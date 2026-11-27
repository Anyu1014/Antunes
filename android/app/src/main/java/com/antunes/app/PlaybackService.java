package com.antunes.app;

import android.app.*;
import android.content.*;
import android.media.*;
import android.media.audiofx.Equalizer;
import android.media.session.*;
import android.os.*;
import org.json.*;
import java.io.*;
import java.util.concurrent.*;

public class PlaybackService extends Service {
    static PlaybackService current;
    static final String EVENT = "com.antunes.app.PLAYBACK";
    MediaPlayer player;
    MediaSession session;
    Equalizer equalizer;
    AudioManager audio;
    AudioFocusRequest focus;
    JSONArray queue = new JSONArray();
    int index = 0;
    String mode = "list", error = "";
    boolean prepared = false, resumeAfterFocus = false, loading = false;
    long generation = 0;
    long sleepAt = 0;
    final Handler handler = new Handler(Looper.getMainLooper());
    long lastPersistAt = 0;
    final ExecutorService worker = Executors.newSingleThreadExecutor();
    MusicApi api;
    final BroadcastReceiver noisy = new BroadcastReceiver() { public void onReceive(Context c, Intent i) { pause(); } };
    @Override public void onCreate() {
        super.onCreate(); current = this;
        try { api = MusicApi.shared(this); } catch (Exception e) { stopSelf(); return; }
        audio = (AudioManager)getSystemService(AUDIO_SERVICE);
        focus = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()).setOnAudioFocusChangeListener(change -> {
            if (change == AudioManager.AUDIOFOCUS_LOSS) { resumeAfterFocus = false; pause(); }
            else if (change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) { resumeAfterFocus = isPlaying(); pause(); }
            else if (change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK && player != null) player.setVolume(.2f,.2f);
            else if (change == AudioManager.AUDIOFOCUS_GAIN) { if (player != null) player.setVolume(1,1); if (resumeAfterFocus) { resumeAfterFocus=false; resume(); } }
        }).build();
        session = new MediaSession(this, "Antunes");
        session.setCallback(new MediaSession.Callback() {
            @Override public void onPlay() { resume(); }
            @Override public void onPause() { pause(); }
            @Override public void onSkipToNext() { next(1, false); }
            @Override public void onSkipToPrevious() { next(-1, false); }
            @Override public void onSeekTo(long pos) { seek(pos); }
            @Override public void onStop() { pause(); stopForeground(STOP_FOREGROUND_REMOVE); }
        }); session.setActive(true);
        ((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(new NotificationChannel("playback", "音乐播放", NotificationManager.IMPORTANCE_LOW));
        registerReceiver(noisy, new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY), RECEIVER_NOT_EXPORTED);
        handler.post(tick);
    }
    @Override public IBinder onBind(Intent i) { return null; }
    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        showNotification();
        if (intent != null) {
            String action = intent.getStringExtra("action");
            if ("queue".equals(action)) {
                try {
                    JSONArray next = new JSONArray(intent.getStringExtra("queue"));
                    if (next.length() == 0 || next.length() > 2000) throw new Exception();
                    queue=next; index=Math.max(0,Math.min(intent.getIntExtra("index",0),queue.length()-1));
                    mode=intent.getStringExtra("mode"); load();
                } catch (Exception e) { error="播放队列无效"; changed(); }
            } else if ("replaceQueue".equals(action)) {
                try { JSONArray next = new JSONArray(intent.getStringExtra("queue")); if(next.length() > 0 && next.length() <= 2000) { queue = next; index = Math.max(0,Math.min(intent.getIntExtra("index",index),queue.length()-1));persist();changed(); } } catch(Exception e) { error="播放队列无效";changed(); }
            } else if ("next".equals(action)) next(1, false);
            else if ("previous".equals(action)) next(-1, false);
            else if ("toggle".equals(action)) { if (isPlaying()) pause(); else resume(); }
            else if ("pause".equals(action)) pause();
            else if ("seek".equals(action)) seek(intent.getLongExtra("value",0));
            else if ("mode".equals(action)) { mode=intent.getStringExtra("mode"); persist(); changed(); }
            else if ("sleep".equals(action)) { long mins = intent.getLongExtra("value",0); sleepAt=mins > 0 ? System.currentTimeMillis()+mins*60000 : 0; changed(); }
            else if ("eq".equals(action)) applyEQ();
            else if ("remove".equals(action)) {
                int n=(int)intent.getLongExtra("value",-1);
                if (n >= 0 && n < queue.length() && n != index) { queue.remove(n); if(n<index)index--; persist(); changed(); }
            }
        }
        return START_NOT_STICKY;
    }
    void load() {
        final long token=++generation; prepared=false; loading=true; error="";
        releasePlayer();
        final JSONObject track=queue.optJSONObject(index); if(track==null){loading=false;changed();return;}
        showNotification(); changed(); persist();
        worker.execute(() -> {
            try {
                String id=""+track.getLong("id");
                File offline=new File(getFilesDir(), "audio/"+id+".audio");
                boolean forceNetwork = pendingForceNetwork; pendingForceNetwork = false;
                String url;
                if (!forceNetwork && offline.exists()) { url = offline.getAbsolutePath(); servedQuality = "local"; }
                else {
                    String resolved = api.audioURL(track.getLong("id"),getSharedPreferences("player",MODE_PRIVATE).getString("quality","exhigh"));
                    servedQuality = api.lastResolvedLevel;
                    android.util.Log.i("Kumone", "resolved type="+api.lastResolvedType+" level="+servedQuality+" url="+resolved);
                    // FLAC 按 iOS 的做法：整首落盘再播。MediaPlayer 直接吃网络流时 seek 只能靠
                    // 码率估算字节位置，无损以上会落错地方；本地文件由解封装器建索引，才能按帧定位。
                    if ("flac".equalsIgnoreCase(api.lastResolvedType)) {
                        File cached = flacFile(track.getLong("id"));
                        if (!cached.isFile() || cached.length() < 1_000_000) downloadFlac(resolved, cached);
                        resolved = cached.getAbsolutePath();
                    }
                    url = resolved;
                }
                handler.post(() -> { if(token!=generation)return;
                  // 这一代要播的必须是队列里这一格，别把上一格的声音接上来。
                  JSONObject expect=queue.optJSONObject(index);
                  if(expect==null||expect.optLong("id")!=track.optLong("id")){loading=false;changed();return;}
                  try {
                    player=new MediaPlayer();
                    player.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK);
                    player.setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build());
                    player.setDataSource(url);
                    // 只认「当前这一台」player 的回调：切歌时旧实例被 release，
                    // 但它挂的回调还会回来，不加这层就会把新实例当成已就绪去 start。
                    player.setOnPreparedListener(p -> { if(p!=player||token!=generation)return; prepared=true; loading=false; applyEQ();
                        if(pendingSeekMs>=0){ try { player.seekTo((int)pendingSeekMs); } catch(Exception ignored){} pendingSeekMs=-1; }
                        resume(); });
                    player.setOnCompletionListener(p -> { if(p!=player||token!=generation)return; next(1,true); });
                    player.setOnErrorListener((p,what,extra) -> { if(p!=player||token!=generation)return true; prepared=false; loading=false; error="音频播放失败 ("+what+")"; showNotification(); changed(); return true; });
                    player.prepareAsync();
                } catch(Exception e) { loading=false; error="音频加载失败"; changed(); } });
            } catch(Exception e) { handler.post(() -> {if(token!=generation)return;loading=false;error=e.getMessage()==null?"歌曲加载失败":e.getMessage();showNotification();changed();}); }
        });
    }
    void next(int direction, boolean ended) {
        if(queue.length()==0)return;
        if(ended && "single".equals(mode)) {seek(0);resume();return;}
        if("shuffle".equals(mode)&&direction>0&&queue.length()>1) index=(index+1+new java.security.SecureRandom().nextInt(queue.length()-1))%queue.length();
        else index=(index+direction+queue.length())%queue.length();
        load();
    }
    void resume() {
        if(player==null) {if(queue.length()>0)load();return;}
        if(!prepared)return;
        if(audio.requestAudioFocus(focus)!=AudioManager.AUDIOFOCUS_REQUEST_GRANTED){error="其他应用正在使用音频";changed();return;}
        try { player.start(); error=""; showNotification(); changed(); } catch(IllegalStateException e){error="播放状态已改变，请重新播放";changed();}
    }
    void pause() { if(prepared&&player!=null){try{player.pause();}catch(IllegalStateException ignored){}} showNotification(); changed(); }
    void seek(long pos) { if(prepared&&player!=null)player.seekTo(Math.max(0,Math.min(pos,player.getDuration())), MediaPlayer.SEEK_CLOSEST); changed(); }
    boolean isPlaying() { try{return player!=null&&prepared&&player.isPlaying();}catch(IllegalStateException e){return false;} }
    JSONObject positionState() {
        JSONObject s=new JSONObject();
        try { s.put("position",prepared?player.getCurrentPosition():0).put("duration",prepared?player.getDuration():0).put("playing",isPlaying()); } catch(Exception ignored) {}
        return s;
    }
    /** 当前这首实际用的档位（本地下载时会写 local）。 */
    String servedQuality = "";
    /** reload 时把播放位置带过来，等 prepared 之后 seek 过去。 */
    long pendingSeekMs = -1;
    /** reload 来自手动换档位：这一次跳过本地文件，直接按新档位取网络地址。 */
    boolean pendingForceNetwork = false;

    JSONObject state() {
        JSONObject s=new JSONObject();
        try { s.put("queue",queue).put("index",index).put("playing",isPlaying()).put("loading",loading).put("error",error).put("mode",mode).put("sleepAt",sleepAt).put("position",prepared?player.getCurrentPosition():0).put("duration",prepared?player.getDuration():0).put("quality",servedQuality); } catch(Exception ignored){}
        return s;
    }
    void persist() { int pos=0; try { pos = prepared ? player.getCurrentPosition() : 0; } catch (Exception ignored) {} getSharedPreferences("player",MODE_PRIVATE).edit().putString("queue",queue.toString()).putInt("index",index).putString("mode",mode).putInt("position",pos).apply(); }
    void changed() { sendBroadcast(new Intent(EVENT).setPackage(getPackageName())); }
    final Runnable tick=new Runnable(){public void run(){if(sleepAt>0&&System.currentTimeMillis()>=sleepAt){sleepAt=0;pause();}if(isPlaying()){updateSession();if(System.currentTimeMillis()-lastPersistAt>3000){lastPersistAt=System.currentTimeMillis();persist();}}handler.postDelayed(this,1000);}};
    void updateSession() {
        long actions=PlaybackState.ACTION_PLAY|PlaybackState.ACTION_PAUSE|PlaybackState.ACTION_PLAY_PAUSE|PlaybackState.ACTION_SKIP_TO_NEXT|PlaybackState.ACTION_SKIP_TO_PREVIOUS|PlaybackState.ACTION_SEEK_TO;
        session.setPlaybackState(new PlaybackState.Builder().setActions(actions).setState(isPlaying()?PlaybackState.STATE_PLAYING:PlaybackState.STATE_PAUSED,prepared?player.getCurrentPosition():0,isPlaying()?1:0).build());
        JSONObject t=queue.optJSONObject(index);
        if(t!=null)session.setMetadata(new MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE,t.optString("name")).putString(MediaMetadata.METADATA_KEY_ARTIST,t.optString("artist")).putLong(MediaMetadata.METADATA_KEY_DURATION,prepared?player.getDuration():0).build());
    }
    void showNotification() {
        if(session==null)return;
        updateSession(); JSONObject t=queue.optJSONObject(index);
        Notification n=new Notification.Builder(this,"playback").setSmallIcon(R.drawable.ic_music).setContentTitle(t==null?"Antunes":t.optString("name")).setContentText(t==null?"Antunes":t.optString("artist")).setVisibility(Notification.VISIBILITY_PUBLIC).setOngoing(isPlaying()).setContentIntent(PendingIntent.getActivity(this,0,new Intent(this,MainActivity.class),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT))
            .addAction(new Notification.Action.Builder(null,"上一首",pending("previous",1)).build())
            .addAction(new Notification.Action.Builder(null,isPlaying()?"暂停":"播放",pending("toggle",2)).build())
            .addAction(new Notification.Action.Builder(null,"下一首",pending("next",3)).build())
            .setStyle(new Notification.MediaStyle().setMediaSession(session.getSessionToken()).setShowActionsInCompactView(0,1,2)).build();
        startForeground(1,n);
    }
    PendingIntent pending(String action,int id){return PendingIntent.getService(this,id,new Intent(this,PlaybackService.class).putExtra("action",action),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);}
    void applyEQ(){
        if(player==null||!prepared)return;
        try{
            if(equalizer!=null)equalizer.release(); equalizer=new Equalizer(0,player.getAudioSessionId());
            android.content.SharedPreferences p=getSharedPreferences("player",MODE_PRIVATE);
            JSONArray levels=new JSONArray(p.getString("eq","[]"));
            short[] range=equalizer.getBandLevelRange();
            for(short b=0;b<equalizer.getNumberOfBands();b++) {
                double frequency=equalizer.getCenterFreq(b)/1000.0;
                double[] centers={31,62,125,250,500,1000,2000,4000,8000,16000}; int nearest=0;
                for(int i=1;i<centers.length;i++)if(Math.abs(Math.log(frequency/centers[i]))<Math.abs(Math.log(frequency/centers[nearest])))nearest=i;
                int db=levels.optInt(nearest,0)*100;equalizer.setBandLevel(b,(short)Math.max(range[0],Math.min(range[1],db)));
            }
            equalizer.setEnabled(p.getBoolean("eqEnabled",false));
        }catch(Exception e){error="当前设备不支持音效处理";changed();}
    }
    /** 无损以上（flac）整曲缓存目录，与 iOS 的 Caches/FLAC 对应。 */
    File flacFile(long id) {
        File dir = new File(getFilesDir(), "flac");
        if (!dir.isDirectory()) dir.mkdirs();
        return new File(dir, id + ".flac");
    }

    /** 整首下载（先写 .part 再改名，避免半截文件被当成缓存命中）。 */
    void downloadFlac(String url, File target) throws Exception {
        File part = new File(target.getPath() + ".part");
        java.net.HttpURLConnection conn = (java.net.HttpURLConnection) new java.net.URL(url).openConnection();
        conn.setConnectTimeout(15000); conn.setReadTimeout(30000);
        try (java.io.InputStream in = conn.getInputStream();
             java.io.FileOutputStream out = new java.io.FileOutputStream(part)) {
            byte[] buf = new byte[64 * 1024];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        } finally { conn.disconnect(); }
        if (!part.renameTo(target)) { part.delete(); throw new java.io.IOException("缓存写入失败"); }
    }

    void releasePlayer(){if(equalizer!=null){equalizer.release();equalizer=null;}if(player!=null){player.release();player=null;}prepared=false;}
    @Override public void onDestroy(){generation++;handler.removeCallbacksAndMessages(null);releasePlayer();worker.shutdownNow();if(session!=null)session.release();if(audio!=null&&focus!=null)audio.abandonAudioFocusRequest(focus);try{unregisterReceiver(noisy);}catch(Exception ignored){}current=null;super.onDestroy();}
}
