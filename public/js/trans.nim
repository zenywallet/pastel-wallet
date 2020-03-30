# Copyright (c) 2019 zenywallet

include karax / i18n

template trans*(x: string): cstring = cstring(i18n(x))
template trans*(x: string, param: openarray[cstring]): cstring = i18n(x) % param
proc jstrans(x: cstring, param: openarray[cstring] = []): cstring =
  if param.len > 0:
    TranslatedString(translate(cstring x)) % param
  else:
    cstring(TranslatedString(translate(cstring x)))

proc setlang(lang: cstring) =
  if lang.startsWith("ja"):
    setCurrentLanguage(Language.jaJP)
  elif lang.startsWith("en"):
    setCurrentLanguage(Language.enUS)
  else:
    setCurrentLanguage(Language.enUS)

{.emit: """
var __t = `jstrans`;
var setlang = `setlang`;
var navlang = window.navigator.language || window.navigator.userLanguage || window.navigator.browserLanguage;
setlang(navlang || 'en');
""".}

addTranslation(Language.jaJP, "Scan your seed cards or input your mnemonic to start.", "はじめるにはSeedカードを読み取るか、またはニーモニックを入力してしてください。")
addTranslation(Language.jaJP, "Seed card", "Seedカード")
addTranslation(Language.jaJP, "Mnemonic", "ニーモニック")
addTranslation(Language.jaJP, "Scan seed card with camera", "カメラでSeedカードを読み取る")
addTranslation(Language.jaJP, "Select mnemonic language", "ニーモニックの言語選択")
addTranslation(Language.jaJP, "Japanese", "日本語")
addTranslation(Language.jaJP, "English", "英語")
addTranslation(Language.jaJP, "Import your mnemonic you already have", "所有しているニーモニックのインポート")
addTranslation(Language.jaJP, "Check", "確認")
addTranslation(Language.jaJP, "Advanced Check", "高度な確認")
addTranslation(Language.jaJP, "Preparing Camera", "カメラの準備中")
addTranslation(Language.jaJP, "Seed", "Seed")
addTranslation(Language.jaJP, "unknown", "不明")
addTranslation(Language.jaJP, "Seed Vector:", "Seedベクター:")
addTranslation(Language.jaJP, "Type your seed vector", "Seedベクターを入力")
addTranslation(Language.jaJP, "Next", "次へ")
addTranslation(Language.jaJP, "Back", "戻る")
addTranslation(Language.jaJP, """
A key card or passphrase is required to encrypt and save the private key in your browser.
 You will need it before sending your coins.
""", """
秘密鍵を暗号化しブラウザ内に保存するためにキーカードまたはパスフレーズを設定してください。
 キーカードまたはパスフレーズはコインを送信するときに必要になります。
""")
addTranslation(Language.jaJP, "Key card", "キーカード")
addTranslation(Language.jaJP, "Passphrase", "パスフレーズ")
addTranslation(Language.jaJP, "Scan key card with camera", "カメラでキーカードを読み取る")
addTranslation(Language.jaJP, "Input passphrase", "パスフレーズの入力")
addTranslation(Language.jaJP, "Apply", "設定")
addTranslation(Language.jaJP, "Scanned key card", "読み取ったキーカード")
addTranslation(Language.jaJP, "Rescan", "再読み取り")

addTranslation(Language.jaJP, "Send", "送信")
addTranslation(Language.jaJP, "Receive", "受信")
addTranslation(Language.jaJP, "Settings", "設定")
addTranslation(Language.jaJP, "Logs", "履歴")

