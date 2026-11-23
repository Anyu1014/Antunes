import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';

const root=process.argv[2]||resolve(import.meta.dirname,'../..');
const read=file=>readFileSync(resolve(root,file),'utf8');
const swift=file=>read('Sources/Kumone/'+file+'.swift');
const messages=swift('Features/Pages/MessagesView');
const client=swift('Core/API/MusicClient');
const routes=swift('Features/Navigation');
const track=swift('Core/Models/Track');
const playlist=swift('Core/Storage/PlaylistContent');
const search=swift('Features/Pages/SearchView');
const home=swift('Features/Home/HomeView');
const rank=swift('Features/Pages/ListeningRankView');
const player=swift('Core/Player/PlayerServiceIOS');
const ui=read('ios/KumoneIOSUITests/KumoneIOSUITests.swift');
const android='android/app/src/main/java/com/antunes/app/';
const checks=[
  ['conversation belongs to its original account and only clears the sent draft',
   routes.includes('case conversation(Int, String, Int)')&&
   messages.includes('account.authenticatedAccountID == ownerID')&&
   messages.includes('if draft == submittedDraft { draft = "" }')&&
   messages.includes('sendPrivateText(text, to: userID, binding: session)')&&
   client.includes('if let binding, authentication.binding != binding')&&
   client.includes('snapshot: cookieSnapshot')],
  ['audio thumbnail path prepares a cached row before showing it and merges a missing album',
   playlist.includes('if !preparesArtwork')&&
   /await warmLeadingArtwork\(saved\.detail\.tracks, size: artworkSize\)[\s\S]*?if tracks != saved\.detail\.tracks/.test(playlist)&&
   playlist.includes('cachedImage(for: $0) == nil')&&
   track.includes('album.id == 0 ? previous.album')&&track.includes('id == previous.id')],
  ['search marks success only after verifying the winning request',
   /guard isCurrent\(\) else \{ return \}[\s\S]*?if !failedTabs\.contains\(tab\) \{ loadedTabs\.insert\(tab\) \}/.test(search)&&
   search.includes('requests[tab] == request && !Task.isCancelled')&&
   search.indexOf('loadedTabs.insert(tab)')>search.indexOf('switch tab')],
  ['main home sections are published before fallback and daily artwork',
   /sections = primary\s+state = \.loaded[\s\S]*?async let playlistsTask/.test(home)&&
   home.includes('missing.contains(.radarPlaylists)')&&home.indexOf('let dailyCover = await dailyTask')>home.indexOf('sections = HomeFeed.filling(primary,')],
  ['listening rank has a single current account/period task',
   (rank.match(/\.task\(/g)||[]).length===1&&rank.includes('.task(id: key)')&&
   rank.includes('!Task.isCancelled && loadKey == key')&&rank.includes('账号资料尚未就绪')],
  ['late home playlist play is blocked by normal playback and by account change',
   home.includes('player.isCurrentPlaybackIntent(intent), owner == account.authenticatedAccountID')&&
   /func play\(tracks:[\s\S]*?\{\s*beginPlaybackIntent\(\)/.test(player)&&
   /func startFM\(\) \{\s*beginPlaybackIntent\(\)/.test(player)],
  ['radar opens recommendation-aware song menu',
   /section\.slot == \.radarPlaylists\s+\? Destination\.radarPlaylist/.test(home)&&
   routes.includes('recommendationContext: .radar')],
  ['iPhone UI regression test exercises keyboard, close, and two tabs',
    ui.includes('app.keyboards.firstMatch')&&ui.includes('search-close-button')&&
    ui.includes('section-tab-home')&&ui.includes('section-tab-library')&&ui.includes('openSearch.isHittable')],
  ['Android native bridge binds queued private requests before taking a cookie snapshot',
    read(android+'MainActivity.java').includes('api.sessionEpoch():-1')&&
    /path\.startsWith\("\/msg\/private\/"\) && submittedSession != epoch[\s\S]*?jar = new JSONObject/.test(read(android+'MusicApi.java'))]
];
for(const [title,ok] of checks)console.log(`${ok?'PASS':'FAIL'} ${title}`);
const successes=checks.filter(([,passed])=>passed).length;
console.log(`SOURCE CONTRACTS ${successes}/${checks.length}`);
process.exitCode=Number(successes!==checks.length);
