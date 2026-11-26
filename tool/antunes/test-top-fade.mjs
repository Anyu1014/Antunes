import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';
const c=await connect();
try{
 const result=await c.evaluate(`(()=>{const page=document.querySelector('#page'),bar=document.querySelector('.top-bar, .playlist-nav'),pseudo=getComputedStyle(page,'::before'),b=getComputedStyle(bar);return {topBlur:b.backdropFilter,topShadow:b.boxShadow,fadeBlur:pseudo.backdropFilter,fadeMask:pseudo.maskImage,fadeHeight:parseFloat(pseudo.height),viewport:innerHeight,position:b.position};})()`);
 const ok=result.topBlur==='none'&&result.topShadow==='none'&&result.fadeBlur.includes('12px')&&result.fadeMask.includes('gradient')&&result.fadeHeight<result.viewport*.2&&['sticky','absolute','fixed'].includes(result.position);
 console.log('TOP_FADE: '+JSON.stringify(result)+'; '+(ok?'PASS':'FAIL'));if(!ok)process.exitCode=1;
}finally{c.close();}
