import libcurl, json

var curl: Pcurl
var headers: PSlist
headers = slist_append(headers, "Content-Type: application/json")

proc http_init() =
  curl = easy_init()

proc http_cleanup() =
  curl.easy_cleanup()

proc write_callback(buffer: cstring, size: int, nitems: int, outstream: pointer): int =
  var outbuf = cast[ref string](outstream)
  outbuf[] &= buffer
  result = size * nitems;

proc http_get(url: string): tuple[code: Code, data: string] =
  var outbuf: ref string = new string
  discard curl.easy_setopt(OPT_URL, url)
  discard curl.easy_setopt(OPT_WRITEDATA, outbuf)
  discard curl.easy_setopt(OPT_WRITEFUNCTION, write_callback)
  discard curl.easy_setopt(OPT_USERAGENT, "pastel-v0.1")
  let ret = curl.easy_perform()
  (ret, outbuf[])

proc http_post(url: string, post_data: string): tuple[code: Code, data: string] =
  var outbuf: ref string = new string
  discard curl.easy_setopt(OPT_URL, url)
  discard curl.easy_setopt(OPT_POST, 1)
  discard curl.easy_setopt(OPT_HTTPHEADER, headers)
  discard curl.easy_setopt(OPT_POSTFIELDS, post_data);
  discard curl.easy_setopt(OPT_WRITEDATA, outbuf)
  discard curl.easy_setopt(OPT_WRITEFUNCTION, write_callback)
  discard curl.easy_setopt(OPT_USERAGENT, "pastel-v0.1")
  let ret = curl.easy_perform()
  (ret, outbuf[])

when isMainModule:
  discard libcurl.global_init(GLOBAL_ALL)
  http_init()

  var res_get = http_get("http://localhost:8000/api/addr/ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP")
  if res_get.code == E_OK:
    echo res_get.data.parseJson()

  var post_json = %*{"addrs": ["ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP"]}
  var res_post = http_post("http://localhost:8000/api/addrs", $post_json)
  if res_post.code == E_OK:
    echo res_post.data.parseJson()

  http_cleanup()
  libcurl.global_cleanup()
