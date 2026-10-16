package org.austugal.lantern

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** A one-peer transport. Consent is explicit on both phones, before payloads. */
class MainActivity : FlutterActivity(), EventChannel.StreamHandler {
    private val client by lazy { Nearby.getConnectionsClient(this) }
    private var sink: EventChannel.EventSink? = null
    private var running = false
    private var generation = 0
    private var displayName = ""
    private var pending: String? = null
    private var connected: String? = null
    private val names = mutableMapOf<String, String>()
    private var permissionResult: MethodChannel.Result? = null
    private val service = "org.austugal.lantern.v1"

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        EventChannel(engine.dartExecutor.binaryMessenger, "org.austugal.lantern/events").setStreamHandler(this)
        MethodChannel(engine.dartExecutor.binaryMessenger, "org.austugal.lantern/nearby").setMethodCallHandler(::handle)
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { shutdown(); sink = null }
    private fun emit(type: String, id: String = "", extras: Map<String, Any> = emptyMap()) {
        runOnUiThread { sink?.success(mapOf("type" to type, "id" to id) + extras) }
    }
    private fun fail(result: MethodChannel.Result, e: Exception) = result.error("nearby", e.localizedMessage ?: "Nearby operation failed", null)
    private fun requiredPermissions(): Array<String> {
        val permissions = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= 31) permissions.addAll(listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_ADVERTISE))
        if (Build.VERSION.SDK_INT >= 33) permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        return permissions.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }.toTypedArray()
    }
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: ""
        when (call.method) {
            "start" -> {
                if (permissionResult != null) { result.error("busy", "A permission request is already open", null); return }
                shutdown()
                displayName = (call.argument<String>("name") ?: "").trim().take(24)
                if (displayName.isBlank()) { result.error("name", "Choose a display name first", null); return }
                val permissions = requiredPermissions()
                if (permissions.isNotEmpty()) {
                    permissionResult = result
                    requestPermissions(permissions, 902)
                } else start(result)
            }
            "stop" -> { shutdown(); result.success(null) }
            "request" -> {
                if (!running || connected != null || pending != null || !names.containsKey(id)) { result.error("state", "This person is no longer available", null); return }
                pending = id
                val epoch = generation
                client.requestConnection(displayName, id, lifecycle(epoch))
                    .addOnSuccessListener { result.success(null) }
                    .addOnFailureListener { if (epoch == generation) pending = null; fail(result, it) }
            }
            "accept" -> {
                if (!running || pending != id) { result.error("state", "This invitation has expired", null); return }
                client.acceptConnection(id, payloads(generation)).addOnSuccessListener { result.success(null) }.addOnFailureListener { fail(result, it) }
            }
            "reject" -> {
                if (pending == id) pending = null
                client.rejectConnection(id).addOnSuccessListener { result.success(null) }.addOnFailureListener { fail(result, it) }
            }
            "disconnect" -> {
                client.disconnectFromEndpoint(id)
                if (pending == id) pending = null
                if (connected == id) connected = null
                result.success(null)
            }
            "send" -> {
                val bytes = (call.argument<String>("data") ?: "").toByteArray(Charsets.UTF_8)
                if (!running || connected != id || bytes.size > 8192) { result.error("state", "No active connection or message too large", null); return }
                client.sendPayload(id, Payload.fromBytes(bytes)).addOnSuccessListener { result.success(null) }.addOnFailureListener { fail(result, it) }
            }
            else -> result.notImplemented()
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 902) return
        val result = permissionResult ?: return
        permissionResult = null
        if (grantResults.isEmpty() || grantResults.any { it != PackageManager.PERMISSION_GRANTED }) result.error("permission", "Allow Nearby devices and Location in app settings to discover people.", null)
        else start(result)
    }
    private fun start(result: MethodChannel.Result) {
        val epoch = ++generation
        running = true
        client.startAdvertising(displayName, service, lifecycle(epoch), AdvertisingOptions.Builder().setStrategy(Strategy.P2P_POINT_TO_POINT).build())
            .addOnSuccessListener {
                if (epoch != generation || !running) { result.error("cancelled", "Discovery was cancelled", null); return@addOnSuccessListener }
                client.startDiscovery(service, discovery(epoch), DiscoveryOptions.Builder().setStrategy(Strategy.P2P_POINT_TO_POINT).build())
                    .addOnSuccessListener {
                        if (epoch == generation && running) result.success(null)
                        else result.error("cancelled", "Discovery was cancelled", null)
                    }
                    .addOnFailureListener { if (epoch == generation) shutdown(); fail(result, it) }
            }.addOnFailureListener { if (epoch == generation) shutdown(); fail(result, it) }
    }
    private fun discovery(epoch: Int) = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(id: String, info: DiscoveredEndpointInfo) {
            if (!running || epoch != generation || names.size >= 100) return
            names[id] = info.endpointName.take(64)
            emit("found", id, mapOf("name" to names[id]!!))
        }
        override fun onEndpointLost(id: String) {
            if (epoch != generation) return
            if (id != connected && id != pending) names.remove(id)
            emit("lost", id)
        }
    }
    private fun lifecycle(epoch: Int) = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(id: String, info: ConnectionInfo) {
            if (!running || epoch != generation || connected != null || (pending != null && pending != id)) { client.rejectConnection(id); return }
            pending = id
            names[id] = info.endpointName.take(64)
            emit("invitation", id, mapOf("name" to names[id]!!, "code" to info.authenticationDigits))
        }
        override fun onConnectionResult(id: String, resolution: ConnectionResolution) {
            if (epoch != generation || !running || pending != id) { client.disconnectFromEndpoint(id); return }
            pending = null
            if (resolution.status.isSuccess) {
                connected = id
                emit("connected", id, mapOf("name" to (names[id] ?: "Nearby person")))
            } else {
                emit("disconnected", id)
                emit("error", id, mapOf("message" to "Connection declined or failed. Try again when both phones are ready."))
            }
        }
        override fun onDisconnected(id: String) {
            if (epoch != generation) return
            if (connected == id) connected = null
            if (pending == id) pending = null
            emit("disconnected", id)
        }
    }
    private fun payloads(epoch: Int) = object : PayloadCallback() {
        override fun onPayloadReceived(id: String, payload: Payload) {
            if (!running || epoch != generation || connected != id) return
            val bytes = payload.asBytes() ?: return
            if (bytes.size <= 8192) emit("data", id, mapOf("data" to bytes.toString(Charsets.UTF_8)))
        }
        override fun onPayloadTransferUpdate(id: String, update: PayloadTransferUpdate) {
            if (epoch == generation && update.status == PayloadTransferUpdate.Status.FAILURE) emit("error", id, mapOf("message" to "A message could not be transferred. Check its delivery status."))
        }
    }
    private fun shutdown() {
        ++generation
        running = false
        pending = null
        connected = null
        names.clear()
        client.stopAdvertising()
        client.stopDiscovery()
        client.stopAllEndpoints()
        permissionResult?.error("cancelled", "Discovery was cancelled", null)
        permissionResult = null
    }
    override fun onStop() { shutdown(); emit("stopped"); super.onStop() }
    override fun onDestroy() { shutdown(); super.onDestroy() }
}
