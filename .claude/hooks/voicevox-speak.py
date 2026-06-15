#!/usr/bin/env python3
"""Claude Code hook: Notification / Stop イベントの内容を VOICEVOX で読み上げる。

- Stop        : transcript から最後のアシスタント返答を取り出し、冒頭 1〜2 文を読む
- Notification: ずんだもん時は内容を一般化した定型セリフをランダムに(詳細は画面で
                分かる前提)、それ以外の話者は渡された message をそのまま読む

エンジン(http://127.0.0.1:50021)が停止していたら、バックグラウンドで自動起動を
仕掛けてその回はスキップする(次回の hook から読み上げる)。
hook を絶対に失敗させないため、例外はすべて握りつぶして exit 0 で抜ける。

環境変数:
  VOICEVOX_HOST       既定 127.0.0.1:50021
  VOICEVOX_SPEAKER    既定 3 (ずんだもん ノーマル)
  VOICEVOX_MAXLEN     既定 120 (読み上げ最大文字数)
  VOICEVOX_ENGINE_BIN 既定 /Applications/VOICEVOX.app/.../vv-engine/run
                      (未起動時に自動起動するエンジン本体。空にすると自動起動しない)
  VOICEVOX_ZUNDAMON_STYLES 既定 1,3,5,7,22,38,75,76
                      (この SPEAKER のとき語尾を「のだ」口調に簡易変換する)

エンジンの手動操作:
  停止 : lsof -ti:50021 | xargs kill
  状態 : curl -s http://127.0.0.1:50021/version
  (停止後、次の hook で自動的に再起動される。完全に止めるなら本スクリプトの
   hook 登録を settings.json から外すか VOICEVOX_ENGINE_BIN を空にする)
"""
import fcntl
import json
import os
import random
import re
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request

HOST = os.environ.get("VOICEVOX_HOST", "127.0.0.1:50021")
SPEAKER = os.environ.get("VOICEVOX_SPEAKER", "3")
MAXLEN = int(os.environ.get("VOICEVOX_MAXLEN", "120"))
BASE = f"http://{HOST}"

# エンジン未起動なら GUI なしでバックグラウンド起動する(初回はその回をスキップ)
ENGINE_BIN = os.environ.get(
    "VOICEVOX_ENGINE_BIN",
    "/Applications/VOICEVOX.app/Contents/Resources/vv-engine/run",
)
LAUNCH_LOCK = "/tmp/voicevox-engine.launching"
LAUNCH_COOLDOWN = 60  # 秒。直近に起動を試みていたら再起動しない(立ち上がり待ち)

# ずんだもんのスタイル ID(エンジンの /speakers 由来)。選択時に「のだ」口調にする
_ZUNDA_DEFAULT = "1,3,5,7,22,38,75,76"
ZUNDAMON_STYLES = {
    s.strip()
    for s in os.environ.get("VOICEVOX_ZUNDAMON_STYLES", _ZUNDA_DEFAULT).split(",")
    if s.strip()
}


