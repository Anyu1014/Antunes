package com.antunes.app;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import android.util.Log;
import org.json.*;
import javax.crypto.*;
import javax.crypto.spec.GCMParameterSpec;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;

final class MusicApi {
    private static MusicApi shared;
    static synchronized MusicApi shared(Context context) throws Exception { if(shared==null)shared=new MusicApi(context.getApplicationContext());return shared; }
    private final SharedPreferences prefs;
    private JSONObject cookies;
    private long epoch = 0;
    private static final Set<String> PATHS = Set.of(
        "/personalized/playlist", "/v1/discovery/recommend/resource", "/v3/discovery/recommend/songs",
        "/toplist", "/album/new", "/toplist/artist", "/playlist/list", "/playlist/highquality/list",
        "/v6/playlist/detail", "/v3/song/detail", "/cloudsearch/pc", "/search/suggest/web", "/search/defaultkeyword/get",
        "/song/enhance/player/url/v1", "/song/enhance/player/url", "/song/enhance/download/url/v1", "/song/lyric/v1", "/song/lyric",
        "/login/qrcode/unikey", "/login/qrcode/client/login", "/nuser/account/get", "/login/token/refresh",
        "/sms/captcha/sent", "/w/login/cellphone", "/logout", "/user/playlist", "/song/like/get",         "/album/sublist", "/artist/sublist", "/playmode/intelligence/list",
        "/playlist/create", "/playlist/remove", "/playlist/subscribe", "/playlist/unsubscribe", "/playlist/manipulate/tracks",
        "/album/sub", "/album/unsub", "/artist/sub", "/artist/unsub", "/v1/discovery/simiSong",
        "/v1/radio/get", "/radio/trash/add", "/v1/comment/like", "/v1/comment/unlike", "/cloud/get", "/cloud/del", "/play-record/song/list", "/feedback/weblog");
    MusicApi(Context context) throws Exception {
        prefs = context.getSharedPreferences("api", Context.MODE_PRIVATE);
        String device = prefs.getString("device", "");
        if (device.isEmpty()) { byte[] b = new byte[26]; new SecureRandom().nextBytes(b); prefs.edit().putString("device", RequestCrypto.hex(b).toUpperCase(Locale.ROOT)).commit(); }
        String saved = prefs.getString("auth", "");
        cookies = saved.isEmpty() ? new JSONObject() : new JSONObject(open(saved));
    }
    private SecretKey key() throws Exception {
        KeyStore ks = KeyStore.getInstance("AndroidKeyStore"); ks.load(null);
        if (ks.containsAlias("kumone-auth")) return (SecretKey) ks.getKey("kumone-auth", null);
        KeyGenerator gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        gen.init(new KeyGenParameterSpec.Builder("kumone-auth", KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
        return gen.generateKey();
    }
    private String seal(String plain) throws Exception {
        Cipher c = Cipher.getInstance("AES/GCM/NoPadding"); c.init(Cipher.ENCRYPT_MODE, key());
        return Base64.encodeToString(c.getIV(), Base64.NO_WRAP) + ":" + Base64.encodeToString(c.doFinal(plain.getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP);
    }
    private String open(String value) throws Exception {
        String[] parts = value.split(":", 2); Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
        c.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)));
        return new String(c.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), StandardCharsets.UTF_8);
    }
    synchronized boolean loggedIn() { return !cookies.optString("MUSIC_U").isEmpty(); }
    private synchronized void saveCookies(JSONObject value) throws Exception {
        String encoded = seal(value.toString());
        if (!prefs.edit().putString("auth", encoded).commit()) throw new IOException("登录状态保存失败");
        cookies = value;
    }
    synchronized void logout() throws Exception { saveCookies(new JSONObject()); epoch++; }
    synchronized JSONObject status() throws JSONException { return new JSONObject().put("loggedIn", loggedIn()); }
    JSONObject cookieLogin(String raw) throws Exception {
        JSONObject candidate = new JSONObject();
        for (String part : raw.split(";")) {
            String[] pair = part.trim().split("=", 2);
            if (!Set.of("MUSIC_U", "__csrf").contains(pair[0])) continue;
            if (pair.length != 2 || candidate.has(pair[0]) || pair[1].isEmpty()) throw new Exception("Cookie 格式错误");
            for(char c:pair[1].toCharArray())if(c<0x21||c>0x7e||c=='"'||c==','||c=='\\')throw new Exception("Cookie 格式错误");
            candidate.put(pair[0], pair[1]);
        }
        if (candidate.optString("MUSIC_U").isEmpty()) throw new Exception("请输入包含 MUSIC_U 的有效 Cookie");
        long before; synchronized (this) { before = epoch; }
        JSONObject result = transport("/nuser/account/get", new JSONObject(), candidate, -1);
        if (result.optInt("code") != 200 || result.isNull("profile") || result.optJSONObject("profile").optLong("userId") <= 0) throw new Exception("Cookie 登录验证失败");
        synchronized (this) { if (epoch != before) throw new Exception("登录状态已改变，请重试"); saveCookies(candidate); epoch++; }
        return result;
    }
    static boolean allowedPath(String path) {
        if (path == null) return false;
        // 查询串/片段不参与白名单比对，避免 /xxx?a=1 这类写法被误判成未知接口。
        String bare = path.split("[?#]")[0];
        return PATHS.contains(bare) || bare.matches("/(v1/(album|artist)|artist/albums)/[0-9]+") || bare.matches("/v1/resource/comments/R_SO_4_[0-9]+");
    }
    JSONObject request(String path, JSONObject payload) throws Exception {
        if (!allowedPath(path)) {
            Log.w("AntunesApi", "未识别的接口: " + path + " payload=" + payload);
            // 把路径带进提示，出错时一眼能看出是哪个接口，而不是只有一句「未识别的接口」。
            throw new Exception("未识别的接口: " + path);
        }
        JSONObject jar; long generation;
        synchronized (this) { jar = new JSONObject(cookies.toString()); generation = epoch; }
        return transport(path, payload, jar, generation);
    }
    private JSONObject transport(String path, JSONObject payload, JSONObject jar, long generation) throws Exception {
        boolean plain = Set.of("/sms/captcha/sent", "/w/login/cellphone", "/artist/sub", "/artist/unsub").contains(path);
        String host = plain ? "music.163.com" : "interface.music.163.com";
        boolean media = path.startsWith("/song/enhance/");
        JSONObject header = new JSONObject().put("osver", "Microsoft-Windows-10-Professional-build-19045-64bit").put("deviceId", prefs.getString("device", "")).put("os", "pc").put("appver", media ? "2.9.7" : "3.1.17.204416").put("versioncode", media ? "100" : "140").put("mobilename", "").put("buildver", "" + System.currentTimeMillis()/1000).put("resolution", "1920x1080").put("channel", "netease").put("requestId", System.currentTimeMillis()+"_"+new SecureRandom().nextInt(10000)).put("__csrf", jar.optString("__csrf"));
        for (Iterator<String> keys = jar.keys(); keys.hasNext();) { String k = keys.next(); header.put(k, jar.get(k)); }
        String body;
        if (plain) {
            StringJoiner fields = new StringJoiner("&");
            for (Iterator<String> keys = payload.keys(); keys.hasNext();) { String k = keys.next(); fields.add(URLEncoder.encode(k, "UTF-8")+"="+URLEncoder.encode(payload.get(k).toString(), "UTF-8")); }
            body = fields.toString();
        } else {
            payload.put("header", header).put("e_r", false);
            body = "params=" + RequestCrypto.encrypt("/api" + path, payload.toString());
        }
        HttpURLConnection con = (HttpURLConnection) new URL("https://"+host+(plain?"/api":"/eapi")+path).openConnection();
        con.setInstanceFollowRedirects(false); con.setConnectTimeout(15000); con.setReadTimeout(20000); con.setRequestMethod("POST"); con.setDoOutput(true);
        con.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
        con.setRequestProperty("Referer", "https://music.163.com");
        con.setRequestProperty("User-Agent", plain ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/17.0 Safari/605.1.15" : "NeteaseMusic 9.0.90/5038 (iPhone; iOS 16.2; zh_CN)");
        StringJoiner cookieHeader = new StringJoiner("; ");
        for (Iterator<String> keys = header.keys(); keys.hasNext();) { String k = keys.next(); cookieHeader.add(k+"="+header.get(k)); }
        con.setRequestProperty("Cookie", cookieHeader.toString());
        try {
            try (OutputStream out = con.getOutputStream()) { out.write(body.getBytes(StandardCharsets.UTF_8)); }
            if (con.getResponseCode() != 200) throw new IOException("网络错误 ("+con.getResponseCode()+")");
            byte[] data;
            try (InputStream in = con.getInputStream()) { data = in.readNBytes(12 * 1024 * 1024 + 1); }
            if (data.length > 12*1024*1024) throw new IOException("接口响应过大");
            JSONObject result = new JSONObject(new String(data, StandardCharsets.UTF_8));
            int code = result.optInt("code", 200);
            synchronized (this) {
                if (generation >= 0 && generation != epoch) throw new IOException("登录状态已改变，请重试");
                if (generation >= 0 && (code == 200 || code == 803)) {
                    JSONObject next = new JSONObject(cookies.toString()); boolean changed = false;
                    for (Map.Entry<String, List<String>> field : con.getHeaderFields().entrySet()) if ("Set-Cookie".equalsIgnoreCase(field.getKey())) {
                        for (String value : field.getValue()) for (HttpCookie c : HttpCookie.parse(value)) {
                            if (Set.of("MUSIC_U", "__csrf", "NMTID").contains(c.getName()) && !c.getValue().isEmpty()) { next.put(c.getName(), c.getValue()); changed = true; }
                        }
                    }
                    if (changed) { boolean loginChanged = !next.optString("MUSIC_U").equals(cookies.optString("MUSIC_U")); saveCookies(next); if (loginChanged) epoch++; }
                }
            }
            if (code != 200 && !(path.startsWith("/login/qrcode/") && code >= 800 && code <= 803)) throw new IOException(code == 301 ? "需要登录" : result.optString("message", result.optString("msg", "接口错误 ("+code+")")));
            return result;
        } finally { con.disconnect(); }
    }
    String audioURL(long id, String ignoredQuality) throws Exception {
        // 音质锁定极高：不再接受其它档位。
        String quality = "exhigh";
        JSONObject first = null;
        try {
            JSONObject result = request("/song/enhance/player/url/v1", new JSONObject().put("ids", "["+id+"]").put("level", quality).put("encodeType", "flac"));
            first = result.getJSONArray("data").getJSONObject(0);
            String candidate = first.optString("url", "");
            if (candidate.isEmpty() || candidate.equals("null")) first = null;
        } catch (IOException e) { first = null; }
        if (first == null) {
            // v1 is risk-gated for some client builds; the older endpoint still answers.
            JSONObject result = request("/song/enhance/player/url", new JSONObject().put("ids", "["+id+"]").put("br", 320000));
            first = result.getJSONArray("data").getJSONObject(0);
        }
        String url = first.optString("url", "");
        if (url.isEmpty() || url.equals("null")) throw new IOException("当前歌曲暂无可播放音源");
        // A trial fragment is what the account is entitled to; play it rather than failing.
        return checkedMediaURL(url);
    }
    static String checkedMediaURL(String value) throws Exception {
        URI uri = URI.create(value); String host = uri.getHost();
        if (host == null || !host.endsWith(".music.126.net") || uri.getUserInfo() != null || (uri.getPort() != -1 && uri.getPort() != 443 && uri.getPort() != 80) || !Set.of("http", "https").contains(uri.getScheme())) throw new IOException("音频地址无效");
        return value.replaceFirst("^http:", "https:");
    }
}
