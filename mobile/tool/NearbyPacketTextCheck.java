package org.austugal.lantern;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/** Standalone byte-boundary checks; no Android device, radio or JSON parser. */
public final class NearbyPacketTextCheck {
    private static int checks;

    private static void require(boolean passed, String reason) {
        checks++;
        if (!passed) throw new AssertionError(reason);
    }

    private static byte[] bytes(int... values) {
        byte[] result = new byte[values.length];
        for (int i = 0; i < values.length; i++) result[i] = (byte) values[i];
        return result;
    }

    private static void reject(String reason, int... values) {
        require(NearbyPacketText.decode(bytes(values)) == null, reason);
    }

    private static void roundTrip(String text) {
        byte[] encoded = text.getBytes(StandardCharsets.UTF_8);
        byte[] unchanged = encoded.clone();
        require(text.equals(NearbyPacketText.decode(encoded)), "changed valid Unicode");
        require(Arrays.equals(encoded, unchanged), "mutated caller bytes");
    }

    public static void main(String[] args) {
        require(NearbyPacketText.decode(null) == null, "null accepted");
        reject("empty accepted");
        reject("isolated continuation accepted", 0x80);
        reject("overlong two-byte encoding accepted", 0xc0, 0xaf);
        reject("overlong three-byte encoding accepted", 0xe0, 0x80, 0xaf);
        reject("overlong four-byte encoding accepted", 0xf0, 0x80, 0x80, 0xaf);
        reject("high surrogate accepted", 0xed, 0xa0, 0x80);
        reject("low surrogate accepted", 0xed, 0xbf, 0xbf);
        reject("out-of-range code point accepted", 0xf4, 0x90, 0x80, 0x80);
        reject("invalid leading byte accepted", 0xff);
        reject("five-byte encoding accepted", 0xf8, 0x88, 0x80, 0x80, 0x80);
        reject("truncated two-byte sequence accepted", 0xc2);
        reject("truncated three-byte sequence accepted", 0xe2, 0x82);
        reject("truncated four-byte sequence accepted", 0xf0, 0x9f, 0x98);
        reject("ASCII in continuation position accepted", 0xe2, 0x41, 0xac);
        reject("malformed byte inside JSON string accepted", 0x7b, 0x22, 0x78, 0x22,
                0x3a, 0x22, 0xff, 0x22, 0x7d);

        roundTrip("{\"text\":\"Lisboa — Olá, 東京, 😀\"}");
        roundTrip("\uFFFD"); // A real replacement character is valid UTF-8.
        roundTrip("\u0000\u007f\u0080\u07ff\u0800\ud7ff\ue000\uffff");
        roundTrip(new String(Character.toChars(0x10ffff)));

        byte[] ascii = new byte[8192];
        Arrays.fill(ascii, (byte) 'a');
        require(NearbyPacketText.decode(ascii).length() == 8192, "exact byte limit rejected");
        require(NearbyPacketText.decode(Arrays.copyOf(ascii, 8193)) == null,
                "over-limit input accepted");
        String exactMultibyte = "a".repeat(8188) + "😀";
        roundTrip(exactMultibyte);
        byte[] encoded = exactMultibyte.getBytes(StandardCharsets.UTF_8);
        require(encoded.length == 8192, "fixture is not at exact byte limit");
        require(NearbyPacketText.decode(Arrays.copyOf(encoded, 8191)) == null,
                "truncated sequence at size boundary accepted");
        require(NearbyPacketText.decode((exactMultibyte + "a").getBytes(StandardCharsets.UTF_8)) == null,
                "multibyte payload beyond byte limit accepted");
        roundTrip("after rejection"); // One malformed packet must not poison later decoding.
        System.out.println("NearbyPacketText JVM checks passed: " + checks);
    }
}
