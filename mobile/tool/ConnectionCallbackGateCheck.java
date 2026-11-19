package org.austugal.lantern;

/** Deterministic callback-policy scenarios; no phone, SDK callback or radio is exercised. */
public final class ConnectionCallbackGateCheck {
    private static int checks;

    private static void require(boolean condition, String message) {
        checks++;
        if (!condition) throw new AssertionError(message);
    }

    private static final class Effects {
        int rejected;
        int progressed;
        String pending = "reused-endpoint";
        String connected;

        void apply(ConnectionCallbackGate.Action action) {
            switch (action) {
                case REJECT: rejected++; break;
                case PROCEED: progressed++; pending = null; connected = "reused-endpoint"; break;
                case IGNORE: break;
                default: throw new AssertionError("Unknown action");
            }
        }
    }

    private static void oldCallbacksCannotTouchNewSession() {
        for (String connected : new String[]{null, "reused-endpoint"}) {
            Effects effects = new Effects();
            effects.connected = connected;
            effects.apply(ConnectionCallbackGate.initiated(1, 3, true,
                    "reused-endpoint", effects.pending, effects.connected));
            effects.apply(ConnectionCallbackGate.result(1, 3, true,
                    "reused-endpoint", effects.pending, effects.connected));
            require(effects.rejected == 0, "old callbacks attempted endpoint rejection/disconnection");
            require(effects.progressed == 0, "old callbacks advanced new session");
            require("reused-endpoint".equals(effects.pending), "old callback changed pending peer");
            require(connected == effects.connected, "old callback changed connected peer");
        }
        require(ConnectionCallbackGate.initiated(1, 2, false, "old", null, null)
                == ConnectionCallbackGate.Action.IGNORE, "stopped old invitation not ignored");
        require(ConnectionCallbackGate.result(1, 2, false, "old", null, null)
                == ConnectionCallbackGate.Action.IGNORE, "stopped old result not ignored");
    }

    private static void currentSessionRulesRemain() {
        require(ConnectionCallbackGate.initiated(3, 3, true, "peer", null, null)
                == ConnectionCallbackGate.Action.PROCEED, "fresh incoming invitation denied");
        require(ConnectionCallbackGate.initiated(3, 3, true, "peer", "peer", null)
                == ConnectionCallbackGate.Action.PROCEED, "requested peer denied");
        require(ConnectionCallbackGate.result(3, 3, true, "peer", "peer", null)
                == ConnectionCallbackGate.Action.PROCEED, "current pending result denied");
        require(ConnectionCallbackGate.initiated(3, 3, true, "third", "peer", null)
                == ConnectionCallbackGate.Action.REJECT, "third invitation accepted while pending");
        require(ConnectionCallbackGate.initiated(3, 3, true, "third", null, "peer")
                == ConnectionCallbackGate.Action.REJECT, "third invitation accepted while connected");
        require(ConnectionCallbackGate.result(3, 3, true, "third", "peer", null)
                == ConnectionCallbackGate.Action.REJECT, "unsolicited result accepted");
        require(ConnectionCallbackGate.result(3, 3, true, "peer", null, null)
                == ConnectionCallbackGate.Action.REJECT, "cancelled or timed-out result accepted");
        require(ConnectionCallbackGate.initiated(3, 3, false, "peer", "peer", null)
                == ConnectionCallbackGate.Action.REJECT, "stopped current invitation accepted");
        require(ConnectionCallbackGate.result(3, 3, false, "peer", "peer", null)
                == ConnectionCallbackGate.Action.REJECT, "stopped current result accepted");
    }

    private static final class InvitationEffects {
        int generation = 3;
        int invitationGeneration = 8;
        boolean running = true;
        String pending = "peer";
        int cleared;

        void failedRequest(int epoch, int invitationEpoch, String id) {
            if (ConnectionCallbackGate.ownsInvitation(epoch, generation,
                    invitationEpoch, invitationGeneration, running, id, pending)) {
                pending = null;
                cleared++;
            }
        }
    }

