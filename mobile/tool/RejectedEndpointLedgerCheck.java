package org.austugal.lantern;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicReference;

/** Component policy checks only; no native lifecycle, SDK or physical radio is exercised. */
public final class RejectedEndpointLedgerCheck {
    private static int checks;

    private static void require(boolean condition, String message) {
        checks++;
        if (!condition) throw new AssertionError(message);
    }

    private static void rejectionAndDuplicateRules() {
        RejectedEndpointLedger ledger = new RejectedEndpointLedger();
        require(ledger.size() == 0, "new generation retained old rejections");
        require(!ledger.isClosed(), "new generation starts closed");
        require(ledger.allows("peer-a"), "new peer denied before rejection");
        require(ledger.size() == 0, "admission query retained a peer");
        ledger.reject("peer-a");
        require(!ledger.allows(new String("peer-a")), "rejected ID admitted by value");
        require(ledger.allows("peer-b"), "rejection closed unrelated admission early");
        require(ledger.size() == 1, "first rejection not retained");
        for (int i = 0; i < 1000; i++) ledger.reject(new String("peer-a"));
        require(ledger.size() == 1, "duplicate rejections consumed capacity");
        require(!ledger.isClosed(), "duplicates latched closure early");
        require(!ledger.allows("peer-a"), "duplicate rejection forgot the ID");
    }

    private static void capacityLatchesWithoutEviction() {
        RejectedEndpointLedger ledger = new RejectedEndpointLedger();
        for (int i = 0; i < 99; i++) ledger.reject("peer-" + i);
        require(ledger.size() == 99, "incorrect retained count before capacity");
        require(!ledger.isClosed(), "closed before capacity");
        require(ledger.allows("last-peer"), "fresh peer refused before capacity");
        ledger.reject("peer-0");
        require(ledger.size() == 99, "duplicate at 99 consumed final slot");
        require(!ledger.isClosed(), "duplicate at 99 closed admission");
        boolean allRejected = true;
        for (int i = 0; i < 99; i++) allRejected &= !ledger.allows("peer-" + i);
        require(allRejected, "a prior rejection was evicted or forgotten");
        ledger.reject("last-peer");
        require(ledger.size() == 100, "capacity entry not retained");
        require(ledger.isClosed(), "capacity must latch closure at 100, not 101");
        require(!ledger.allows("never-recorded"), "unrecorded peer admitted at capacity");
        ledger.reject("peer-101");
        require(ledger.size() == 100, "101st rejection grew retained set");
        require(!ledger.allows("peer-101"), "overflow peer admitted later");
        for (int i = 0; i < 10000; i++) ledger.reject("flood-" + i);
        require(ledger.size() == 100, "post-closure flood grew memory");
        require(ledger.isClosed(), "post-closure flood reopened admission");
        require(!ledger.allows("peer-0"), "old peer admitted after overflow");
        require(!ledger.allows("unseen-after-flood"), "closure forgot unrecorded IDs");

        RejectedEndpointLedger replacement = new RejectedEndpointLedger();
        require(replacement.allows("peer-0"), "replacement generation inherited rejection");
        require(replacement.size() == 0, "replacement generation inherited retained IDs");
        require(!replacement.isClosed(), "replacement generation inherited closure");
        replacement.reject("new-generation-peer");
        require(ledger.size() == 100, "replacement mutated old generation");
        require(ledger.isClosed(), "replacement reopened old generation");
        require(!ledger.allows("new-generation-peer"), "old reference became usable again");
    }

    private static void identifiersAreBoundedAndInvalidQueriesAreReadOnly() {
        String longest = "x".repeat(128);
        String oversized = "x".repeat(129);
        RejectedEndpointLedger ledger = new RejectedEndpointLedger();
        require(ledger.allows(longest), "128-character ID refused");
        ledger.reject(longest);
        require(!ledger.allows(longest), "128-character rejection not retained");
        require(ledger.size() == 1, "128-character ID not counted");
        for (String invalid : new String[]{null, "", oversized}) {
            require(!ledger.allows(invalid), "invalid identifier admitted");
            require(!ledger.isClosed(), "invalid query mutated closure");
            require(ledger.size() == 1, "invalid query mutated retained count");
            require(ledger.allows("valid"), "invalid query affected other IDs");
        }
        // Java character bounds count UTF-16 code units, including surrogate pairs.
        String unicodeLimit = "\uD83D\uDE80".repeat(64);
        require(ledger.allows(unicodeLimit), "128-unit Unicode ID refused");
        require(!ledger.allows(unicodeLimit + "x"), "129-unit Unicode ID admitted");
        ledger.reject(unicodeLimit);
        require(!ledger.allows(unicodeLimit), "Unicode rejection not retained exactly");
        require(ledger.size() == 2, "Unicode ID not counted");
    }

    private static void invalidRejectionsCloseWithoutRetainingInput() {
        for (String invalid : new String[]{null, "", "x".repeat(129)}) {
            RejectedEndpointLedger ledger = new RejectedEndpointLedger();
            ledger.reject("known-peer");
            ledger.reject(invalid);
            require(ledger.isClosed(), "invalid rejection did not fail closed");
            require(ledger.size() == 1, "invalid rejection retained invalid input");
            require(!ledger.allows("never-recorded"), "invalid rejection left admission open");
            ledger.reject("another-peer");
            require(ledger.size() == 1, "closed ledger retained later input");
            require(!ledger.allows("known-peer"), "invalid rejection erased earlier denial");
        }
    }

    private static void concurrentRejectionsCannotExceedCapacity() throws InterruptedException {
        RejectedEndpointLedger ledger = new RejectedEndpointLedger();
        CountDownLatch start = new CountDownLatch(1);
        AtomicReference<Throwable> workerFailure = new AtomicReference<>();
        Thread[] threads = new Thread[8];
        for (int worker = 0; worker < threads.length; worker++) {
            final int index = worker;
            threads[worker] = new Thread(() -> {
                try {
                    start.await();
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    throw new AssertionError(interrupted);
                }
                for (int i = 0; i < 125; i++) ledger.reject("worker-" + index + "-" + i);
            });
            threads[worker].setDaemon(true);
            threads[worker].setUncaughtExceptionHandler((thread, failure) -> workerFailure.set(failure));
            threads[worker].start();
        }
        start.countDown();
        for (Thread thread : threads) {
            thread.join(5000);
            require(!thread.isAlive(), "concurrent rejection worker stalled");
        }
        require(workerFailure.get() == null, "concurrent rejection worker failed");
        require(ledger.size() == 100, "concurrent rejections exceeded or missed capacity");
        require(ledger.isClosed(), "concurrent rejection flood failed to close admission");
        require(!ledger.allows("fresh-after-concurrency"), "concurrent closure permitted reuse");
    }

    public static void main(String[] args) throws InterruptedException {
        rejectionAndDuplicateRules();
        capacityLatchesWithoutEviction();
        identifiersAreBoundedAndInvalidQueriesAreReadOnly();
        invalidRejectionsCloseWithoutRetainingInput();
        concurrentRejectionsCannotExceedCapacity();
        System.out.println("RejectedEndpointLedger JVM checks passed: " + checks);
    }
}
