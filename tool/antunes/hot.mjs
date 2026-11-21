// 把改过的 WebView 资源"热"塞进模拟器里正在跑的那一页，方便看排版。
// 注意：安卓端的 index.html/app.js 是从 APK 的 assets 里读的
// （MainActivity.shouldInterceptRequest → getAssets().open），CDP 改不了
// 文档本身，所以这里只能在已加载的页面里再执行一份 app.js —— 页面里因此
// 同时存在两份应用实例，行为只当预览，最终结论必须以装出来的 APK 为准。
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {connect} from './cdp.mjs';

const assets = fileURLToPath(new URL('../../android/app/src/main/assets/', import.meta.url));
const c = await connect();
await c.call('Page.enable');

const css = await readFile(assets + 'app.css', 'utf8');
const js = await readFile(assets + 'app.js', 'utf8');

await c.evaluate(`(() => {
  let style = document.getElementById('hot-css');
  if (!style) { style = document.createElement('style'); style.id = 'hot-css'; document.head.appendChild(style); }
  style.textContent = ${JSON.stringify(css)};
  document.getElementById('page')?.replaceChildren();
  document.getElementById('chrome')?.replaceWith(Object.assign(document.createElement('div'), {id: 'chrome'}));
  document.getElementById('overlay')?.replaceChildren();
})()`);

// 走 module 注入，app.js 里的 `import './core.mjs'` 才能按页面 URL 解析。
await c.evaluate(`new Promise(resolve => {
  const script = document.createElement('script');
  script.type = 'module';
  script.textContent = ${JSON.stringify(js)};
  script.onload = resolve;
  document.body.appendChild(script);
  setTimeout(resolve, 1200);
})`);

const live = await c.evaluate("!!document.querySelector('#chrome .lyric-track')");
console.log('HOT_UPDATE: Antunes source loaded;' + (live ? ' lyric bar is the edited markup;' : ' lyric bar markup missing;') +
            ' no APK built; no reinstall; data preserved');
