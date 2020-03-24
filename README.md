# Pastel Wallet
A sample wallet using Blockstor API

### Requirements
- blockstor https://github.com/zenywallet/blockstor
- Nim https://nim-lang.org/
- rocksdb (librocksdb-dev)
- apache or nginx for web proxy and SSL

### Build Instructions
```bash
git clone --recursive https://github.com/zenywallet/pastel-wallet
cd pastel-wallet/deps/libbtc
./autogen.sh
./configure --disable-wallet --disable-tools
make
cd ../..
nimble build
```

### Installation
```bash
nimble install
```

### Launch
```bash
pastel
```
- http://localhost:5000/
- WebSocket port is 5001


### Release Build without installing and Launch
```bash
nim c -d:release src/pastel.nim
src/pastel
```
