# Pastel Wallet
A sample wallet using Blockstor API


### Requirements
- Nim https://nim-lang.org/
- Emscripten https://emscripten.org/
- Google Closure Compiler https://github.com/google/closure-compiler
- blockstor https://github.com/zenywallet/blockstor


### Build Instructions
```bash
git clone https://github.com/zenywallet/pastel-wallet
cd pastel-wallet
git submodule update --init
```

- Download [Emscripten](https://emscripten.org/) and install
- Download [closure-compiler.jar](https://developers.google.com/closure/compiler) and copy to bin/closure-compiler.jar
- Change src/config.nim as you like

```bash
nimble depsAll
nimble cipher
nimble minify
nimble build -d:release
```


### Launch
```bash
bin/pastel
```
- https://localhost:5002/
