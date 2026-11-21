package com.antunes.app;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

/** Same eapi envelope as Sources/Kumone/Core/API/RequestCrypto.swift. */
public final class RequestCrypto {
    public static String hex(byte[] bytes) { StringBuilder s = new StringBuilder(bytes.length*2); for(byte b: bytes) s.append(String.format(java.util.Locale.ROOT,"%02x", b & 255)); return s.toString(); }
    public static String encrypt(String path, String json) throws Exception {
        String digest = hex(MessageDigest.getInstance("MD5").digest(("nobody" + path + "use" + json + "md5forencrypt").getBytes(StandardCharsets.UTF_8)));
        Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
        cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec("e82ckenh8dichen8".getBytes(StandardCharsets.UTF_8), "AES"));
        return hex(cipher.doFinal((path + "-36cd479b6b5-" + json + "-36cd479b6b5-" + digest).getBytes(StandardCharsets.UTF_8))).toUpperCase(java.util.Locale.ROOT);
    }
}
