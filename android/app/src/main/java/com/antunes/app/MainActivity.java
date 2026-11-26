package com.antunes.app;

import android.app.*;
import android.content.*;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.ImageDecoder;
import android.os.*;
import android.view.*;
import android.webkit.*;
import org.json.*;
import java.io.*;
import java.net.*;
import java.util.*;
import java.util.concurrent.*;

public class MainActivity extends Activity {
    WebView web;
    MusicApi api;
    final ExecutorService network=Executors.newFixedThreadPool(4);
    final Handler ui=new Handler(Looper.getMainLooper());
    boolean destroyed=false;
    private static final int PLAYLIST_COVER_REQUEST=42;
    private String coverPickerRequest;
    private long coverPickerSession;
    final BroadcastReceiver playback=new BroadcastReceiver(){public void onReceive(Context c,Intent i){emitState();}};
    @Override public void onCreate(Bundle saved){
        super.onCreate(saved);
        try{api=MusicApi.shared(this);}catch(Exception e){new AlertDialog.Builder(this).setMessage("登录存储读取失败，请重启后重试。原有数据已保留。").setPositiveButton("关闭",(d,w)->finish()).show();return;}
        getWindow().setStatusBarColor(Color.TRANSPARENT);getWindow().setNavigationBarColor(Color.TRANSPARENT);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE|View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        getWindow().setNavigationBarContrastEnforced(false);
        web=new WebView(this);setContentView(web);
        web.setBackgroundColor(Color.WHITE);
        WebSettings settings=web.getSettings();settings.setJavaScriptEnabled(true);settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);settings.setAllowContentAccess(false);settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setMediaPlaybackRequiresUserGesture(true);settings.setSupportMultipleWindows(false);
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG);
        web.addJavascriptInterface(new Bridge(),"KumoneNative");
        web.setWebViewClient(new WebViewClient(){
            @Override public boolean shouldOverrideUrlLoading(WebView view,WebResourceRequest req){return !"app.kumone.local".equals(req.getUrl().getHost());}
            @Override public WebResourceResponse shouldInterceptRequest(WebView view,WebResourceRequest req){
                if(!"app.kumone.local".equals(req.getUrl().getHost()))return null;
                String path=req.getUrl().getPath();
                if(path==null||path.contains(".."))return empty(403);
                if(path.equals("/"))path="/index.html";
                try{
                    String mime=(path.endsWith(".js")||path.endsWith(".mjs"))?"text/javascript":path.endsWith(".css")?"text/css":path.endsWith(".png")?"image/png":path.endsWith(".txt")?"text/plain":"text/html";
                    // 调试包优先读 files/hot/ 下的同名文件：改完资源 adb push 进这个目录再刷新页面即生效，不必重装
                    File hot=new File(new File(getFilesDir(),"hot"),path.substring(1));
                    if(BuildConfig.DEBUG&&hot.isFile())return new WebResourceResponse(mime,"UTF-8",new FileInputStream(hot));
                    return new WebResourceResponse(mime,"UTF-8",getAssets().open(path.substring(1)));
                }catch(Exception e){return empty(404);}
            }
            @Override public void onPageFinished(WebView view,String url){
                android.graphics.Insets insets=getWindow().getDecorView().getRootWindowInsets().getInsets(WindowInsets.Type.systemBars());
                float density=getResources().getDisplayMetrics().density;
                web.evaluateJavascript("document.documentElement.style.setProperty('--safe-top','"+insets.top/density+"px');document.documentElement.style.setProperty('--safe-bottom','"+insets.bottom/density+"px');",null);
                emitState();
            }
        });
        registerReceiver(playback,new IntentFilter(PlaybackService.EVENT),RECEIVER_NOT_EXPORTED);
        web.loadUrl("https://app.kumone.local/");
        ui.post(tick);
    }
    private WebResourceResponse empty(int status){return new WebResourceResponse("text/plain","UTF-8",status,status==404?"Not Found":"Forbidden",Map.of(),new ByteArrayInputStream(new byte[0]));}
    private void reply(String id,Object data,String error){
        try{JSONObject result=new JSONObject().put("id",id).put("data",data==null?JSONObject.NULL:data).put("error",error==null?JSONObject.NULL:error);evaluate("window.dispatchEvent(new CustomEvent('native-reply',{detail:"+result+"}));");}catch(JSONException ignored){}
    }
    void evaluate(String js){ui.post(()->{if(!destroyed&&web!=null)web.evaluateJavascript(js,null);});}
    void emitState(){PlaybackService s=PlaybackService.current;if(s!=null)evaluate("window.dispatchEvent(new CustomEvent('playback',{detail:"+s.state()+"}));");}
    final Runnable tick=new Runnable(){public void run(){if(destroyed)return;emitState();ui.postDelayed(this,500);}};
    class Bridge{
        @JavascriptInterface public void call(String id,String operation,String raw){
            if(id.length()>100||raw.length()>2*1024*1024)return;
            final long requestSession=api.sessionEpoch();
            network.execute(()->{try{
                JSONObject a=new JSONObject(raw);Object result=new JSONObject();
                switch(operation){
                    case "status":result=api.status();break;
                    case "request":result=api.request(a.getString("path"),a.optJSONObject("payload")==null?new JSONObject():a.getJSONObject("payload"),requestSession);break;
                    case "pickPlaylistCover":ui.post(()->pickPlaylistCover(id,requestSession));return;
                    case "updatePlaylistCover":result=api.updatePlaylistCover(a.getLong("id"),a.getString("jpeg"),requestSession);break;
                    case "cookieLogin":result=api.cookieLogin(a.getString("cookie"));break;
                    case "logout":api.logout();break;
                    case "position":
                        result=PlaybackService.current!=null?PlaybackService.current.positionState():new JSONObject().put("position",0).put("playing",false);
                        break;
                    case "state":
                        if(PlaybackService.current!=null)result=PlaybackService.current.state();
                        else {android.content.SharedPreferences p=getSharedPreferences("player",MODE_PRIVATE);result=new JSONObject().put("queue",new JSONArray(p.getString("queue","[]"))).put("index",p.getInt("index",0)).put("mode",p.getString("mode","list")).put("playing",false).put("position",p.getInt("position",0)).put("duration",0);}
                        break;
                    case "control":ui.post(()->control(a));break;
                    // 音质七档（与 MeloX 一致）：写进偏好，播放时按档位请求，
                    // 拿不到会自动往下降。
                    case "quality":getSharedPreferences("player",MODE_PRIVATE).edit().putString("quality",MusicApi.normalizeQuality(a.optString("value"))).apply();break;
                    case "downloadQuality":getSharedPreferences("player",MODE_PRIVATE).edit().putString("download_quality",MusicApi.normalizeQuality(a.optString("value"))).apply();break;
                    case "eq":
                        JSONArray bands=a.getJSONArray("bands");if(bands.length()!=10)throw new Exception("音效参数无效");for(int n=0;n<10;n++)if(Math.abs(bands.getInt(n))>12)throw new Exception("音效参数无效");
                        getSharedPreferences("player",MODE_PRIVATE).edit().putString("eq",bands.toString()).putBoolean("eqEnabled",a.optBoolean("enabled")).apply();ui.post(()->{if(PlaybackService.current!=null)PlaybackService.current.applyEQ();});break;
                    case "downloads":result=downloads();break;
                    case "saveLyric":saveLyric(a.getString("id"),a.getString("text"));break;
                    case "lyric":result=readLyric(a.getString("id"));break;
                    case "lyricStats":result=lyricStats();break;
                    case "clearLyrics":clearLyrics();break;
                    case "download":result=download(a.getJSONObject("track"));break;
                    case "deleteDownload":
                        long songId=a.getLong("id");if(songId<=0)throw new Exception("歌曲无效");
                        File audio=new File(getFilesDir(),"audio/"+songId+".audio");if(audio.exists()&&!audio.delete())throw new IOException("文件删除失败");
                        File meta=new File(getFilesDir(),"audio/"+songId+".json");if(meta.exists()&&!meta.delete())throw new IOException("元数据删除失败");
                        File merged=new File(getFilesDir(),"audio/"+songId+".txt");if(merged.exists())merged.delete();
                        File stray=new File(lyricsDir(),songId+".txt");if(stray.exists())stray.delete();
                        break;
                    case "openUrl":
                        String href=a.optString("url","");
                        if(href.startsWith("https://")||href.startsWith("http://")){
                            ui.post(()->{ try{ startActivity(new Intent(Intent.ACTION_VIEW,android.net.Uri.parse(href))); }catch(Exception ignored){} });
                        }
                        break;
                    case "theme":ui.post(()->{boolean dark=a.optBoolean("dark");getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE|View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION|(dark?0:View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR));web.setBackgroundColor(dark?Color.rgb(18,18,20):Color.WHITE);});break;
                    default:throw new Exception("未识别的操作");
                }
                reply(id,result,null);
            }catch(Exception e){String message=(operation.equals("cookieLogin"))?"Cookie 登录验证失败，请检查后重试":e instanceof SocketTimeoutException?"网络连接超时，请重试":e.getMessage();reply(id,null,message==null?"操作失败，请重试":message);}});
        }
    }
    private void pickPlaylistCover(String request, long session){
        if(coverPickerRequest!=null){reply(request,null,"正在选择封面");return;}
        if(session!=api.sessionEpoch()||!api.loggedIn()){reply(request,null,"登录状态已改变，请重试");return;}
        Intent picker=new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("image/*");
        try{
            coverPickerRequest=request;coverPickerSession=session;
            startActivityForResult(picker,PLAYLIST_COVER_REQUEST);
        }catch(ActivityNotFoundException e){coverPickerRequest=null;reply(request,null,"找不到照片选择器");}
    }

    @Override protected void onActivityResult(int code,int result,Intent data){
        super.onActivityResult(code,result,data);
        if(code!=PLAYLIST_COVER_REQUEST||coverPickerRequest==null)return;
        String request=coverPickerRequest;long session=coverPickerSession;coverPickerRequest=null;
        if(result!=RESULT_OK||data==null||data.getData()==null){reply(request,null,null);return;}
        network.execute(()->{
            try{
                if(session!=api.sessionEpoch())throw new IOException("登录状态已改变，请重试");
                Bitmap bitmap=ImageDecoder.decodeBitmap(ImageDecoder.createSource(getContentResolver(),data.getData()),(decoder,info,source)->{
                    int width=info.getSize().getWidth(),height=info.getSize().getHeight();
                    double scale=Math.min(1,1280.0/Math.max(width,height));
                    decoder.setTargetSize(Math.max(1,(int)(width*scale)),Math.max(1,(int)(height*scale)));
                    decoder.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE);
                });
                int side=Math.min(bitmap.getWidth(),bitmap.getHeight());
                Bitmap square=Bitmap.createBitmap(bitmap,(bitmap.getWidth()-side)/2,(bitmap.getHeight()-side)/2,side,side);
                if(side>640)square=Bitmap.createScaledBitmap(square,640,640,true);
                ByteArrayOutputStream out=new ByteArrayOutputStream();
                if(!square.compress(Bitmap.CompressFormat.JPEG,86,out)||out.size()>MusicApi.MAX_COVER_BYTES)throw new IOException("图片过大");
                if(session!=api.sessionEpoch())throw new IOException("登录状态已改变，请重试");
                reply(request,android.util.Base64.encodeToString(out.toByteArray(),android.util.Base64.NO_WRAP),null);
            }catch(Exception e){reply(request,null,session!=api.sessionEpoch()?"登录状态已改变，请重试":"读取图片失败，请换一张照片");}
        });
    }

    void control(JSONObject a){
        String action=a.optString("action");
        if(!Set.of("queue","replaceQueue","toggle","pause","next","previous","seek","mode","sleep","remove").contains(action))return;
        Intent intent=new Intent(this,PlaybackService.class).putExtra("action",action).putExtra("value",a.optLong("value",0)).putExtra("mode",a.optString("mode","list"));
        if(action.equals("queue")||action.equals("replaceQueue")){JSONArray q=a.optJSONArray("queue");if(q==null||q.length()==0)return;intent.putExtra("queue",q.toString()).putExtra("index",a.optInt("index",0));}
        if(PlaybackService.current==null&&!action.equals("queue"))return;
        if(Build.VERSION.SDK_INT>=33&&checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=android.content.pm.PackageManager.PERMISSION_GRANTED)requestPermissions(new String[]{android.Manifest.permission.POST_NOTIFICATIONS},11);
        try{startForegroundService(intent);}catch(Exception e){evaluate("window.dispatchEvent(new CustomEvent('native-error',{detail:'播放服务启动失败'}));");}
    }
    File lyricsDir(){File dir=new File(getFilesDir(),"lyrics");if(!dir.isDirectory())dir.mkdirs();return dir;}
    File audioDir(){File dir=new File(getFilesDir(),"audio");if(!dir.isDirectory())dir.mkdirs();return dir;}
    // 已下载歌曲的歌词合并进下载（audio 目录），只有「听过但没下载」的歌词才算歌词缓存。
    boolean isDownloaded(String id){return id!=null&&new File(audioDir(),id+".audio").isFile();}
    File lyricFile(String id){return new File(isDownloaded(id)?audioDir():lyricsDir(),id+".txt");}
    synchronized void saveLyric(String id,String text)throws Exception{
        if(id==null||text==null||text.isEmpty())return;
        File f=lyricFile(id);
        try(FileOutputStream out=new FileOutputStream(f)){out.write(text.getBytes(java.nio.charset.StandardCharsets.UTF_8));}
        if(isDownloaded(id)){File stray=new File(lyricsDir(),id+".txt");if(stray.isFile()&&!stray.equals(f))stray.delete();}
    }
    synchronized String readLyric(String id)throws Exception{
        if(id==null)return null;
        File f=isDownloaded(id)?new File(audioDir(),id+".txt"):new File(lyricsDir(),id+".txt");
        if(!f.isFile())f=new File(lyricsDir(),id+".txt");
        if(!f.isFile())return null;
        try(InputStream in=new FileInputStream(f)){return new String(in.readAllBytes(),java.nio.charset.StandardCharsets.UTF_8);}
    }
    synchronized JSONObject lyricStats()throws Exception{
        File[] files=lyricsDir().listFiles((d,name)->name.endsWith(".txt"));long bytes=0;int count=0;
        if(files!=null)for(File f:files){
            String id=f.getName().substring(0,f.getName().length()-4);
            if(!f.isFile()||isDownloaded(id))continue;
            bytes+=f.length();count++;
        }
        return new JSONObject().put("count",count).put("bytes",bytes);
    }
    synchronized void clearLyrics(){
        File[] files=lyricsDir().listFiles();
        if(files!=null)for(File f:files){
            String id=f.getName().endsWith(".txt")?f.getName().substring(0,f.getName().length()-4):"";
            if(isDownloaded(id))continue;
            f.delete();
        }
    }
    synchronized JSONArray downloads() throws Exception{
        JSONArray list=new JSONArray();File dir=new File(getFilesDir(),"audio");File[] files=dir.listFiles((d,name)->name.endsWith(".json"));if(files!=null)for(File f:files){
            if(!new File(dir,f.getName().replace(".json",".audio")).exists())continue;
            try(InputStream in=new FileInputStream(f)){JSONObject item=new JSONObject(new String(in.readAllBytes(),java.nio.charset.StandardCharsets.UTF_8));item.put("bytes",new File(dir,f.getName().replace(".json",".audio")).length());list.put(item);}
        }return list;
    }
    synchronized JSONObject download(JSONObject track)throws Exception{
        long id=track.getLong("id");if(id<=0)throw new Exception("歌曲无效");
        // 下载走单独的「下载音质」，与播放音质解耦。
        String url=api.audioURL(id,getSharedPreferences("player",MODE_PRIVATE).getString("download_quality",getSharedPreferences("player",MODE_PRIVATE).getString("quality","exhigh")));
        File dir=new File(getFilesDir(),"audio");if(!dir.isDirectory()&&!dir.mkdirs())throw new IOException("下载目录创建失败");
        File tmp=new File(dir,id+".part");HttpURLConnection con=(HttpURLConnection)new URL(url).openConnection();con.setInstanceFollowRedirects(false);con.setConnectTimeout(15000);con.setReadTimeout(30000);
        try{
            if(con.getResponseCode()!=200)throw new IOException("音频下载失败");
            String type=con.getContentType();if(type!=null&&(type.contains("text")||type.contains("json")))throw new IOException("下载的内容不是音频");
            long expected=con.getContentLengthLong();long total=0;
            try(InputStream in=con.getInputStream();FileOutputStream out=new FileOutputStream(tmp)){byte[] buffer=new byte[32768];int n;while((n=in.read(buffer))!=-1){total+=n;if(total>600L*1024*1024)throw new IOException("音频文件过大");out.write(buffer,0,n);}out.getFD().sync();}
            if(total<1024||(expected>0&&total!=expected))throw new IOException("音频下载不完整");
            File audio=new File(dir,id+".audio");if(!tmp.renameTo(audio))throw new IOException("音频保存失败");
            android.util.AtomicFile metadata=new android.util.AtomicFile(new File(dir,id+".json"));FileOutputStream out=metadata.startWrite();
            try{out.write(track.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));metadata.finishWrite(out);}catch(Exception e){metadata.failWrite(out);throw e;}
            return track;
        }finally{con.disconnect();if(tmp.exists())tmp.delete();}
    }
    @Override public void onBackPressed(){if(web!=null)evaluate("window.dispatchEvent(new Event('android-back'));");else super.onBackPressed();}
    @Override protected void onDestroy(){destroyed=true;ui.removeCallbacksAndMessages(null);network.shutdownNow();try{unregisterReceiver(playback);}catch(Exception ignored){}if(web!=null){web.removeJavascriptInterface("KumoneNative");web.destroy();}super.onDestroy();}
}