addTranslation(Language.jaJP, "Send Coins", "コイン送信")
addTranslation(Language.jaJP, "Locked", "ロック中")
addTranslation(Language.jaJP, "Unlocked", "ロック解除済み")
addTranslation(Language.jaJP, "Please unlock your wallet before sending coins.", "コインを送信する前にウォレットのロックを解除してください。")
addTranslation(Language.jaJP, "Clear", "削除")
addTranslation(Language.jaJP, "Scan QR Code", "QRコード読み取り")
addTranslation(Language.jaJP, "-1 Ball", "-1 ボール")
addTranslation(Language.jaJP, "+1 Ball", "+1 ボール")
addTranslation(Language.jaJP, "Send Address", "送信アドレス")
addTranslation(Language.jaJP, "Address", "アドレス")
addTranslation(Language.jaJP, "Send", "送信")
addTranslation(Language.jaJP, "Receive Address", "受信アドレス")
addTranslation(Language.jaJP, "Copy", "コピー")
addTranslation(Language.jaJP, "Copied to clipboard", "クリップボードにコピーしました。")
addTranslation(Language.jaJP, "Create QR Code", "QRコード作成")
addTranslation(Language.jaJP, "Amount", "数量")
addTranslation(Language.jaJP, "Label", "ラベル")
addTranslation(Language.jaJP, "Message", "メッセージ")
addTranslation(Language.jaJP, "Scan your key card", "キーカード読み取り")
addTranslation(Language.jaJP, "Cancel", "キャンセル")
addTranslation(Language.jaJP, "Change-", "おつり-")
addTranslation(Language.jaJP, "Too Much Balls", "多すぎるボール")
addTranslation(Language.jaJP, "$#$ years ago", "$#$ 年前")
addTranslation(Language.jaJP, "$#$ year ago", "$#$ 年前")
addTranslation(Language.jaJP, "$#$ years $#$ months ago", "$#$ 年 $#$ヶ月前")
addTranslation(Language.jaJP, "$#$ year $#$ months ago", "$#$ 年 $#$ヶ月前")
addTranslation(Language.jaJP, "$#$ years $#$ month ago", "$#$ 年 $#$ヶ月前")
addTranslation(Language.jaJP, "$#$ year $#$ month ago", "$#$ 年 $#$ヶ月前")
addTranslation(Language.jaJP, "$#$ months ago", "$#$ ヶ月前")
addTranslation(Language.jaJP, "$#$ month ago", "$#$ ヶ月前")
addTranslation(Language.jaJP, "$#$ weeks ago", "$#$ 週間前")
addTranslation(Language.jaJP, "$#$ week ago", "$#$ 週間前")
addTranslation(Language.jaJP, "$#$ days ago", "$#$ 日前")
addTranslation(Language.jaJP, "$#$ day ago", "$#$ 日前")
addTranslation(Language.jaJP, "$#$ hours ago", "$#$ 時間前")
addTranslation(Language.jaJP, "$#$ hour ago", "$#$ 時間前")
addTranslation(Language.jaJP, "$#$ minutes ago", "$#$ 分前")
addTranslation(Language.jaJP, "$#$ minute ago", "$#$ 分前")
addTranslation(Language.jaJP, "just now", "新着")
addTranslation(Language.jaJP, "SEND", "送信")
addTranslation(Language.jaJP, "RECEIVE", "受信")
addTranslation(Language.jaJP, "Confirmed", "確認済")
addTranslation(Language.jaJP, "Unconfirmed", "未確認")
addTranslation(Language.jaJP, "Reset Wallet", "ウォレットのリセット")
addTranslation(Language.jaJP, "Are you sure to reset your wallet?", "本当にウォレットをリセットしますか？")
addTranslation(Language.jaJP, "Reset", "リセット")
addTranslation(Language.jaJP, """
Delete all your wallet data in your web browser, including your encrypted secret keys.
 If you have coins in your wallet or waiting for receiving coins, make sure you have the seed cards
 or mnemonics before deleting it. Otherwise you may lost your coins forever.
""", """
ブラウザ内の暗号化した秘密鍵を含むすべてのウォレットデータを削除します。
 もしウォレットにコインが残っていたり、受信予定のコインがある場合は、削除前にSeedカードまたはニーモニックを持っていることを確認してください。
 そうしないとコインを永久に失うかもしれません。
""")
addTranslation(Language.jaJP, "I confirmed that I have the seed cards or mnemonics or no coins in my wallet.",
"私はSeedカードやニーモニックを持っています。またはウォレットにコインがありません。")
addTranslation(Language.jaJP, "Confirmation", "確認")
addTranslation(Language.jaJP, "Please read and check here before resetting your wallet.", "ウォレットをリセットする前に内容を読んでチェックをしてください。")
addTranslation(Language.jaJP, "Error", "エラー")
addTranslation(Language.jaJP, "Warning", "警告")
addTranslation(Language.jaJP, "Unsupported seed card was scanned.", "サポートしてないシードカードを読み取りました。")
addTranslation(Language.jaJP, "The seed card has already been scanned.", "すでに読み取り済みのシードカードです。")
addTranslation(Language.jaJP, "Failed to lock your wallet with the key card.", "キーカードによるウォレットのロックに失敗しました。")
addTranslation(Language.jaJP, "There are no misspellings, but some words seem to be wrong.", "不正なワードはありませんが、いくつかのワードが間違えています。")
addTranslation(Language.jaJP, "Try to use [Advanced Check]", "[高度な確認] を試してみてください。")
addTranslation(Language.jaJP, "Failed to lock your wallet with the passphrase.", "パスフレーズによるウォレットのロックに失敗しました。")
addTranslation(Language.jaJP, "Failed to unlock. Wrong key card was scanned.", "ロック解除に失敗しました。 キーカードが間違えています。")
addTranslation(Language.jaJP, "Failed to unlock. Passphrase is incorrect.", "ロック解除に失敗しました。 パスフレーズが間違えています。")
addTranslation(Language.jaJP, "Coins sent successfully.", "コインを送信しました。")
addTranslation(Language.jaJP, "Failed to send coins.", "コインの送信に失敗しました。")
addTranslation(Language.jaJP, "Address is invalid.", "アドレスが不正です。")
addTranslation(Language.jaJP, "Balance is insufficient.", "残高が不足しています。")
addTranslation(Language.jaJP, "Amount is zero.", "数量が 0 です。")
addTranslation(Language.jaJP, "Amount is too small.", "数量が小さすぎます。")
addTranslation(Language.jaJP, "Failed to send coins. Busy.", "コインの送信に失敗しました。 ビジー")
addTranslation(Language.jaJP, "Server is not responding. Coins may have been sent.", "サーバーが応答しません。 コインの送信に成功している可能性もあります。")
addTranslation(Language.jaJP, "Failed to send coins. Server error.", "コインの送信に失敗しました。 サーバーエラー")
addTranslation(Language.jaJP, "Failed to send coins. Server is not responding.", "サーバーが応答しません。")
addTranslation(Language.jaJP, "Amount is invalid. The decimal places is too long. Please set it 8 or less.", "数量が不正です。 小数点以下が長すぎます。 小数点以下の桁数は8以内にしてください。")
addTranslation(Language.jaJP, "Amount is invalid.", "数量が不正です。")
addTranslation(Language.jaJP, "Failed to lock keys.", "ロックに失敗しました。")
