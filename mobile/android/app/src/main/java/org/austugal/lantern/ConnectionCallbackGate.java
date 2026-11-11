package org.austugal.lantern;

/** Stale SDK callbacks must not issue endpoint-wide actions in a newer session. */
final class ConnectionCallbackGate {
    enum Action { IGNORE, REJECT, PROCEED }

    private ConnectionCallbackGate() {}

    static Action initiated(int epoch, int current, boolean running,
                            String id, String pending, String connected) {
        if (epoch != current) return Action.IGNORE;
        if (!running || connected != null || (pending != null && !pending.equals(id))) {
            return Action.REJECT;
        }
        return Action.PROCEED;
    }

    static Action result(int epoch, int current, boolean running,
                         String id, String pending, String connected) {
        if (epoch != current) return Action.IGNORE;
        if (!running || pending == null || !pending.equals(id)) return Action.REJECT;
        return Action.PROCEED;
    }
}
