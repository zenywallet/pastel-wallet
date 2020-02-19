# Pastel Wallet
A sample wallet using Blockstor API

### Requirements
- blockstor https://github.com/zenywallet/blockstor
- Nim https://nim-lang.org/
- rocksdb (librocksdb-dev)
- apache or nginx for web proxy and SSL

### Build Instructions
```bash
git clone https://github.com/zenywallet/pastel-wallet
cd pastel-wallet
nimble build
```

### Launch
```bash
bin/pastel
```
http://localhost:5000/

### Debug
```bash
nim c -r src/pastel.nim
```
