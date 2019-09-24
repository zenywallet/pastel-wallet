# Copyright (c) 2019 zenywallet
# nim c -d:release -d:emscripten -o:ed25519.js orlp_ed25519.nim

{.emit: """
#define ED25519_NO_SEED true

#include "../deps/ed25519/src/ed25519.h"
#include "../deps/ed25519/src/ge.h"

void ed25519_get_publickey(unsigned char *private_key, unsigned char *public_key) {
    ge_p3 A;

    private_key[0] &= 248;
    private_key[31] &= 63;
    private_key[31] |= 64;

    ge_scalarmult_base(&A, private_key);
    ge_p3_tobytes(public_key, &A);
}
""".}

{.compile: "../deps/ed25519/src/add_scalar.c".}
{.compile: "../deps/ed25519/src/fe.c".}
{.compile: "../deps/ed25519/src/ge.c".}
{.compile: "../deps/ed25519/src/key_exchange.c".}
{.compile: "../deps/ed25519/src/keypair.c".}
{.compile: "../deps/ed25519/src/sc.c".}
#{.compile: "../deps/ed25519/src/seed.c".}
{.compile: "../deps/ed25519/src/sha512.c".}
{.compile: "../deps/ed25519/src/sign.c".}
{.compile: "../deps/ed25519/src/verify.c".}
