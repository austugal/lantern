package org.austugal.lantern;

import java.util.Arrays;

/** Standalone JVM checks. No Android service, radio, or peer is started. */
public final class SessionInboxCheck {
    private static final String PEER = "verified-peer";
    private static final long GENERATION = 7;
    private static final int BYTE_LIMIT = 256 * 1024;

    private static void require(boolean passed, String reason) {
        if (!passed) throw new AssertionError(reason);
    }

    private static SessionInbox inbox() {
        return new SessionInbox(PEER, GENERATION);
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

    public static void main(String[] args) {
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
