package org.austugal.lantern;

import java.util.Arrays;
import java.util.concurrent.atomic.AtomicLong;

/** Standalone JVM checks. No Android service, radio, or peer is started. */
public final class SessionInboxCheck {
    private static final String PEER = "verified-peer";
    private static final long GENERATION = 7;
    private static final int BYTE_LIMIT = 256 * 1024;

    private static void require(boolean passed, String reason) {
        if (!passed) throw new AssertionError(reason);
    }

    private static SessionInbox inbox() {
        return new SessionInbox(PEER, GENERATION, () -> 0L);
    }

    private static boolean offer(SessionInbox inbox, byte[] bytes) {
        return inbox.offer(PEER, GENERATION, bytes);
    }

    private static byte[] poll(SessionInbox inbox) {
        return inbox.poll(PEER, GENERATION);
    }

    private static void assertClosed(SessionInbox inbox, String reason) {
        require(inbox.isClosed(), reason + ": inbox did not report closure");
        require(poll(inbox) == null, reason + ": buffered data survived");
        require(!offer(inbox, new byte[]{1}), reason + ": inbox reopened");
    }

    private static void fifoAndCopies() {
        SessionInbox inbox = inbox();
        require(poll(inbox) == null, "new inbox should be empty");
        require(!inbox.isClosed(), "empty poll closed inbox");
        byte[] source = {1, 2};
        require(offer(inbox, source), "first offer");
        source[0] = 3;
        require(offer(inbox, source), "second offer");
        source[1] = 4;
        require(Arrays.equals(poll(inbox), new byte[]{1, 2}), "first packet changed");
        require(Arrays.equals(poll(inbox), new byte[]{3, 2}), "second packet changed");
        require(poll(inbox) == null, "packet drained twice");
    }

    private static void countBound() {
        SessionInbox inbox = inbox();
        for (int i = 0; i < 32; i++) {
            require(offer(inbox, new byte[]{(byte) i}), "early rejection at index " + i);
        }
        require(!offer(inbox, new byte[]{32}), "33rd packet accepted");
        assertClosed(inbox, "count overflow");
    }

    private static void byteBound() {
        SessionInbox inbox = inbox();
        byte[] packet = new byte[BYTE_LIMIT];
        require(offer(inbox, packet), "exact byte limit rejected");
        require(Arrays.equals(poll(inbox), packet), "wrong exact-limit packet");
        require(offer(inbox, new byte[BYTE_LIMIT - 1]), "poll did not free byte budget");
        require(offer(inbox, new byte[]{2}), "exact aggregate byte limit rejected");
        require(!offer(inbox, new byte[]{3}), "aggregate byte limit exceeded");
        assertClosed(inbox, "aggregate byte overflow");

        inbox = inbox();
        require(!offer(inbox, new byte[BYTE_LIMIT + 1]), "oversized packet accepted");
        assertClosed(inbox, "oversized packet");
    }

    private static void rejectOtherSession(String peer, long generation) {
        SessionInbox receiver = inbox();
        require(offer(receiver, new byte[]{1}), "seed for offer mismatch");
        require(!receiver.offer(peer, generation, new byte[]{2}), "accepted wrong session");
        assertClosed(receiver, "wrong session on offer");

        SessionInbox reader = inbox();
        require(offer(reader, new byte[]{1}), "seed for poll mismatch");
        require(reader.poll(peer, generation) == null, "released data to wrong session");
        assertClosed(reader, "wrong session on poll");
    }

    private static void rejectMalformed(byte[] malformed) {
        SessionInbox inbox = inbox();
        require(offer(inbox, new byte[]{1}), "seed for malformed payload");
        require(!offer(inbox, malformed), "malformed payload accepted");
        assertClosed(inbox, "malformed payload");
    }

    private static void fixedDeadline() {
        long start = 9_876_543L; // Already well past 30 minutes since boot.
        long deadline = start + 30 * 60_000L;
        AtomicLong clock = new AtomicLong(start);
        SessionInbox writer = new SessionInbox(PEER, GENERATION, clock::get);
        SessionInbox reader = new SessionInbox(PEER, GENERATION, clock::get);
        SessionInbox observer = new SessionInbox(PEER, GENERATION, clock::get);

        clock.set(deadline - 1);
        require(offer(writer, new byte[]{1}), "offer rejected before deadline");
        require(offer(reader, new byte[]{2}), "first offer rejected before deadline");
        require(offer(reader, new byte[]{3}), "second offer rejected before deadline");
        require(Arrays.equals(poll(reader), new byte[]{2}), "poll rejected before deadline");
        require(!observer.isClosed(), "status expired before deadline");

        // Each operation must detect expiry without relying on another operation or a timer.
        clock.set(deadline);
        require(!offer(writer, new byte[]{4}), "late offer extended lifetime");
        require(poll(reader) == null, "late poll released a queued packet");
        require(observer.isClosed(), "status remained open at deadline");
        assertClosed(writer, "expired on offer");
        assertClosed(reader, "expired on poll");
        assertClosed(observer, "expired on status");
    }

    private static void resumeAfterDeadline() {
        AtomicLong clock = new AtomicLong(1_000L);
        SessionInbox old = new SessionInbox(PEER, GENERATION, clock::get);
        require(offer(old, new byte[]{1}), "seed before long idle period");
        clock.addAndGet(24 * 60 * 60_000L); // First access after the elapsed clock jumps.
        require(poll(old) == null, "old payload released on resume");

        SessionInbox fresh = new SessionInbox(PEER, GENERATION + 1, clock::get);
        require(fresh.poll(PEER, GENERATION + 1) == null, "new inbox inherited old payload");
        require(fresh.offer(PEER, GENERATION + 1, new byte[]{2}), "new inbox inherited expiry");
        require(Arrays.equals(fresh.poll(PEER, GENERATION + 1), new byte[]{2}),
                "new inbox could not drain its own packet");
        clock.set(1_000L);
        assertClosed(old, "expired inbox after clock reset");
    }

    private static void invalidClockCannotExtendLifetime() {
        // Adding the lifetime to this timestamp would overflow before the session starts.
        AtomicLong clock = new AtomicLong(Long.MAX_VALUE - 2);
        SessionInbox inbox = new SessionInbox(PEER, GENERATION, clock::get);
        clock.incrementAndGet();
        require(offer(inbox, new byte[]{1}), "near-maximum start caused premature expiry");
        clock.decrementAndGet(); // Earlier than the last access, though still at the start time.
        require(poll(inbox) == null, "clock rollback released a pending packet");
        assertClosed(inbox, "backwards clock");
    }

    public static void main(String[] args) {
        invalidClockCannotExtendLifetime();
        fixedDeadline();
        resumeAfterDeadline();
        fifoAndCopies();
        countBound();
        byteBound();
        rejectOtherSession("other-peer", GENERATION);
        rejectOtherSession(PEER, GENERATION - 1);
        rejectOtherSession(null, GENERATION);
        rejectMalformed(null);
        rejectMalformed(new byte[0]);

        SessionInbox inbox = inbox();
        require(offer(inbox, new byte[]{1}), "seed for explicit close");
        inbox.close();
        inbox.close();
        assertClosed(inbox, "explicit close");
        System.out.println("SessionInbox JVM checks passed");
    }
}
