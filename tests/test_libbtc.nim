# Copyright (c) 2019 zenywallet

import unittest, byteutils, marshal, sequtils, base64
import ../src/libbtc

test "btc_random_bytes array":
  var buf: array[32, byte]
  var ret = btc_random_bytes(buf, 32, 0)
  echo "ret=", ret, " ", buf.toHex
  check(ret == 1)

test "btc_random_bytes seq":
  var buf = newSeq[byte](32)
  var ret = btc_random_bytes(buf, 32, 0)
  echo "ret=", ret, " ", buf.toHex
  check(ret == 1)

test "bip44-1":
  #[
  mnemonic = "achieve evoke pigeon twin lake build sign inform nice sick glance end tube shadow floor"
  seed = "80a20b8ad8e285266196504d0e4a66d2397ccce83d024237aaf7496e3cb4b0ad26fec4bc35b98c7a03c1e707e29c31185d078113a1004d5880c2edcdb788dfcc"
  rootkey = "xprv9s21ZrQH143K4KinPjY2wtbeAW62uSqNbc4UPGjt3cpyVc5Udzc5odqwZbN14qLCFkLdAezMrN2BvsYNjqS48GfKdijwfdXg9Jo8n8fQoYf"

  44 0 0 0 xprv xprv9z3yZx89zwd442ix6DaHvcStmSYYV5xKdVG9vNS6RMkytGYZ5myQeF1aagTzkk2w7e1ejTCVCeNT6sj2HYzAAgvuqBYZ53T25PgRMEFtmMx
  44 0 0 0 xpub xpub6D3KyTf3qKBMGWoRCF7JHkPdKUP2tYgAziBkikqhyhHxm4shdKHfC3L4RxdeNRDeFGpZGHEoEGoCorRcodbjKf7E6zAg7XkKUHfnrGNDz8q
  m/44'/0'/0'/0 extended xprvA2LGQZVkGpJaFnEiawYHPJc3Yy1c1DboZkF9Aw9oNP66jKfXyNZc2BhM5SCefvXKMhyZheQdfXRYw1PgRTfKVXvnfzRgtDTUBBRRbAX4eGN
  m/44'/0'/0'/0 extended xpub6FKcp52e7BrsUGKBgy5HkSYn6zr6QgKevyAjyKZQvid5c7zgWusrZz1pvhRNDB6WJqR6RzBc5btMVHD3W8Xb39ut8tKgAGrQF6SehBzw2Y1
  18HVNi1YEtnyLJJVkPzcyyssryZjREw6Sq  027bc1c0bd02704f2c36ce1bd5b8bc1990d798bb3b0aa008bb2c3b1237110f0155  KyeZweoUyz7AwEjfK7Cq54W6ocS3HqWFcU4DtmhhuTuTWPnP8zDE

  m/44'/0'/0'/0/0   18HVNi1YEtnyLJJVkPzcyyssryZjREw6Sq  027bc1c0bd02704f2c36ce1bd5b8bc1990d798bb3b0aa008bb2c3b1237110f0155  KyeZweoUyz7AwEjfK7Cq54W6ocS3HqWFcU4DtmhhuTuTWPnP8zDE
  m/44'/0'/0'/0/1   1AK3na6js6SwaxBN76XXpuTgtLchzpPSaS  02998cf0baac2693ba44e4acb03fc1212117d2287c139e638e5fe3edcb96412114  KyyxoE8V9AoSAUhqigSBkAkbvDSzAneKtRSUxHUFq5Arsi4w5soR
  m/44'/0'/0'/0/2   16GxWG4bMaCFRWq179vh2wQG1yGGQNwNz5  02ee3a492356c0374664e49575242ca1435bd864fe283fee37a19efeee24a5c1fb  L2okuHzASmeFxwPM6Td2iXxsEGu3ACiAfSFh5bfRHyTLcBHPwhoM
  m/44'/0'/0'/0/3   1JzpmtEzKj1BPVeMGdpHt5y55djbZ5mX98  022c646594acf9d03e9e861a3ac2ae65e4797525fa33b9434a6a4b1b90d148186a  L54y4TC2faBxp7uSyXrsvY5SU2zf1sSJEX1bzUkosKFdpD3CtToS
  m/44'/0'/0'/0/4   1H9XLEgUVe67mPwiZQeEw8UBgMD8v3opqh  02e59916ae8f489430f88666b39c3dd911c86a53b2de0b81d3e31064a754687a31  L46wiX9EVk6AP4WRqJviyznfHS69KZ9aoB3PPh9cgiKtPhq6ExYY
  m/44'/0'/0'/0/5   1KLkmyVTSduAxM6v2gSsH24dzYek7BnsEr  024b8778209fb3b04a5157b5840298dc12703045f485ea432eef05c1e8112789ca  L3Di5r7xPCsw2cWjyiXnCqVh2xi9aPKinWUNRV4b8FzQTjJSJLVc

  m/0/0   18HVNi1YEtnyLJJVkPzcyyssryZjREw6Sq  027bc1c0bd02704f2c36ce1bd5b8bc1990d798bb3b0aa008bb2c3b1237110f0155  NA
  m/0/1   1AK3na6js6SwaxBN76XXpuTgtLchzpPSaS  02998cf0baac2693ba44e4acb03fc1212117d2287c139e638e5fe3edcb96412114  NA
  m/0/2   16GxWG4bMaCFRWq179vh2wQG1yGGQNwNz5  02ee3a492356c0374664e49575242ca1435bd864fe283fee37a19efeee24a5c1fb  NA
  m/0/3   1JzpmtEzKj1BPVeMGdpHt5y55djbZ5mX98  022c646594acf9d03e9e861a3ac2ae65e4797525fa33b9434a6a4b1b90d148186a  NA
  m/0/4   1H9XLEgUVe67mPwiZQeEw8UBgMD8v3opqh  02e59916ae8f489430f88666b39c3dd911c86a53b2de0b81d3e31064a754687a31  NA
  ]#

  #let privkey: cstring = "xpub6D3KyTf3qKBMGWoRCF7JHkPdKUP2tYgAziBkikqhyhHxm4shdKHfC3L4RxdeNRDeFGpZGHEoEGoCorRcodbjKf7E6zAg7XkKUHfnrGNDz8q"
  #let privkey: cstring = "xprv9s21ZrQH143K2JF8RafpqtKiTbsbaxEeUaMnNHsm5o6wCW3z8ySyH4UxFVSfZ8n7ESu7fgir8imbZKLYVBxFPND1pniTZ81vKfd45EHKX73"
  #var masterkey: cstring = "xprv9s21ZrQH143K3C5hLMq2Upsh8mf9Z1p5C4QuXJkiodSSihp324YnWpFfRjvP7gqocJKz4oakVwZn5cUgRYTHtNRvGqU5DU2Gn8MPM9jHvfC" #cast[cstring](seed)

  btc_ecc_start()
  let privkey: cstring = "xprv9s21ZrQH143K4KinPjY2wtbeAW62uSqNbc4UPGjt3cpyVc5Udzc5odqwZbN14qLCFkLdAezMrN2BvsYNjqS48GfKdijwfdXg9Jo8n8fQoYf"
  let keypath: cstring = "m/44'/0'/0'"
  let extkeyout_size: csize = 128
  let extkeyout: cstring = newString(extkeyout_size)
  var ret: bool = hd_derive(addr bitzeny_chain, privkey, keypath, extkeyout, extkeyout_size)
  echo "ret=", ret, " ", extkeyout
  check(ret == true and extkeyout == "xprv9z3yZx89zwd442ix6DaHvcStmSYYV5xKdVG9vNS6RMkytGYZ5myQeF1aagTzkk2w7e1ejTCVCeNT6sj2HYzAAgvuqBYZ53T25PgRMEFtmMx")

  var node: btc_hdnode
  ret = btc_hdnode_deserialize(extkeyout, addr bitzeny_chain, addr node)
  var strsize: csize = 128
  var str: cstring = newString(strsize)
  ret = btc_hdnode_get_pub_hex(addr node, str, addr strsize)
  echo "pub hex: ", str, " ", strsize
  strsize = 128
  btc_hdnode_serialize_public(addr node, addr bitzeny_chain, str, cast[cint](strsize))
  echo "xpub: ", str, " ", strsize
  check(str == "xpub6D3KyTf3qKBMGWoRCF7JHkPdKUP2tYgAziBkikqhyhHxm4shdKHfC3L4RxdeNRDeFGpZGHEoEGoCorRcodbjKf7E6zAg7XkKUHfnrGNDz8q")
  btc_ecc_stop()

