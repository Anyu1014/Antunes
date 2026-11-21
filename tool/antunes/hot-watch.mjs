// 持续热更新：监听 assets，改动即 push 到设备 files/hot/ 并刷新 WebView（复用 hot.sh）。
//   node hot-watch.mjs
// 只认 WebView 实际加载的四个文件；保存抖动用 250ms 合并成一次刷新。
import {watch} from 'node:fs';
import {execFile} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const FILES = new Set(['app.js', 'app.css', 'core.mjs', 'index.html']);
const assets = fileURLToPath(new URL('../../android/app/src/main/assets/', import.meta.url));
const here = fileURLToPath(new URL('.', import.meta.url));

let timer = null;
const pending = new Set();

const stamp = () => new Date().toTimeString().slice(0, 8);
const flush = () => {
  const files = [...pending];
  pending.clear();
  if (!files.length) return;
  execFile(here + 'hot.sh', files, {cwd: here}, (err, out, errOut) => {
    const reload = /HOT_RELOAD/.test(out);
    console.log(`${stamp()} ${files.join(',')} ${err ? 'FAILED: ' + (errOut || err.message).trim().split('\n').pop() : reload ? 'HOT_RELOAD ok' : 'pushed, reload missing'}`);
  });
};

console.log(`${stamp()} watching ${assets}`);
watch(assets, {persistent: true}, (_ev, name) => {
  if (!name || !FILES.has(name)) return;
  pending.add(name);
  clearTimeout(timer);
  timer = setTimeout(flush, 250);
});

const stop = () => {
  clearTimeout(timer);
  flush();
  setTimeout(() => process.exit(0), 1500);
};
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
