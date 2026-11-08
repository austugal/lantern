package org.austugal.lantern;

import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;

/** Bounded, strict decoding before the Flutter protocol validator. No receipt is sent here. */
final class NearbyPacketText {
    private NearbyPacketText() {}

    static String decode(byte[] bytes) {
        if (bytes == null || bytes.length == 0 || bytes.length > 8192) return null;
        try {
            return StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes)).toString();
        } catch (CharacterCodingException malformed) {
            return null;
        }
    }
}