test "bip44-2":
  btc_ecc_start()
  let privkey: cstring = "xprv9s21ZrQH143K4KinPjY2wtbeAW62uSqNbc4UPGjt3cpyVc5Udzc5odqwZbN14qLCFkLdAezMrN2BvsYNjqS48GfKdijwfdXg9Jo8n8fQoYf"
  let keypath: cstring = "m/44'/0'/0'/0"
  let extkeyout_size: csize = 128
  let extkeyout: cstring = newString(extkeyout_size)
  var ret: bool = hd_derive(addr bitzeny_chain, privkey, keypath, extkeyout, extkeyout_size)
  echo "ret=", ret, " ", extkeyout
  check(ret == true and extkeyout == "xprvA2LGQZVkGpJaFnEiawYHPJc3Yy1c1DboZkF9Aw9oNP66jKfXyNZc2BhM5SCefvXKMhyZheQdfXRYw1PgRTfKVXvnfzRgtDTUBBRRbAX4eGN")

  var node: btc_hdnode
  ret = btc_hdnode_deserialize(extkeyout, addr bitzeny_chain, addr node)
  var strsize: csize = 128
  var str: cstring = newString(strsize)
  ret = btc_hdnode_get_pub_hex(addr node, str, addr strsize)
  echo "pub hex: ", str, " ", strsize
  strsize = 128
  btc_hdnode_serialize_public(addr node, addr bitzeny_chain, str, cast[cint](strsize))
  echo "xpub: ", str, " ", strsize
  check(str == "xpub6FKcp52e7BrsUGKBgy5HkSYn6zr6QgKevyAjyKZQvid5c7zgWusrZz1pvhRNDB6WJqR6RzBc5btMVHD3W8Xb39ut8tKgAGrQF6SehBzw2Y1")
  btc_ecc_stop()

