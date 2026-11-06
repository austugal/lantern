package org.austugal.lantern;

import android.os.SystemClock;

/** Creates a new inbox at explicit session start; elapsedRealtime includes device sleep. */
final class AndroidSessionInbox {
    private AndroidSessionInbox() {}

    static SessionInbox start(String verifiedPeer, long generation) {
        return new SessionInbox(verifiedPeer, generation, SystemClock::elapsedRealtime);
    }
}
