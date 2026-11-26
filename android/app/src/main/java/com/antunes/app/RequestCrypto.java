package com.antunes.app;

import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.Map;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
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

    static Map<String, String> weapi(String json) throws Exception {
        String alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        SecureRandom random = new SecureRandom();
        StringBuilder secret = new StringBuilder(16);
        for (int i = 0; i < 16; i++) secret.append(alphabet.charAt(random.nextInt(alphabet.length())));
        String params = webAES(webAES(json, "0CoJUm6Qyw8W8jud"), secret.toString());
        String spki = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDgtQn2JZ34ZC28NWYpAUd98iZ37BUrX/aKzmFbt7clFSs6sXqHauqKWqdtLkF2KexO40H1YTX8z2lSgBBOAxLsvaklV8k4cBFK9snQXE9/DDaFt6Rr7iVZMldczhC0JNgTz+SHXT6CBHuX3e9SdB1Ua44oncaTWz7OBGLbCiK45wIDAQAB";
        Cipher rsa = Cipher.getInstance("RSA/ECB/NoPadding");
        rsa.init(Cipher.ENCRYPT_MODE, KeyFactory.getInstance("RSA").generatePublic(
                new X509EncodedKeySpec(Base64.getDecoder().decode(spki))));
        byte[] buffer = new byte[128];
        System.arraycopy(secret.reverse().toString().getBytes(StandardCharsets.US_ASCII), 0, buffer, 112, 16);
        return Map.of("params", params, "encSecKey", hex(rsa.doFinal(buffer)));
    }

    private static String webAES(String value, String key) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
        cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key.getBytes(StandardCharsets.US_ASCII), "AES"),
                new IvParameterSpec("0102030405060708".getBytes(StandardCharsets.US_ASCII)));
        return Base64.getEncoder().encodeToString(cipher.doFinal(value.getBytes(StandardCharsets.UTF_8)));
    }
}
