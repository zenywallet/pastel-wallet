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
- In a local environment, edit ws_url in public/js/pastel.js as follows: ws://localhost:5001/ws/
- Edit baseurl in src/blockstor.nim to change blockstor api url
- Edit blockstor_apikey in src/config.nim to change blockstor api key

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
