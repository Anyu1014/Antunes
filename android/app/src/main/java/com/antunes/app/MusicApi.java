package com.antunes.app;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.BitmapFactory;
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
import java.util.Arrays;
import java.util.Collections;
import java.util.*;

final class MusicApi {
    private static MusicApi shared;
    static synchronized MusicApi shared(Context context) throws Exception { if(shared==null)shared=new MusicApi(context.getApplicationContext());return shared; }
    private final SharedPreferences prefs;
    private JSONObject cookies;
    private long epoch = 0;
    static final int MAX_COVER_BYTES = 768 * 1024;
    private static final Set<String> PATHS = Set.of(
        "/personalized/playlist", "/v1/discovery/recommend/resource", "/v3/discovery/recommend/songs",
        "/homepage/block/page",
        "/top/song",
        "/personalized/newsong",
        "/simi/song",
        "/toplist", "/album/new", "/toplist/artist", "/playlist/list", "/playlist/highquality/list",
        "/v6/playlist/detail", "/v3/song/detail", "/cloudsearch/pc", "/search/suggest/web", "/search/defaultkeyword/get",
        "/song/enhance/player/url/v1", "/song/enhance/player/url", "/song/enhance/download/url/v1", "/song/lyric/v1", "/song/lyric",
        "/login/qrcode/unikey", "/login/qrcode/client/login", "/nuser/account/get", "/login/token/refresh",
        "/sms/captcha/sent", "/w/login/cellphone", "/logout", "/user/playlist", "/song/like/get",         "/album/sublist", "/artist/sublist", "/playmode/intelligence/list",
        "/playlist/create", "/playlist/desc/update", "/playlist/remove", "/playlist/subscribe", "/playlist/unsubscribe", "/playlist/manipulate/tracks",
        "/album/sub", "/album/unsub", "/artist/sub", "/artist/unsub", "/v1/discovery/simiSong",
        "/v1/radio/get", "/radio/trash/add", "/v1/play/record", "/msg/private/users", "/msg/private/history", "/msg/private/send",
        "/v1/comment/like", "/v1/comment/unlike", "/radio/like", "/like", "/cloud/get", "/cloud/del", "/play-record/song/list", "/feedback/weblog");
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
    synchronized long sessionEpoch() { return epoch; }
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
        return request(path, payload, sessionEpoch());
    }
    JSONObject request(String path, JSONObject payload, long submittedSession) throws Exception {
        if (!allowedPath(path)) {
            Log.w("AntunesApi", "未识别的接口: " + path + " payload=" + payload);
            // 把路径带进提示，出错时一眼能看出是哪个接口，而不是只有一句「未识别的接口」。
            throw new Exception("未识别的接口: " + path);
        }
        JSONObject jar; long generation;
        synchronized (this) {
            // A queued private request must not inherit a newly logged-in account.
            String bare = path.split("[?#]")[0];
            boolean editing = bare.equals("/playlist/desc/update"), deleting = bare.equals("/playlist/remove");
            if ((path.startsWith("/msg/private/") || editing || deleting) && submittedSession != epoch) {
                throw new IOException("登录状态已改变，请重试");
            }
            if ((editing || deleting) && !loggedIn()) throw new IOException("需要登录");
            if (editing) {
                if (payload.optLong("id") <= 0 || !(payload.opt("desc") instanceof String value) || value.length() > 1000)
                    throw new IOException("歌单简介无效");
            }
            jar = new JSONObject(cookies.toString());
            generation = epoch;
        }
        return transport(path, payload, jar, generation);
    }
    private synchronized JSONObject playlistCredentials(long submittedSession) throws Exception {
        if (submittedSession != epoch) throw new IOException("登录状态已改变，请重试");
        if (!loggedIn()) throw new IOException("需要登录");
        return new JSONObject(cookies.toString());
    }

    String updatePlaylistCover(long id, String encoded, long submittedSession) throws Exception {
        if (id <= 0 || encoded.length() > MAX_COVER_BYTES * 4 / 3 + 4) throw new IOException("封面图片无效");
        byte[] jpeg = Base64.decode(encoded, Base64.NO_WRAP);
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeByteArray(jpeg, 0, jpeg.length, bounds);
        if (jpeg.length > MAX_COVER_BYTES || !"image/jpeg".equals(bounds.outMimeType)
                || bounds.outWidth < 1 || bounds.outWidth != bounds.outHeight || bounds.outWidth > 640)
            throw new IOException("封面图片无效");

        String key, token;
        Object coverId;
        try {
            JSONObject allocPayload = new JSONObject()
                    .put("bucket", "yyimgs").put("ext", "jpg").put("filename", "playlist.jpg")
                    .put("local", false).put("nos_product", 0).put("type", "other")
                    .put("return_body", "{\"code\":200,\"size\":\"$(ObjectSize)\"}");
            // eapi 优先：token 与 App 通道的登录态同源；拿不到再走 weapi。
            // eapi 与 weapi 都可能下发 token；只认纯 ASCII、非空的，哪条能给就用哪条。
            JSONObject slot = null;
            String slotToken = null, slotKey = null;
            Object slotId = null;
            String[][] attempts = {{"eapi", "1"}, {"weapi", "0"}};
            for (String[] attempt : attempts) {
                boolean asEapi = "1".equals(attempt[1]);
                try {
                    JSONObject raw = asEapi
                            ? transport("/nos/token/alloc", allocPayload, playlistCredentials(submittedSession), submittedSession, true)
                            : transport("/nos/token/alloc", allocPayload, playlistCredentials(submittedSession), submittedSession);
                    JSONObject candidate = raw.getJSONObject("result");
                    String candidateToken = candidate.optString("token", "").replaceAll("[\\r\\n]", "").trim();
                    Object candidateId = candidate.opt("docId");
                    // NOS token 是「两段用空格连起来」的形态，允许中间出现空格，但首尾不行。
                    boolean tokenOk = candidateToken.matches("[!-~](?:[ -~]{0,4094}[!-~])?");
                    boolean idOk = candidateId != null && candidateId.toString().matches("[0-9]{1,24}");
                    Log.i("MusicApi", "cover alloc " + attempt[0] + " ok=" + (tokenOk && idOk));
                    if (tokenOk && idOk) { slot = candidate; slotToken = candidateToken; slotId = candidateId; break; }
                } catch (Exception attemptFailure) {
                    Log.w("MusicApi", "cover alloc " + attempt[0] + " failed: " + attemptFailure);
                }
            }
            if (slot == null) throw new IOException("封面上传凭证无效");
            key = playlistCoverPath(slot.getString("objectKey"));
            token = slotToken;
            coverId = slotId;
        } catch (Exception e) {
            Log.w("MusicApi", "cover alloc failed: " + e, e);
            playlistCredentials(submittedSession);
            throw new IOException("获取封面上传凭证失败，请重试", e);
        }
        playlistCredentials(submittedSession);
        String uploadHost = nosUploadHost("yyimgs");
        Log.i("MusicApi", "cover upload host=" + uploadHost + " bytes=" + jpeg.length);
        HttpURLConnection upload = (HttpURLConnection) new URL(uploadHost + "/yyimgs/" + key + "?offset=0&complete=true&version=1.0").openConnection();
        try {
            // 上传机常把请求转到真正的存储节点，禁跳转会被判成失败。
            upload.setInstanceFollowRedirects(true);
            upload.setConnectTimeout(15000);
            upload.setReadTimeout(20000);
            upload.setRequestMethod("POST");
            upload.setDoOutput(true);
            upload.setFixedLengthStreamingMode(jpeg.length);
            upload.setRequestProperty("x-nos-token", token);
            upload.setRequestProperty("Content-Type", "image/jpeg");
            try (OutputStream out = upload.getOutputStream()) { out.write(jpeg); }
            int uploadStatus = upload.getResponseCode();
            Log.i("MusicApi", "cover upload status=" + uploadStatus);
            if (uploadStatus < 200 || uploadStatus >= 400) throw new IOException("NOS response " + uploadStatus);
        } catch (IOException e) {
            Log.w("MusicApi", "cover upload failed: " + e.getMessage(), e);
            playlistCredentials(submittedSession);
            throw new IOException("图片上传失败，请重试", e);
        } finally { upload.disconnect(); }
        JSONObject result;
        try {
            result = transport("/playlist/cover/update", new JSONObject().put("id", id).put("coverImgId", coverId),
                    playlistCredentials(submittedSession), submittedSession);
        } catch (Exception e) {
            playlistCredentials(submittedSession);
            throw new IOException("更新歌单封面失败，请重试", e);
        }
        String url = result.optString("url").replaceFirst("^http:", "https:");
        if (url.matches("https://[A-Za-z0-9-]+\\.music\\.126\\.net/[^\\s]+")) return url;
        return "https://p1.music.126.net/" + key;
    }

    // NOS 上传域名由 LBS 下发，nosup-hz1 只是兜底。
    private static String nosUploadHost(String bucket) {
        String fallback = "https://nosup-hz1.127.net";
        HttpURLConnection con = null;
        try {
            con = (HttpURLConnection) new URL("https://wanproxy.127.net/lbs?version=1.0&bucketname=" + bucket).openConnection();
            con.setConnectTimeout(5000);
            con.setReadTimeout(5000);
            if (con.getResponseCode() != 200) return fallback;
            java.io.ByteArrayOutputStream buffer = new java.io.ByteArrayOutputStream();
            try (java.io.InputStream in = con.getInputStream()) {
                byte[] chunk = new byte[4096];
                int read;
                while ((read = in.read(chunk)) > 0) buffer.write(chunk, 0, read);
            }
            JSONArray hosts = new JSONObject(buffer.toString("UTF-8")).optJSONArray("upload");
            if (hosts == null || hosts.length() == 0) return fallback;
            String host = hosts.optString(0, "").trim().replaceAll("/+$", "");
            if (host.isEmpty()) return fallback;
            // LBS 常下发 http://，Android 默认拦明文；统一升到 https（同一台机器 443 可用）。
            host = host.replaceFirst("^http://", "https://");
            return host.startsWith("https://") ? host : "https://" + host;
        } catch (Exception e) {
            return fallback;
        } finally {
            if (con != null) con.disconnect();
        }
    }

    private static String playlistCoverPath(String key) throws IOException {
        if (key.isEmpty() || key.getBytes(StandardCharsets.UTF_8).length > 512) throw new IOException("无效图片路径");
        String relative = key.startsWith("/") ? key.substring(1) : key;
        StringJoiner path = new StringJoiner("/");
        for (String part : relative.split("/", -1)) {
            if (part.isEmpty() || part.equals(".") || part.equals("..")) throw new IOException("无效图片路径");
            path.add(URLEncoder.encode(part, "UTF-8").replace("+", "%20").replace("*", "%2A").replace("%7E", "~"));
        }
        return path.toString();
    }

    private JSONObject transport(String path, JSONObject payload, JSONObject jar, long generation) throws Exception {
        return transport(path, payload, jar, generation, false);
    }

    private JSONObject transport(String path, JSONObject payload, JSONObject jar, long generation, boolean forceEapi) throws Exception {
        boolean plain = Set.of("/sms/captcha/sent", "/w/login/cellphone", "/artist/sub", "/artist/unsub").contains(path);
        boolean webEncrypted = !forceEapi && (path.equals("/nos/token/alloc") || path.equals("/playlist/cover/update"));
        boolean web = plain || webEncrypted;
        String host = web ? "music.163.com" : "interface.music.163.com";
        boolean media = path.startsWith("/song/enhance/");
        JSONObject header = new JSONObject().put("osver", "Microsoft-Windows-10-Professional-build-19045-64bit").put("deviceId", prefs.getString("device", "")).put("os", "pc").put("appver", media ? "2.9.7" : "3.1.17.204416").put("versioncode", media ? "100" : "140").put("mobilename", "").put("buildver", "" + System.currentTimeMillis()/1000).put("resolution", "1920x1080").put("channel", "netease").put("requestId", System.currentTimeMillis()+"_"+new SecureRandom().nextInt(10000)).put("__csrf", jar.optString("__csrf"));
        for (Iterator<String> keys = jar.keys(); keys.hasNext();) { String k = keys.next(); header.put(k, jar.get(k)); }
        String body;
        if (webEncrypted) {
            payload.put("csrf_token", jar.optString("__csrf")).put("e_r", false);
            Map<String, String> form = RequestCrypto.weapi(payload.toString());
            body = "params=" + URLEncoder.encode(form.get("params"), "UTF-8") + "&encSecKey=" + form.get("encSecKey");
        } else if (plain) {
            StringJoiner fields = new StringJoiner("&");
            for (Iterator<String> keys = payload.keys(); keys.hasNext();) { String k = keys.next(); fields.add(URLEncoder.encode(k, "UTF-8")+"="+URLEncoder.encode(payload.get(k).toString(), "UTF-8")); }
            body = fields.toString();
        } else {
            payload.put("header", header).put("e_r", false);
            body = "params=" + RequestCrypto.encrypt("/api" + path, payload.toString());
        }
        HttpURLConnection con = (HttpURLConnection) new URL("https://"+host+(webEncrypted?"/weapi":plain?"/api":"/eapi")+path).openConnection();
        con.setInstanceFollowRedirects(false); con.setConnectTimeout(15000); con.setReadTimeout(20000); con.setRequestMethod("POST"); con.setDoOutput(true);
        con.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
        con.setRequestProperty("Referer", "https://music.163.com");
        con.setRequestProperty("User-Agent", web ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/17.0 Safari/605.1.15" : "NeteaseMusic 9.0.90/5038 (iPhone; iOS 16.2; zh_CN)");
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
                if (!webEncrypted && generation >= 0 && (code == 200 || code == 803)) {
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
    /** 音质档位，从高到低；与 /song/enhance/player/url/v1 的 level 取值一致。 */
    static final java.util.List<String> QUALITY_LEVELS =
            java.util.List.of("jymaster", "sky", "jyeffect", "hires", "lossless", "exhigh", "standard");

    static String normalizeQuality(String value) {
        if (value == null) return "exhigh";
        String trimmed = value.trim();
        if (trimmed.isEmpty() || "higher".equals(trimmed)) return "exhigh";
        return QUALITY_LEVELS.contains(trimmed) ? trimmed : "exhigh";
    }

    /** 从请求档位开始往下降，直到标准档。 */
    static java.util.List<String> qualityFallbacks(String requested) {
        int start = QUALITY_LEVELS.indexOf(normalizeQuality(requested));
        return QUALITY_LEVELS.subList(start < 0 ? QUALITY_LEVELS.size() - 2 : start, QUALITY_LEVELS.size());
    }

    /** 上一次 audioURL 实际拿到的档位（阶梯降档后会变），供播放服务展示。 */
    volatile String lastResolvedLevel = "";

    /** 上一次 audioURL 实际拿到的文件类型（mp3 / flac），用来决定要不要走本地整曲播放。 */
    volatile String lastResolvedType = "";

    String audioURL(long id, String requestedQuality) throws Exception {
        // 该档拿不到地址时逐档下降；只对「没有 url」降档，拿到地址就用。
        for (String quality : qualityFallbacks(requestedQuality)) {
            JSONObject payload = new JSONObject()
                    .put("ids", "["+id+"]").put("level", quality).put("encodeType", "flac");
            if ("sky".equals(quality)) payload.put("immerseType", "c51");
            JSONObject result = request("/song/enhance/player/url/v1", payload);
            JSONObject found = result.getJSONArray("data").getJSONObject(0);
            String url = found.optString("url", "");
            if (!url.isEmpty() && !url.equals("null")) {
                // 服务端会把无损以上的档位一律回成 level=lossless，但码率能看出真实档位。
                lastResolvedLevel = servedLevel(found.optInt("br",0), found.optString("type",""));
                lastResolvedType = found.optString("type","");
                return checkedMediaURL(url);
            }
        }
        {
            JSONObject legacy = request("/song/enhance/player/url", new JSONObject().put("ids", "["+id+"]").put("br", 320000));
            JSONObject found = legacy.getJSONArray("data").getJSONObject(0);
            String url = found.optString("url", "");
            if (!url.isEmpty() && !url.equals("null")) { lastResolvedLevel = "exhigh"; return checkedMediaURL(url); }
        }
        throw new IOException("当前歌曲暂无可播放音源");
    }

    /** 按码率/格式推断实际拿到的档位（与 iOS 的 SongURLData.servedQualityLevel 同一套阈值）。 */
    static String servedLevel(int br, String type) {
        String format = type == null ? "" : type.toLowerCase();
        if (format.equals("flac") || format.equals("ape") || format.equals("wav")) {
            if (br >= 1_400_000) return "hires";
            if (br >= 700_000) return "lossless";
            return "exhigh";
        }
        if (br >= 256_000) return "exhigh";
        if (br >= 160_000) return "higher";
        return "standard";
    }

    static String checkedMediaURL(String value) throws Exception {
        URI uri = URI.create(value); String host = uri.getHost();
        if (host == null || !host.endsWith(".music.126.net") || uri.getUserInfo() != null || (uri.getPort() != -1 && uri.getPort() != 443 && uri.getPort() != 80) || !Set.of("http", "https").contains(uri.getScheme())) throw new IOException("音频地址无效");
        return value.replaceFirst("^http:", "https:");
    }
}
