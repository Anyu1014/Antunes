import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import vm from 'node:vm';

const root = process.argv[2] || resolve(import.meta.dirname, '../..');
const read = path => readFileSync(resolve(root, path), 'utf8');
const app = read('android/app/src/main/assets/app.js');
const settings = read('Sources/Kumone/Features/Pages/SettingsView.swift');
const home = read('Sources/Kumone/Features/Home/HomeView.swift');
const feed = read('Sources/Kumone/Features/Home/HomeFeed.swift');
const groups = ['主页板块', '我的音乐板块', '主页歌单展示', '推荐页板块'];

const prefs = {};
let wide = false;
const changes = [];
const context = vm.createContext({
  prefs, route: { kind: 'library' }, window: { innerWidth: 760, matchMedia: () => ({ matches: wide }) },
  e: String, bind: callback => { changes.push(callback); return `data-call="${changes.length}"`; },
  header: title => `<h1>${title}</h1>`, round: () => '', icon: () => '',
  button: (contents, _, cls) => `<button class="${cls}">${contents}</button>`,
  shelf: title => `<h2>${title}</h2>`, startHeart() {}, savePrefs() {},
  listRow: () => '', openEQ() {}, openSleep() {}, openStorage() {}, openAbout() {},
  openLicenses() {}, openLogin() {}, applyTheme() {}, loggedIn: false, LIBRARY_ROWS: [],
});
const slice = (from, to) => app.slice(app.indexOf(from), app.indexOf(to));
vm.runInContext(slice('const HOME_SLOTS=', 'function homeSlot(')
  + slice('function homeHTML(', 'async function explorePage(')
  + slice('function selectRow(', 'function openSettings(){')
  + 'function homeSectionHTML(section) { return section.title + "|"; }', context);

const html = context.settingsHTML();
assert(html.includes('>板块管理</div>'), 'Android is missing 板块管理');
for (const group of groups) {
  assert.match(html, new RegExp(`<details[^>]*data-section-group="${group}"[^>]*><summary[^>]*>${group}</summary>`));
  assert(settings.includes(`DisclosureGroup("${group}")`), `iOS is missing disclosure: ${group}`);
}
assert(settings.includes('Section("板块管理")'));
const reopened = context.settingsHTML(new Set(['推荐页板块', '我的音乐板块']));
assert.deepEqual([...reopened.matchAll(/data-section-group="([^"]+)" open/g)].map(x => x[1]), [groups[1], groups[3]]);

const sections = vm.runInContext('HOME_SLOTS.map(slot => ({ slot, title: HOME_SLOT_TITLES[slot] }))', context);
const allTitles = ['每日推荐', '私人漫游', '心动模式', ...sections.map(section => section.title), '新碟上架', '推荐歌手'];
const recommendation = html.slice(html.indexOf('data-section-group="推荐页板块"'));
const render = (signedIn = true) => context.homeHTML(sections, [], signedIn);
const visible = (markup, title) => markup.includes('>' + title + '<') || markup.includes(title + '|');
for (const title of allTitles) {
  const row = recommendation.match(new RegExp(`aria-label="${title}" checked data-change="(\\d+)"`));
  assert(row, `missing or off by default: ${title}`);
  const toggle = changes[Number(row[1]) - 1];
  assert(visible(render(), title));
  toggle({ target: { checked: false } });
  assert(!visible(render(), title), `off must hide: ${title}`);
  for (const other of allTitles.filter(other => other !== title)) assert(visible(render(), other));
  toggle({ target: { checked: true } });
  assert(visible(render(), title), `turning back on must show: ${title}`);
}
for (const match of recommendation.split('</details>')[0].matchAll(/data-change="(\d+)"/g)) {
  changes[Number(match[1]) - 1]({ target: { checked: false } });
}
assert(allTitles.every(title => !visible(render(), title)));
assert(!render().includes('feature-shelf'), 'hidden cards must not leave a shelf');
assert(!render(false).includes('feature-shelf'), 'logged-out view must not show cards');
Object.keys(prefs).forEach(key => delete prefs[key]);
wide = true;
prefs['home.section.' + sections[0].slot] = false;
const columns = render().split('<div class="home-col">').slice(1);
assert(columns[0].includes(sections[1].title + '|') && columns[1].includes(sections[2].title + '|'));

assert(settings.includes('HomeFeedSlot.allCases') && settings.includes('HomeSupplement.shortcuts') && settings.includes('HomeSupplement.shelves'));
assert([settings, home].every(source => source.includes('@AppStorage(HomeFeed.hiddenSectionsKey)')));
assert(home.includes('model.sections.filter') && home.includes('ForEach(Array(visibleSections.enumerated())'));
for (const slot of ['recommendedPlaylists', 'radarPlaylists', 'charts']) {
  assert(home.includes(`showsHomeSection(HomeFeedSlot.${slot}.rawValue)`), `missing iOS fallback: ${slot}`);
}
for (const supplement of ['daily', 'privateFM', 'heartbeat', 'newAlbums', 'topArtists']) {
  assert(feed.includes(`case .${supplement}:`) && home.includes(`showsHomeSection(HomeSupplement.${supplement}.rawValue)`));
}
console.log('SECTION_MANAGEMENT: 4 independent groups; Android 14 toggles/defaults/all-off/landscape; iOS settings and rendering paths PASS');
