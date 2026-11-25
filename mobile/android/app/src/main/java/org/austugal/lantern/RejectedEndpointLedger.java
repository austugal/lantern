package org.austugal.lantern;

import java.util.HashSet;
import java.util.Set;

/**
 * Bounded rejection memory for one discovery generation.
 *
 * <p>This is a standalone policy component, not yet wired into the native adapter.
 * Its owner must fence stale callbacks and create a new instance only for an
 * explicit discovery restart. It does not reserve an attempt, stop discovery,
 * disconnect an established peer, or emit an event.
 */
final class RejectedEndpointLedger {
    private static final int MAX_ENDPOINTS = 100;
    private static final int MAX_ID_CHARS = 128;

    private final Set<String> rejected = new HashSet<>();
    private boolean closed;

    RejectedEndpointLedger() {}

    /**
     * Remembers a rejection without eviction. The hundredth distinct rejection
     * closes admission permanently for this instance. An invalid rejection also
     * closes admission, without retaining the invalid ID.
     */
    synchronized void reject(String id) {
        if (closed) return;
        if (!valid(id)) {
            closed = true;
            return;
        }
        rejected.add(id);
        if (rejected.size() == MAX_ENDPOINTS) closed = true;
    }

    /** Returns a policy decision only; invalid queries do not mutate the ledger. */
    synchronized boolean allows(String id) {
        return !closed && valid(id) && !rejected.contains(id);
    }

    synchronized int size() {
        return rejected.size();
    }

    synchronized boolean isClosed() {
        return closed;
    }

    // IDs are opaque: no trimming, case folding or other normalization.
    // Length counts Java UTF-16 code units and bounds retained identifier data.
    private static boolean valid(String id) {
        return id != null && !id.isEmpty() && id.length() <= MAX_ID_CHARS;
    }
}
