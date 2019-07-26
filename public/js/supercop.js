
var __supercopwasm = (function() {
  var _scriptDir = typeof document !== 'undefined' && document.currentScript ? document.currentScript.src : undefined;
  return (
function(__supercopwasm) {
  __supercopwasm = __supercopwasm || {};

var b;b||(b=typeof __supercopwasm !== 'undefined' ? __supercopwasm : {});var g={},l;for(l in b)b.hasOwnProperty(l)&&(g[l]=b[l]);var m=!1,n=!1,p=!1,q=!1,r=!1;m="object"===typeof window;n="function"===typeof importScripts;p=(q="object"===typeof process&&"object"===typeof process.versions&&"string"===typeof process.versions.node)&&!m&&!n;r=!m&&!p&&!n;var t="",u,v;
if(p){t=__dirname+"/";var w,x;u=function(a,c){w||(w=require("fs"));x||(x=require("path"));a=x.normalize(a);a=w.readFileSync(a);return c?a:a.toString()};v=function(a){a=u(a,!0);a.buffer||(a=new Uint8Array(a));a.buffer||y("Assertion failed: undefined");return a};1<process.argv.length&&process.argv[1].replace(/\\/g,"/");process.argv.slice(2);process.on("uncaughtException",function(a){if(!(a instanceof z))throw a;});process.on("unhandledRejection",y);b.inspect=function(){return"[Emscripten Module object]"}}else if(r)"undefined"!=
typeof read&&(u=function(a){return read(a)}),v=function(a){if("function"===typeof readbuffer)return new Uint8Array(readbuffer(a));a=read(a,"binary");"object"===typeof a||y("Assertion failed: undefined");return a};else if(m||n)n?t=self.location.href:document.currentScript&&(t=document.currentScript.src),_scriptDir&&(t=_scriptDir),0!==t.indexOf("blob:")?t=t.substr(0,t.lastIndexOf("/")+1):t="",u=function(a){var c=new XMLHttpRequest;c.open("GET",a,!1);c.send(null);return c.responseText},n&&(v=function(a){var c=
new XMLHttpRequest;c.open("GET",a,!1);c.responseType="arraybuffer";c.send(null);return new Uint8Array(c.response)});var A=b.print||("undefined"!==typeof console?console.log.bind(console):"undefined"!==typeof print?print:null),B=b.printErr||("undefined"!==typeof printErr?printErr:"undefined"!==typeof console&&console.warn.bind(console)||A);for(l in g)g.hasOwnProperty(l)&&(b[l]=g[l]);g=null;var D={"f64-rem":function(a,c){return a%c},"debugger":function(){debugger}};"object"!==typeof WebAssembly&&B("no native wasm support detected");
var E,F=!1;"undefined"!==typeof TextDecoder&&new TextDecoder("utf8");"undefined"!==typeof TextDecoder&&new TextDecoder("utf-16le");var buffer,G,H,I,J=b.TOTAL_MEMORY||16777216;b.wasmMemory?E=b.wasmMemory:E=new WebAssembly.Memory({initial:J/65536,maximum:J/65536});E&&(buffer=E.buffer);J=buffer.byteLength;b.HEAP8=G=new Int8Array(buffer);b.HEAP16=new Int16Array(buffer);b.HEAP32=I=new Int32Array(buffer);b.HEAPU8=H=new Uint8Array(buffer);b.HEAPU16=new Uint16Array(buffer);b.HEAPU32=new Uint32Array(buffer);
b.HEAPF32=new Float32Array(buffer);b.HEAPF64=new Float64Array(buffer);I[8796]=5278096;function K(a){for(;0<a.length;){var c=a.shift();if("function"==typeof c)c();else{var h=c.m;"number"===typeof h?void 0===c.l?b.dynCall_v(h):b.dynCall_vi(h,c.l):h(void 0===c.l?null:c.l)}}}var L=[],M=[],N=[],O=[];function aa(){var a=b.preRun.shift();L.unshift(a)}var P=0,Q=null,R=null;b.preloadedImages={};b.preloadedAudios={};
function S(){var a=T;return String.prototype.startsWith?a.startsWith("data:application/octet-stream;base64,"):0===a.indexOf("data:application/octet-stream;base64,")}var T="supercop.wasm";if(!S()){var U=T;T=b.locateFile?b.locateFile(U,t):t+U}function V(){try{if(b.wasmBinary)return new Uint8Array(b.wasmBinary);if(v)return v(T);throw"both async and sync fetching of the wasm failed";}catch(a){y(a)}}
function ba(){return b.wasmBinary||!m&&!n||"function"!==typeof fetch?new Promise(function(a){a(V())}):fetch(T,{credentials:"same-origin"}).then(function(a){if(!a.ok)throw"failed to load wasm binary file at '"+T+"'";return a.arrayBuffer()}).catch(function(){return V()})}
function ca(a){function c(a){b.asm=a.exports;P--;b.monitorRunDependencies&&b.monitorRunDependencies(P);0==P&&(null!==Q&&(clearInterval(Q),Q=null),R&&(a=R,R=null,a()))}function h(a){c(a.instance)}function k(a){return ba().then(function(a){return WebAssembly.instantiate(a,e)}).then(a,function(a){B("failed to asynchronously prepare wasm: "+a);y(a)})}var e={env:a,global:{NaN:NaN,Infinity:Infinity},"global.Math":Math,asm2wasm:D};P++;b.monitorRunDependencies&&b.monitorRunDependencies(P);if(b.instantiateWasm)try{return b.instantiateWasm(e,
c)}catch(f){return B("Module.instantiateWasm callback failed with error: "+f),!1}(function(){if(b.wasmBinary||"function"!==typeof WebAssembly.instantiateStreaming||S()||"function"!==typeof fetch)return k(h);fetch(T,{credentials:"same-origin"}).then(function(a){return WebAssembly.instantiateStreaming(a,e).then(h,function(a){B("wasm streaming compile failed: "+a);B("falling back to ArrayBuffer instantiation");k(h)})})})();return{}}
b.asm=function(a,c){c.memory=E;c.table=new WebAssembly.Table({initial:0,maximum:0,element:"anyfunc"});c.__memory_base=1024;c.__table_base=0;return ca(c)};function W(){y("OOM")}var X=b.asm({},{b:function(a){b.___errno_location&&(I[b.___errno_location()>>2]=a);return a},e:function(){return G.length},d:function(a){W(a)},c:W,a:35184},buffer);b.asm=X;b._ed25519_create_keypair=function(){return b.asm.f.apply(null,arguments)};b._ed25519_sign=function(){return b.asm.g.apply(null,arguments)};
b._ed25519_verify=function(){return b.asm.h.apply(null,arguments)};var Y=b._free=function(){return b.asm.i.apply(null,arguments)},da=b._malloc=function(){return b.asm.j.apply(null,arguments)};b.asm=X;b.then=function(a){if(b.calledRun)a(b);else{var c=b.onRuntimeInitialized;b.onRuntimeInitialized=function(){c&&c();a(b)}}return b};function z(a){this.name="ExitStatus";this.message="Program terminated with exit("+a+")";this.status=a}z.prototype=Error();z.prototype.constructor=z;
R=function ea(){b.calledRun||Z();b.calledRun||(R=ea)};
function Z(){function a(){if(!b.calledRun&&(b.calledRun=!0,!F)){K(M);K(N);if(b.onRuntimeInitialized)b.onRuntimeInitialized();if(b.postRun)for("function"==typeof b.postRun&&(b.postRun=[b.postRun]);b.postRun.length;){var a=b.postRun.shift();O.unshift(a)}K(O)}}if(!(0<P)){if(b.preRun)for("function"==typeof b.preRun&&(b.preRun=[b.preRun]);b.preRun.length;)aa();K(L);0<P||b.calledRun||(b.setStatus?(b.setStatus("Running..."),setTimeout(function(){setTimeout(function(){b.setStatus("")},1);a()},1)):a())}}
b.run=Z;function y(a){if(b.onAbort)b.onAbort(a);A(a);B(a);F=!0;throw"abort("+a+"). Build with -s ASSERTIONS=1 for more info.";}b.abort=y;if(b.preInit)for("function"==typeof b.preInit&&(b.preInit=[b.preInit]);0<b.preInit.length;)b.preInit.pop()();b.noExitRuntime=!0;Z();
(function(){function a(a){if(a&&a.buffer instanceof ArrayBuffer)a=new Uint8Array(a.buffer,a.byteOffset,a.byteLength);else if("string"===typeof a){for(var c=a.length,e=new Uint8Array(c+1),C=0;C<c;++C)e[C]=a.charCodeAt(C);return e}return a}function c(e,f){var d=new Number(e);d.length=f;d.get=function(a){a=a||Uint8Array;return(new a(buffer,d,f/a.BYTES_PER_ELEMENT)).slice()};d.dereference=function(a){a=a||4;return c(d.get(Uint32Array)[0],a)};d.set=function(c){c=a(c);if(c.length>f)throw RangeError("invalid array length");
H.set(c,d)};d.free=function(){Y(d);k.splice(k.indexOf(d),1)};k.push(d);return d}function h(e,f){f=a(f);0===e&&(e=f.length);var d=c(da(e),e);void 0!==f?(d.set(f),f.length<e&&H.fill(0,d+f.length,d+e)):H.fill(0,d,d+e);return d}var k=[];b.createPointer=c;b.allocatePointer=function(a){a&&(a=Uint32Array.of(a));return h(4,a)};b.allocateBytes=h;b.freeBytes=function(){for(var a=0,c=k.length;a<c;++a)Y(k[a]);k=[]}})();


  return __supercopwasm
}
);
})();
if (typeof exports === 'object' && typeof module === 'object')
      module.exports = __supercopwasm;
    else if (typeof define === 'function' && define['amd'])
      define([], function() { return __supercopwasm; });
    else if (typeof exports === 'object')
      exports["__supercopwasm"] = __supercopwasm;
