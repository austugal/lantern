package org.austugal.lantern

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import android.view.Surface
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.provider.Settings
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
    private var invitationGeneration = 0
    private var displayName = ""
    private var pending: String? = null
    private var connected: String? = null
    private val names = mutableMapOf<String, String>()
    private var permissionResult: MethodChannel.Result? = null
    private var torchPermissionResult: MethodChannel.Result? = null
    private var torchPermissionPending = false
    private var notificationPermissionResult: MethodChannel.Result? = null
    private var torchCamera: String? = null
    private var foreground = true
    private val notificationChannel = "lantern_messages"
    private val service = "org.austugal.lantern.v1"
    private val compassSensors by lazy { getSystemService(SensorManager::class.java) }
    private var compassRunning = false
    private var compassForeground = false
    private var compassStartedNanos = 0L
    private var compassSampleNanos = 0L
    private var compassAccuracy = SensorManager.SENSOR_STATUS_UNRELIABLE
    private val compassVector = FloatArray(5)
    private var compassVectorLength = 0
    private val compassMatrix = FloatArray(9)
    private val compassDisplayMatrix = FloatArray(9)
    private val compassAngles = FloatArray(3)
    private val compassListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            if (!compassRunning || !compassForeground || event.timestamp < compassStartedNanos) return
            if (event.values.size < 3 || event.values.any { !it.isFinite() }) return
            compassVectorLength = minOf(event.values.size, compassVector.size)
            event.values.copyInto(compassVector, endIndex = compassVectorLength)
            compassSampleNanos = event.timestamp
            compassAccuracy = event.accuracy
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
            if (compassRunning) compassAccuracy = accuracy
        }
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        EventChannel(engine.dartExecutor.binaryMessenger, "org.austugal.lantern/events").setStreamHandler(this)
        MethodChannel(engine.dartExecutor.binaryMessenger, "org.austugal.lantern/nearby").setMethodCallHandler(::handle)
        MethodChannel(engine.dartExecutor.binaryMessenger, "org.austugal.lantern/device").setMethodCallHandler(::handleDevice)
        MethodChannel(engine.dartExecutor.binaryMessenger, "org.austugal.lantern/compass").setMethodCallHandler(::handleCompass)
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { shutdown(); sink = null }
    private fun emit(type: String, id: String = "", extras: Map<String, Any> = emptyMap()) {
        runOnUiThread { sink?.success(mapOf("type" to type, "id" to id) + extras) }
    }
    private fun fail(result: MethodChannel.Result, e: Exception) = result.error("nearby", e.localizedMessage ?: "Nearby operation failed", null)
    private fun requiredPermissions(): Array<String> {
        val permissions = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        if (Build.VERSION.SDK_INT >= 31) permissions.addAll(listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_ADVERTISE))
        if (Build.VERSION.SDK_INT >= 33) permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        val missing = permissions.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }.toMutableList()
        if (Manifest.permission.ACCESS_FINE_LOCATION in missing && Manifest.permission.ACCESS_COARSE_LOCATION !in missing) {
            missing.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        return missing.toTypedArray()
    }
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: ""
        when (call.method) {
            "start" -> {
                if (permissionBusy()) { result.error("busy", "A permission request is already open", null); return }
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
                expireInvitation(id, generation)
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
        if (requestCode == 903) {
            torchPermissionPending = false
            val result = torchPermissionResult ?: return
            torchPermissionResult = null
            if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED } && foreground) setTorch(true, result)
            else result.error("permission", "Camera permission is required for the torch. Enable it in app settings.", null)
            return
        }
        if (requestCode == 904) {
            val result = notificationPermissionResult ?: return
            notificationPermissionResult = null
            result.success(notificationsEnabled())
            return
        }
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
            expireInvitation(id, epoch)
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
    private fun permissionBusy() = permissionResult != null || torchPermissionPending || notificationPermissionResult != null
    private fun notificationsEnabled(): Boolean {
        val manager = getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        return Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(notificationChannel)?.importance != NotificationManager.IMPORTANCE_NONE
    }
    private fun handleDevice(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "setTorch" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (!enabled) {
                        val error = turnTorchOff()
                        if (error == null) result.success(null) else result.error("unavailable", "Could not switch off torch: ${error.localizedMessage}", null)
                        return
                    }
                    if (!foreground) { result.error("state", "Keep Lantern open to use the torch", null); return }
                    if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                        if (permissionBusy()) { result.error("busy", "Finish the current permission request first", null); return }
                        torchPermissionResult = result
                        torchPermissionPending = true
                        requestPermissions(arrayOf(Manifest.permission.CAMERA), 903)
                    } else setTorch(true, result)
                }
                "requestNotifications" -> {
                    val manager = getSystemService(NotificationManager::class.java)
                    if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(notificationChannel, "Lantern messages", NotificationManager.IMPORTANCE_DEFAULT))
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        if (permissionBusy()) { result.error("busy", "Finish the current permission request first", null); return }
                        notificationPermissionResult = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 904)
                    } else result.success(notificationsEnabled())
                }
                "notifyMessage" -> {
                    if (!notificationsEnabled()) { result.success(false); return }
                    val manager = getSystemService(NotificationManager::class.java)
                    if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(notificationChannel, "Lantern messages", NotificationManager.IMPORTANCE_DEFAULT))
                    val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    val launch = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, notificationChannel) else Notification.Builder(this)
                    val notification = builder.setSmallIcon(android.R.drawable.ic_dialog_email)
                        .setContentTitle("New Lantern message").setContentText("Open Lantern to view it.")
                        .setVisibility(Notification.VISIBILITY_PRIVATE).setAutoCancel(true)
                        .setContentIntent(launch).build()
                    manager.notify(1701, notification)
                    result.success(true)
                }
                "clearNotifications" -> { getSystemService(NotificationManager::class.java).cancel(1701); result.success(null) }
                "openAppSettings" -> { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (e: Exception) { result.error("device", e.localizedMessage ?: "Device operation unavailable", null) }
    }
    /** Magnetic north only: never starts GPS, requests location, or sends data. */
    private fun handleCompass(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "start" -> {
                    if (!compassForeground) { result.error("state", "Keep Lantern open to use the compass", null); return }
                    if (compassRunning) { result.success(null); return }
                    val sensor = compassSensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
                    if (sensor == null) { result.error("unsupported", "A magnetic compass sensor is unavailable on this device", null); return }
                    compassStartedNanos = SystemClock.elapsedRealtimeNanos()
                    compassRunning = true
                    // UI sampling only. TYPE_GAME_ROTATION_VECTOR must never be used: it has no north reference.
                    if (!compassSensors.registerListener(compassListener, sensor, SensorManager.SENSOR_DELAY_UI)) {
                        stopCompass()
                        result.error("unsupported", "The compass sensor could not be started", null)
                    } else result.success(null)
                }
                "stop" -> { stopCompass(); result.success(null) }
                "read" -> result.success(readCompass())
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            stopCompass()
            result.error("compass", "Compass unavailable: ${error.localizedMessage}", null)
        }
    }
    private fun readCompass(): Map<String, Any?> {
        val ageMillis = if (compassSampleNanos == 0L) -1L else
            (SystemClock.elapsedRealtimeNanos() - compassSampleNanos) / 1_000_000L
        var accuracy = when (compassAccuracy) {
            SensorManager.SENSOR_STATUS_ACCURACY_HIGH -> "high"
            SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM -> "medium"
            SensorManager.SENSOR_STATUS_ACCURACY_LOW -> "low"
            else -> "unreliable"
        }
        var heading: Double? = null
        if (compassRunning && compassForeground && ageMillis in 0L..2000L &&
            compassVectorLength >= 3 && accuracy != "unreliable") {
            SensorManager.getRotationMatrixFromVector(compassMatrix, compassVector.copyOf(compassVectorLength))
            @Suppress("DEPRECATION")
            val rotation = if (Build.VERSION.SDK_INT >= 30) display?.rotation ?: Surface.ROTATION_0
                else windowManager.defaultDisplay.rotation
            val (axisX, axisY) = when (rotation) {
                Surface.ROTATION_90 -> Pair(SensorManager.AXIS_Y, SensorManager.AXIS_MINUS_X)
                Surface.ROTATION_180 -> Pair(SensorManager.AXIS_MINUS_X, SensorManager.AXIS_MINUS_Y)
                Surface.ROTATION_270 -> Pair(SensorManager.AXIS_MINUS_Y, SensorManager.AXIS_X)
                else -> Pair(SensorManager.AXIS_X, SensorManager.AXIS_Y)
            }
            if (SensorManager.remapCoordinateSystem(compassMatrix, axisX, axisY, compassDisplayMatrix)) {
                // A face-up, approximately level screen gives the top edge a meaningful azimuth.
                if (compassDisplayMatrix[8] < 0.5f) accuracy = "tilted"
                else {
                    SensorManager.getOrientation(compassDisplayMatrix, compassAngles)
                    val degrees = Math.toDegrees(compassAngles[0].toDouble())
                    if (degrees.isFinite()) heading = (degrees + 360.0) % 360.0
                }
            }
        }
        return mapOf("heading" to heading, "accuracy" to accuracy, "ageMillis" to ageMillis)
    }
    private fun stopCompass() {
        compassRunning = false
        compassSensors.unregisterListener(compassListener)
        compassSampleNanos = 0L
        compassStartedNanos = 0L
        compassVectorLength = 0
        compassAccuracy = SensorManager.SENSOR_STATUS_UNRELIABLE
        compassVector.fill(0f)
    }
    private fun setTorch(enabled: Boolean, result: MethodChannel.Result) {
        try {
            val manager = getSystemService(CameraManager::class.java)
            val id = torchCamera ?: manager.cameraIdList.firstOrNull {
                manager.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
            if (id == null) { result.error("unavailable", "This device has no available torch", null); return }
            manager.setTorchMode(id, enabled)
            torchCamera = if (enabled) id else null
            result.success(null)
        } catch (e: Exception) { result.error("unavailable", "Torch unavailable: ${e.localizedMessage}", null) }
    }
    private fun turnTorchOff(): Exception? {
        torchPermissionResult?.error("cancelled", "Torch request cancelled", null)
        torchPermissionResult = null
        val id = torchCamera ?: return null
        return try {
            getSystemService(CameraManager::class.java).setTorchMode(id, false)
            torchCamera = null
            null
        } catch (error: Exception) { error }
    }
    private fun expireInvitation(id: String, epoch: Int) {
        val invitationEpoch = ++invitationGeneration
        window.decorView.postDelayed({
            if (running && epoch == generation && invitationEpoch == invitationGeneration && pending == id) {
                pending = null
                client.rejectConnection(id)
                client.disconnectFromEndpoint(id)
                emit("disconnected", id)
                emit("error", id, mapOf("message" to "Invitation expired. Ask the other person to try again."))
            }
        }, 30_000)
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
    override fun onStart() { super.onStart(); foreground = true }
    override fun onResume() { super.onResume(); compassForeground = true }
    override fun onPause() { compassForeground = false; stopCompass(); super.onPause() }
    override fun onStop() { compassForeground = false; stopCompass(); foreground = false; turnTorchOff(); shutdown(); emit("stopped"); super.onStop() }
    override fun onDestroy() {
        compassForeground = false
        stopCompass()
        foreground = false
        turnTorchOff()
        notificationPermissionResult?.error("cancelled", "Notification request cancelled", null)
        notificationPermissionResult = null
        shutdown()
        super.onDestroy()
    }
}
