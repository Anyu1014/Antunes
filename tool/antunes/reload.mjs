// 页面级热更新：assets 已在设备 files/hot/ 里就位时，只刷新 WebView 即生效
import {connect} from './cdp.mjs';
const c = await connect();
try {
  await c.call('Page.enable', {});
  await c.call('Page.reload', {ignoreCache: true});
  console.log('HOT_RELOAD: page reloaded');
} finally {
  process.exit(0);
}