test "bip44-3":
  btc_ecc_start()
  let privkey: cstring = "xpub6D3KyTf3qKBMGWoRCF7JHkPdKUP2tYgAziBkikqhyhHxm4shdKHfC3L4RxdeNRDeFGpZGHEoEGoCorRcodbjKf7E6zAg7XkKUHfnrGNDz8q"
  let keypath: cstring = "m/0/0"
  let extkeyout_size: csize = 128
  let extkeyout: cstring = newString(extkeyout_size)
  var ret: bool = hd_derive(addr bitzeny_chain, privkey, keypath, extkeyout, extkeyout_size)
  echo "ret=", ret, " ", extkeyout

  var node: btc_hdnode
  ret = btc_hdnode_deserialize(extkeyout, addr bitzeny_chain, addr node)
  var strsize: csize = 128
  var str: cstring = newString(strsize)
  ret = btc_hdnode_get_pub_hex(addr node, str, addr strsize)
  echo "pub hex: ", str, " ", strsize
  check(str == "027bc1c0bd02704f2c36ce1bd5b8bc1990d798bb3b0aa008bb2c3b1237110f0155")
  strsize = 128
  btc_hdnode_serialize_public(addr node, addr bitzeny_chain, str, cast[cint](strsize))
  echo "xpub: ", str, " ", strsize
  discard hd_print_node(addr bitzeny_chain, str)
  btc_ecc_stop()

test "var_uint":
  let v: uint64 = 5000000000000000'u64
  echo var_uint(v)

test "sign message":
  btc_ecc_start()
  var message = "This is an example of a signed message."
  var messagePrefix = "\u0018BitZeny Signed Message:\n"
  echo message.len
  echo messagePrefix.len
  var buf: seq[cuchar] = concat(toSeq(messagePrefix), cast[seq[cuchar]](var_uint(uint64(message.len))), toSeq(message))
  echo buf
  echo "buf len=" & $buf.len
  check(buf.len == 65)
  echo cast[seq[byte]](buf).toHex()
  var hashout: uint256
  btc_hash(cast[ptr cuchar](addr buf[0]), buf.len, hashout)
  echo "hashout hex=", hashout.toHex()
  var priv = @[byte 15, 201, 181, 158, 189, 105, 123, 206, 195, 117, 163, 4, 92, 59, 51, 84, 252, 111, 255, 47, 128, 169, 116, 196, 52, 6, 89, 49, 254, 163, 157, 173]
  var sigrec = newSeq[cuchar](buf.len)
  var outlen: csize = -1
  var fCompressed = true
  var recid: cint
  var ret = btc_ecc_sign_compact_recoverable(cast[ptr cuchar](addr priv[0]), hashout, cast[ptr cuchar](addr sigrec[1]), addr outlen, addr recid)
  check(ret == true)
  if fCompressed:
    sigrec[0] = (27 + recid + 4).cuchar
  else:
    sigrec[0] = (27 + recid).cuchar
  let sign_hex = cast[seq[byte]](sigrec).toHex()
  let sign_encode = sigrec.encode()
  echo sign_hex
  echo sign_encode
  check(sign_hex == "2094095a32cf86a51e20740d80c4c700e86e7b37105a4a2850ec35c9ca7ac7b16768c259aa4f72a4958c34c7050ac7e349e090d276e363e2316487f4171115a977")
  check(sign_encode == "IJQJWjLPhqUeIHQNgMTHAOhuezcQWkooUOw1ycp6x7FnaMJZqk9ypJWMNMcFCsfjSeCQ0nbjY+IxZIf0FxEVqXc=")
  btc_ecc_stop()
