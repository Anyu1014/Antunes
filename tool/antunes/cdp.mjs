import {execFileSync} from 'node:child_process';
export async function connect(){
  const adb='/Users/y/toolchains/bin/adb';const device=process.env.ANDROID_SERIAL||'emulator-5554';
  let pid='';
  for(const pkg of [process.env.ANDROID_PKG,'com.antunes.app']){
    if(!pkg)continue;
    try{pid=execFileSync(adb,['-s',device,'shell','pidof',pkg],{encoding:'utf8'}).trim();}catch(e){pid='';}
    if(pid)break;
  }
  if(!pid)throw new Error('app not running: com.antunes.app');
  execFileSync(adb,['-s',device,'forward','tcp:9227','localabstract:webview_devtools_remote_'+pid]);
  const pages=await(await fetch('http://127.0.0.1:9227/json/list')).json();
  const ws=new WebSocket(pages.find(p=>p.url==='https://app.kumone.local/').webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{ws.onopen=resolve;ws.onerror=reject;});
  let seq=0;const waiting=new Map();const listeners=[];
  ws.onmessage=({data})=>{const r=JSON.parse(data);if(!r.id){for(const listener of listeners)Promise.resolve(listener(r)).catch(()=>{});}if(r.id){const p=waiting.get(r.id);if(!p)return;waiting.delete(r.id);r.error?p.reject(new Error(JSON.stringify(r.error))):p.resolve(r.result);}};
  function call(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;waiting.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});}
  async function evaluate(expression){const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
  return {call,evaluate,onEvent:fn=>listeners.push(fn),close:()=>ws.close()};
}
