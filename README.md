# Pastel Wallet
A sample wallet using Blockstor API


### Requirements
- blockstor https://github.com/zenywallet/blockstor
- Nim https://nim-lang.org/
- rocksdb (librocksdb-dev)
- apache or nginx for web proxy and SSL
- Emscripten https://emscripten.org/
- Google Closure Compiler https://github.com/google/closure-compiler


### Build Instructions
- Download [Emscripten](https://emscripten.org/) and install
- Download [closure-compiler.jar](https://developers.google.com/closure/compiler) and copy to bin/closure-compiler.jar

```bash
git clone https://github.com/zenywallet/pastel-wallet
cd pastel-wallet
git submodule update --init
nimble deps
nimble build -d:release
nimble cipher
nimble minify
```


### Launch
```bash
bin/pastel
```
- http://localhost:5000/
- WebSocket port is 5001
