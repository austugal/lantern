package org.austugal.lantern;

import java.util.ArrayDeque;
import java.util.function.LongSupplier;

/**
 * In-memory FIFO for one already-verified peer and session generation. Successful
 * admission only stores bytes; it is not a delivery receipt. A failed offer is
 * terminal: the owner must end the session rather than continue after data loss.
 * Expiry is enforced on access; this inbox schedules no service shutdown.
 */
final class SessionInbox {
    private static final int MAX_PAYLOADS = 32;
    private static final int MAX_BYTES = 256 * 1024;
    private static final long MAX_AGE_MS = 30 * 60 * 1000L;

    private final String peer;
    private final long generation;
    private final LongSupplier elapsedRealtime;
    private final long startedAt;
    private long lastObserved;
    private final ArrayDeque<byte[]> pending = new ArrayDeque<>();
    private int bufferedBytes;
    private boolean closed;

    SessionInbox(String peer, long generation, LongSupplier elapsedRealtime) {
        if (peer == null || peer.trim().isEmpty()) {
            throw new IllegalArgumentException("A verified peer is required");
        }
        this.peer = peer;
        this.generation = generation;
        this.elapsedRealtime = elapsedRealtime;
        startedAt = elapsedRealtime.getAsLong();
        if (startedAt < 0) throw new IllegalArgumentException("Negative elapsed time");
        lastObserved = startedAt;
    }

    synchronized boolean offer(String peer, long generation, byte[] bytes) {
        if (!matches(peer, generation) || bytes == null || bytes.length == 0
                || pending.size() >= MAX_PAYLOADS || bytes.length > MAX_BYTES - bufferedBytes) {
            close();
            return false;
        }
        pending.addLast(bytes.clone());
        bufferedBytes += bytes.length;
        return true;
    }

    /**
     * Returns the next payload, or null when the inbox is empty or closed.
     * On null, the owner must disconnect if isClosed() is true.
     */
    synchronized byte[] poll(String peer, long generation) {
        if (!matches(peer, generation)) {
            close();
            return null;
        }
        byte[] next = pending.pollFirst();
        if (next != null) {
            bufferedBytes -= next.length;
        }
        return next;
    }

    synchronized boolean isClosed() {
        if (!closed) {
            long now = elapsedRealtime.getAsLong();
            // Check ordering before subtraction, so even extreme timestamps are safe.
            if (now < lastObserved || now - startedAt >= MAX_AGE_MS) close();
            lastObserved = now;
        }
        return closed;
    }

    synchronized void close() {
        closed = true;
        pending.clear();
        bufferedBytes = 0;
    }

    private boolean matches(String candidate, long candidateGeneration) {
        return !isClosed() && generation == candidateGeneration && peer.equals(candidate);
    }
}