    private static void failedRequestsOnlyClearTheirOwnInvitation() {
        InvitationEffects retry = new InvitationEffects();
        // Cancel and retry the same peer without restarting discovery.
        int firstInvitation = retry.invitationGeneration;
        retry.pending = null;
        retry.invitationGeneration++;
        retry.pending = "peer";
        retry.failedRequest(3, firstInvitation, "peer");
        require("peer".equals(retry.pending), "old failure cleared same-peer retry");
        require(retry.cleared == 0, "old failure performed pending cleanup");
        retry.failedRequest(3, retry.invitationGeneration, "peer");
        require(retry.pending == null, "current retry failure did not clear pending peer");
        require(retry.cleared == 1, "current retry failure did not perform exactly one cleanup");

        InvitationEffects differentPeer = new InvitationEffects();
        differentPeer.failedRequest(3, 8, "other-peer");
        require("peer".equals(differentPeer.pending), "different-peer failure cleared pending peer");
        require(differentPeer.cleared == 0, "different-peer failure performed cleanup");

        InvitationEffects restarted = new InvitationEffects();
        restarted.failedRequest(1, 8, "peer");
        require("peer".equals(restarted.pending), "previous discovery failure cleared new session");
        require(restarted.cleared == 0, "previous discovery failure performed cleanup");

        InvitationEffects stopped = new InvitationEffects();
        stopped.running = false;
        stopped.failedRequest(3, 8, "peer");
        require("peer".equals(stopped.pending), "stopped session failure changed pending peer");
        require(stopped.cleared == 0, "stopped session failure performed cleanup");

        InvitationEffects noPending = new InvitationEffects();
        noPending.pending = null;
        noPending.failedRequest(3, 8, "peer");
        require(noPending.cleared == 0, "failure without pending invitation performed cleanup");
        noPending.failedRequest(3, 8, null);
        require(noPending.cleared == 0, "null endpoint matched null pending invitation");

        InvitationEffects nullEndpoint = new InvitationEffects();
        nullEndpoint.failedRequest(3, 8, null);
        require("peer".equals(nullEndpoint.pending), "null endpoint failure cleared pending peer");
        require(nullEndpoint.cleared == 0, "null endpoint failure performed cleanup");
    }

    private static final class DisconnectEffects {
        int generation = 3;
        boolean running = true;
        String pending;
        String connected;
        int emitted;

        void disconnect(int epoch, String id) {
            if (!ConnectionCallbackGate.ownsDisconnect(epoch, generation, running,
                    id, pending, connected)) return;
            if (id.equals(pending)) pending = null;
            if (id.equals(connected)) connected = null;
            emitted++;
        }
    }

    private static void disconnectsOnlyAffectOwnedEndpoints() {
        DisconnectEffects invitation = new DisconnectEffects();
        invitation.pending = "new-peer";
        invitation.disconnect(3, "old-peer");
        require("new-peer".equals(invitation.pending), "unrelated disconnect cleared invitation");
        require(invitation.emitted == 0, "unrelated disconnect emitted while invitation pending");
        invitation.disconnect(3, "new-peer");
        require(invitation.pending == null, "owned pending disconnect did not clear invitation");
        require(invitation.emitted == 1, "owned pending disconnect did not emit exactly once");
        invitation.disconnect(3, "new-peer");
        require(invitation.emitted == 1, "duplicate pending disconnect emitted again");

        DisconnectEffects connection = new DisconnectEffects();
        connection.connected = "current-peer";
        connection.disconnect(3, "other-peer");
        require("current-peer".equals(connection.connected), "unrelated disconnect cleared connection");
        require(connection.emitted == 0, "unrelated disconnect emitted while connected");
        connection.disconnect(3, "current-peer");
        require(connection.connected == null, "owned disconnect did not clear connection");
        require(connection.emitted == 1, "owned connection disconnect did not emit exactly once");
        connection.disconnect(3, "current-peer");
        require(connection.emitted == 1, "duplicate connection disconnect emitted again");

        for (boolean pending : new boolean[]{true, false}) {
            DisconnectEffects old = new DisconnectEffects();
            old.pending = pending ? "peer" : null;
            old.connected = pending ? null : "peer";
            old.disconnect(1, "peer");
            require("peer".equals(pending ? old.pending : old.connected),
                    "old-generation disconnect changed owned endpoint");
            require(old.emitted == 0, "old-generation disconnect emitted");
            old.running = false;
            old.disconnect(3, "peer");
            require("peer".equals(pending ? old.pending : old.connected),
                    "stopped-session disconnect changed owned endpoint");
            require(old.emitted == 0, "stopped-session disconnect emitted");
        }

        DisconnectEffects idle = new DisconnectEffects();
        idle.disconnect(3, "peer");
        idle.disconnect(3, null);
        require(idle.emitted == 0, "unowned or null disconnect emitted from idle state");
        idle.pending = "peer";
        idle.disconnect(3, null);
        require("peer".equals(idle.pending) && idle.emitted == 0,
                "null disconnect changed an active invitation");
    }

    /** Models the effects after the gate in MainActivity.onConnectionResult. */
    private static final class ResultEffects {
        boolean running = true;
        String pending = "peer";
        String connected;
        String disconnectedEndpoint;
        int disconnectCalls;
        int connectedEvents;
        int disconnectedEvents;
        int errorEvents;

