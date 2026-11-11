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

    public static void main(String[] args) {
        oldCallbacksCannotTouchNewSession();
        currentSessionRulesRemain();
        System.out.println("ConnectionCallbackGate JVM checks passed: " + checks);
    }
}
