# Pastel Wallet
A sample wallet using Blockstor API

### Prerequirements
- https://github.com/zenywallet/emsdkenv
- https://github.com/zenywallet/zenyjs
- https://github.com/zenywallet/zenycore
- https://github.com/zenywallet/caprese
- https://github.com/zenywallet/blockstor

### Build Instructions
    git clone https://github.com/zenywallet/pastel-wallet pastel
    cd pastel
    git submodule update --init

- Download [closure-compiler.jar](https://developers.google.com/closure/compiler/) and copy to bin/closure-compiler.jar
- Edit src/config.nim as you like

    nimble cipher
    nimble minify
    nimble build -d:release --opt:speed

### Launch
    bin/pastel

- https://localhost:5002/