        void result(String id, boolean success) {
            switch (ConnectionCallbackGate.result(3, 3, running, id, pending, connected)) {
                case IGNORE: return;
                case REJECT:
                    disconnectCalls++;
                    disconnectedEndpoint = id;
                    return;
                case PROCEED: break;
                default: throw new AssertionError("Unknown action");
            }
            pending = null;
            if (success) {
                connected = id;
                connectedEvents++;
            } else {
                disconnectedEvents++;
                errorEvents++;
            }
        }
    }

    private static void duplicateResultsPreserveEstablishedConnection() {
        for (boolean duplicateSuccess : new boolean[]{true, false}) {
            ResultEffects connection = new ResultEffects();
            connection.result("peer", true);
            require(connection.pending == null, "successful result retained pending invitation");
            require("peer".equals(connection.connected), "successful result did not connect peer");
            require(connection.connectedEvents == 1, "successful result did not emit once");
            connection.result("peer", duplicateSuccess);
            connection.result("peer", duplicateSuccess);
            require(connection.disconnectCalls == 0,
                    "duplicate result attempted endpoint-wide disconnection");
            require(connection.pending == null, "duplicate result changed pending invitation");
            require("peer".equals(connection.connected), "duplicate result changed connected peer");
            require(connection.connectedEvents == 1, "duplicate result emitted another connection");
            require(connection.disconnectedEvents == 0 && connection.errorEvents == 0,
                    "duplicate result emitted disconnection or error");
        }

        ResultEffects failure = new ResultEffects();
        failure.result("peer", false);
        require(failure.pending == null, "failed pending result retained invitation");
        require(failure.connected == null, "failed pending result connected peer");
        require(failure.disconnectCalls == 0, "failed pending result attempted endpoint disconnection");
        require(failure.connectedEvents == 0, "failed pending result emitted connection");
        require(failure.disconnectedEvents == 1 && failure.errorEvents == 1,
                "failed pending result did not emit disconnection and error exactly once");

        ResultEffects unrelated = new ResultEffects();
        unrelated.result("peer", true);
        unrelated.result("other-peer", true);
        require(unrelated.disconnectCalls == 1 && "other-peer".equals(unrelated.disconnectedEndpoint),
                "unrelated result did not reject only its own endpoint");
        require(unrelated.pending == null && "peer".equals(unrelated.connected),
                "unrelated result changed owned connection state");
        require(unrelated.connectedEvents == 1, "unrelated result emitted connection");
        require(unrelated.disconnectedEvents == 0 && unrelated.errorEvents == 0,
                "unrelated result emitted owner disconnection or error");

        ResultEffects inconsistent = new ResultEffects();
        inconsistent.connected = "peer";
        inconsistent.pending = "other-peer";
        inconsistent.result("peer", false);
        require("peer".equals(inconsistent.connected) && "other-peer".equals(inconsistent.pending),
                "duplicate result changed owner or unrelated pending state");
        require(inconsistent.disconnectCalls == 0, "duplicate result disconnected inconsistent owner");
        require(inconsistent.connectedEvents == 0 && inconsistent.disconnectedEvents == 0
                && inconsistent.errorEvents == 0, "duplicate result emitted from inconsistent state");

        require(ConnectionCallbackGate.result(3, 3, true, null, null, "peer")
                == ConnectionCallbackGate.Action.REJECT, "null endpoint matched connected peer");
        require(ConnectionCallbackGate.result(3, 3, true, null, null, null)
                == ConnectionCallbackGate.Action.REJECT, "null endpoint matched idle state");
        require(ConnectionCallbackGate.result(3, 3, true, null, "peer", null)
                == ConnectionCallbackGate.Action.REJECT, "null endpoint matched pending peer");

        ResultEffects stopped = new ResultEffects();
        stopped.result("peer", true);
        stopped.running = false;
        stopped.result("peer", true);
        require(stopped.disconnectCalls == 1, "stopped current result was accepted or ignored");
        require(stopped.connectedEvents == 1, "stopped current result emitted connection");
        require(stopped.disconnectedEvents == 0 && stopped.errorEvents == 0,
                "stopped current result emitted disconnection or error");
    }

    public static void main(String[] args) {
        oldCallbacksCannotTouchNewSession();
        currentSessionRulesRemain();
        failedRequestsOnlyClearTheirOwnInvitation();
        disconnectsOnlyAffectOwnedEndpoints();
        duplicateResultsPreserveEstablishedConnection();
        System.out.println("ConnectionCallbackGate JVM checks passed: " + checks);
    }
}