def http(method, path, data=None, headers=None, timeout=10):
    req = urllib.request.Request(f"{BASE}{path}", data=data, method=method,
                                 headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def engine_alive():
    try:
        http("GET", "/version", timeout=1)
        return True
    except Exception:
        return False


def try_launch_engine():
    """エンジンが落ちていれば GUI なしでバックグラウンド起動する。

    複数 hook(Notification/Stop)が同時に走っても二重起動しないよう、起動を
    試みた時刻(LAUNCH_LOCK の mtime)によるクールダウンと flock で抑制する。
    起動コマンドを投げるだけで再生はしない(呼び出し側がこの後 return する)。
    """
    if not ENGINE_BIN or not os.path.exists(ENGINE_BIN):
        return
    # 直近に起動を試みていれば、立ち上がり待ちとみなしスキップ
    try:
        if time.time() - os.path.getmtime(LAUNCH_LOCK) < LAUNCH_COOLDOWN:
            return
    except OSError:
        pass
    try:
        lock = open(LAUNCH_LOCK, "w")  # open("w") で mtime 更新 = クールダウン起点
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return  # 別の hook が今まさに起動処理中
    host, _, port = HOST.partition(":")
    try:
        logf = open("/tmp/voicevox-engine.log", "ab")
        subprocess.Popen(
            [ENGINE_BIN, "--host", host or "127.0.0.1", "--port", port or "50021"],
            stdout=logf, stderr=logf, stdin=subprocess.DEVNULL,
            start_new_session=True,  # 親(hook プロセス)終了後も生存させる
        )
    except Exception:
        pass


def last_assistant_text(transcript_path):
    """transcript(JSONL) から、テキストを含む最後の assistant 発言を返す。"""
    text = ""
    try:
        with open(transcript_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                if obj.get("type") != "assistant":
                    continue
                content = (obj.get("message") or {}).get("content")
                if isinstance(content, str):
                    if content.strip():
                        text = content
                elif isinstance(content, list):
                    parts = [b.get("text", "") for b in content
                             if isinstance(b, dict) and b.get("type") == "text"]
                    joined = "".join(parts).strip()
                    if joined:
                        text = joined
    except Exception:
        pass
    return text


def clean(text):
    """マークダウン/コード/URL/記号を落として読み上げ用の素のテキストにする。"""
    text = re.sub(r"```.*?```", "", text, flags=re.S)          # コードブロック
    text = re.sub(r"`([^`]*)`", r"\1", text)                   # インラインコード
    text = re.sub(r"https?://\S+", "", text)                   # URL
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)      # リンク/画像
    text = re.sub(r"^\s*[#>\-\*\|]+\s*", "", text, flags=re.M)  # 行頭記号
    text = re.sub(r"[*_~#>`|]", "", text)                       # 残りの装飾記号
    text = text.replace("\n", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text


def head_sentences(text, max_sentences=2):
    """先頭 max_sentences 文、ただし MAXLEN 文字でも打ち切る。"""
    sentences = re.split(r"(?<=[。！？!?])", text)
    out = ""
    for s in sentences:
        if not s:
            continue
        if out and len(out) + len(s) > MAXLEN:
            break
        out += s
        if out.count("。") + out.count("！") + out.count("？") \
                + out.count("!") + out.count("?") >= max_sentences:
            break
    if not out:
        out = text
    if len(out) > MAXLEN:
        out = out[:MAXLEN]
    return out.strip()


# 文末表現 → ずんだもん口調。長い/具体的なものから順に判定する(最初の一致を採用)
_ZUNDA_RULES = [
    ("でしょうか", "なのだ"),
    ("ていますか", "ているのだ"),
    ("しますか", "するのだ"),
    ("ませんか", "ないのだ"),
    ("ましたか", "したのだ"),
    ("ですか", "なのだ"),
    ("ますか", "のだ"),
    ("でしょう", "なのだ"),
    ("ていました", "ていたのだ"),
    ("しました", "したのだ"),
    # 五段動詞の音便: 「ました」直前の仮名で過去形を作る(促音便・撥音便)
    ("りました", "ったのだ"),  # 直り→直った
    ("ちました", "ったのだ"),  # 待ち→待った
    ("いました", "ったのだ"),  # 買い→買った
    ("みました", "んだのだ"),  # 読み→読んだ
    ("びました", "んだのだ"),  # 飛び→飛んだ
    ("にました", "んだのだ"),  # 死に→死んだ
    ("ました", "たのだ"),
    ("ません", "ないのだ"),
    ("ましょう", "するのだ"),
    ("ています", "ているのだ"),
    ("します", "するのだ"),
    ("です", "なのだ"),
    ("ます", "のだ"),
    ("である", "なのだ"),
    ("だった", "だったのだ"),
    ("した", "したのだ"),
    ("ない", "ないのだ"),
    ("だ", "なのだ"),
]


def zundamon_style(text):
    """文末の丁寧/断定表現を「のだ」口調に簡易変換する(ルールベース・近似)。

    形態素解析はしないので、よくある文末パターンだけを文ごとに置換する。
    変換できない文末(体言止め等)はそのまま残す。
    """
    parts = re.split(r"([。！？!?])", text)  # 区切り文字も保持して分割
    out = []
    for i, seg in enumerate(parts):
        if i % 2 == 1:  # 区切り文字はそのまま
            out.append(seg)
            continue
        body = seg.rstrip()
        tail = seg[len(body):]  # 末尾空白を保持
        if not body.endswith("のだ"):  # 既に「のだ」口調なら二重変換しない
            for key, val in _ZUNDA_RULES:
                if body.endswith(key):
                    body = body[:-len(key)] + val
                    break
        out.append(body + tail)
    return "".join(out)


# Notification を一般化したずんだもんの定型セリフ(詳細は画面で分かる前提)
NOTIFY_ZUNDA = {
    "permission": [
        "許可がほしいのだ！",
        "ボクに権限をくれるのだ？",
        "確認してほしいのだ！",
        "ゴーサインを待ってるのだ！",
        "ポチッとしてほしいのだ！",
    ],
    "idle": [
        "次の指示がほしいのだ！",
        "ボク、待ってるのだ！",
        "ボク、手が空いちゃったのだ。",
        "なにをすればいいのだ？",
    ],
    "default": [
        "お知らせなのだ！",
        "ちょっと見てほしいのだ！",
        "呼んでるのだ！",
    ],
}


def notification_text(message):
    """Notification の読み上げ文を決める。

    ずんだもん(ZUNDAMON_STYLES)のときは内容を一般化した定型セリフをランダムに返す。
    許可待ち/入力待ちだけ message から大まかに判定して出し分ける。
    それ以外の話者では message をそのまま整形して返す。
    """
    if SPEAKER not in ZUNDAMON_STYLES:
        return clean(message or "")
    msg = (message or "").lower()
    if any(k in msg for k in ("permission", "approve", "allow")):
        key = "permission"
    elif any(k in msg for k in ("waiting", "input", "idle")):
        key = "idle"
    else:
        key = "default"
    return random.choice(NOTIFY_ZUNDA[key])


def speak(text):
    if not text:
        return
    q = urllib.parse.urlencode({"text": text, "speaker": SPEAKER})
    query = http("POST", f"/audio_query?{q}", timeout=10)
    wav = http("POST", f"/synthesis?speaker={SPEAKER}", data=query,
               headers={"Content-Type": "application/json"}, timeout=30)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        tf.write(wav)
        path = tf.name
    try:
        subprocess.run(["afplay", path], check=False)
    finally:
        try:
            os.remove(path)
        except OSError:
            pass


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    event = data.get("hook_event_name", "")
    if event == "Notification":
        text = notification_text(data.get("message", ""))
    elif event == "Stop":
        raw = last_assistant_text(data.get("transcript_path", ""))
        text = head_sentences(clean(raw))
    else:
        return
    if SPEAKER in ZUNDAMON_STYLES:
        text = zundamon_style(text)
    if not text:
        return
    if not engine_alive():
        # 今回は起動を仕掛けるだけでスキップ。次回の hook から読み上げる
        try_launch_engine()
        return
    try:
        speak(text)
    except Exception:
        pass


if __name__ == "__main__":
    main()
