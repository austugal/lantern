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

    public static void main(String[] args) {
        oldCallbacksCannotTouchNewSession();
        currentSessionRulesRemain();
        failedRequestsOnlyClearTheirOwnInvitation();
        System.out.println("ConnectionCallbackGate JVM checks passed: " + checks);
    }
}
