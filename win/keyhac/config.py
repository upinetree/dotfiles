import sys
import os
import datetime

import pyauto
from keyhac import *

def configure(keymap):

    # --------------------------------------------------------------------
    # config.py編集用のテキストエディタの設定

    # プログラムのファイルパスを設定 (単純な使用方法)
    keymap.editor = "C:\Programs\SublimeText2\sublime_text.exe"

    # --------------------------------------------------------------------
    # 表示のカスタマイズ

    # フォントの設定
    keymap.setFont( "ＭＳ ゴシック", 12 )

    # テーマの設定
    keymap.setTheme("black")

    # --------------------------------------------------------------------
    # キー設定

    # キーの単純な置き換え
    # KeySwapでRCtrlとCapsを交換してあることが前提
    keymap.replaceKey( "LCtrl", 235 )

    # ユーザモディファイアキーの定義
    keymap.defineModifier( 235, "User0" )

    # どのウインドウにフォーカスがあっても効くキーマップ
    keymap_global = keymap.defineWindowKeymap()

    keymap_global[ "Semicolon" ] = "S-Semicolon"
    keymap_global[ "S-Semicolon" ] = "Semicolon"

    # USER0
    if 1:

        # 通常Ctrlへ移譲
        keymap_global[ "U0-Z" ] = "C-Z"
        keymap_global[ "U0-X" ] = "C-X"
        keymap_global[ "U0-C" ] = "C-C"
        keymap_global[ "U0-S" ] = "C-S"

        # カーソル
        keymap_global[ "U0-H" ] = "Left"
        keymap_global[ "U0-J" ] = "Down"
        keymap_global[ "U0-K" ] = "Up"
        keymap_global[ "U0-L" ] = "Right"
        keymap_global[ "U0-A" ] = "Home"
        keymap_global[ "U0-E" ] = "End"
        keymap_global[ "U0-S-D" ] = "Delete"
        keymap_global[ "U0-S-H" ] = "Back"
        keymap_global[ "U0-S-W" ] = "C-S-Left", "C-X" # 単語左まで切り取り
        keymap_global[ "U0-S-U" ] = "S-Home", "C-X"   # 行頭まで切り取り
        keymap_global[ "U0-S-K" ] = "S-End", "C-X"    # 行末まで切り取り
        keymap_global[ "U0-OpenBracket" ] = "Esc"

        # USER0-↑↓←→ : 10pixel単位のウインドウの移動
        keymap_global[ "U0-Left"  ] = keymap.command_MoveWindow( -10, 0 )
        keymap_global[ "U0-Right" ] = keymap.command_MoveWindow( +10, 0 )
        keymap_global[ "U0-Up"    ] = keymap.command_MoveWindow( 0, -10 )
        keymap_global[ "U0-Down"  ] = keymap.command_MoveWindow( 0, +10 )

        # USER0-Ctrl-↑↓←→ : 画面の端まで移動
        keymap_global[ "U0-S-Left"  ] = keymap.command_MoveWindow_MonitorEdge(0)
        keymap_global[ "U0-S-Right" ] = keymap.command_MoveWindow_MonitorEdge(2)
        keymap_global[ "U0-S-Up"    ] = keymap.command_MoveWindow_MonitorEdge(1)
        keymap_global[ "U0-S-Down"  ] = keymap.command_MoveWindow_MonitorEdge(3)

        # クリップボード履歴
        keymap_global[ "U0-V" ] = keymap.command_ClipboardList # クリップボード履歴表示
        keymap.quote_mark = "> "                               # 引用貼り付け時の記号

        # USER0-Alt-↑↓←→/Space/PageUp/PageDown : キーボードで擬似マウス操作
        keymap_global[ "U0-A-H"       ] = keymap.command_MouseMove(-10,0)
        keymap_global[ "U0-A-L"       ] = keymap.command_MouseMove(10,0)
        keymap_global[ "U0-A-K"       ] = keymap.command_MouseMove(0,-10)
        keymap_global[ "U0-A-J"       ] = keymap.command_MouseMove(0,10)
        keymap_global[ "D-U0-A-Space" ] = keymap.command_MouseButtonDown('left')
        keymap_global[ "U-U0-A-Space" ] = keymap.command_MouseButtonUp('left')


    # --------------------------------------------------------------------
    # クリップボード履歴

    # クリップボード履歴の最大数 (デフォルト:1000)
    keymap.clipboard_history.maxnum = 1000

    # クリップボード履歴として保存する合計最大サイズ (デフォルト:10MB)
    keymap.clipboard_history.quota = 10*1024*1024

    # クリップボード履歴リスト表示のカスタマイズ
    if 1:

        # 定型文
        fixed_items = [
            ( "name@server.net",     "name@server.net" ),
            ( "住所",                "〒東京都品川区123-456" ),
            ( "電話番号",            "03-4567-8901" ),
        ]

        # フォーマット文字列で現在日時の文字列を生成
        def dateAndTime(fmt):
            def _dateAndTime():
                return datetime.datetime.now().strftime(fmt)
            return _dateAndTime

        # 日時
        datetime_items = [
            ( "YYYY/MM/DD HH:MM:SS",   dateAndTime("%Y/%m/%d %H:%M:%S") ),
            ( "YYYY/MM/DD",            dateAndTime("%Y/%m/%d") ),
            ( "HH:MM:SS",              dateAndTime("%H:%M:%S") ),
            ( "YYYYMMDD_HHMMSS",       dateAndTime("%Y%m%d_%H%M%S") ),
            ( "YYYYMMDD",              dateAndTime("%Y%m%d") ),
            ( "HHMMSS",                dateAndTime("%H%M%S") ),
        ]

        # 文字列に引用符を付ける
        def quoteClipboardText():
            s = getClipboardText()
            lines = s.splitlines(True)
            s = ""
            for line in lines:
                s += keymap.quote_mark + line
            return s

        # 文字列をインデントする
        def indentClipboardText():
            s = getClipboardText()
            lines = s.splitlines(True)
            s = ""
            for line in lines:
                if line.lstrip():
                    line = " " * 4 + line
                s += line
            return s

        # 文字列をアンインデントする
        def unindentClipboardText():
            s = getClipboardText()
            lines = s.splitlines(True)
            s = ""
            for line in lines:
                for i in range(4+1):
                    if i>=len(line) : break
                    if line[i]=='\t':
                        i+=1
                        break
                    if line[i]!=' ':
                        break
                s += line[i:]
            return s

        full_width_chars = "ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ！”＃＄％＆’（）＊＋，−．／：；＜＝＞？＠［￥］＾＿‘｛｜｝～０１２３４５６７８９　"
        half_width_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&'()*+,-./:;<=>?@[\]^_`{|}～0123456789 "

        # 文字列を半角文字にする
        def toHalfWidthClipboardText():
            s = getClipboardText()
            s = s.translate(str.maketrans(full_width_chars,half_width_chars))
            return s

        # 文字列を全角文字にする
        def toFullWidthClipboardText():
            s = getClipboardText()
            s = s.translate(str.maketrans(half_width_chars,full_width_chars))
            return s

        # クリップボードの内容をデスクトップに保存
        def command_SaveClipboardToDesktop():

            text = getClipboardText()
            if not text: return

            # utf-8 / CR-LF に変換
            utf8_bom = b"\xEF\xBB\xBF"
            text = text.replace("\r\n","\n")
            text = text.replace("\r","\n")
            text = text.replace("\n","\r\n")
            text = text.encode( encoding="utf-8" )

            # デスクトップに保存
            fullpath = os.path.join( getDesktopPath(), datetime.datetime.now().strftime("clip_%Y%m%d_%H%M%S.txt") )
            fd = open( fullpath, "wb" )
            fd.write(utf8_bom)
            fd.write(text)
            fd.close()

            # テキストエディタを開く
            keymap.editTextFile(fullpath)

        # その他
        other_items = [
            ( "Quote clipboard",            quoteClipboardText ),
            ( "Indent clipboard",           indentClipboardText ),
            ( "Unindent clipboard",         unindentClipboardText ),
            ( "",                           None ),
            ( "To Half-Width",              toHalfWidthClipboardText ),
            ( "To Full-Width",              toFullWidthClipboardText ),
            ( "",                           None ),
            ( "Save clipboard to Desktop",  command_SaveClipboardToDesktop ),
            ( "",                           None ),
            ( "Edit config.py",             keymap.command_EditConfig ),
            ( "Reload config.py",           keymap.command_ReloadConfig ),
        ]

        # クリップボード履歴リストのメニューリスト
        keymap.cblisters += [
            ( "定型文",  cblister_FixedPhrase(fixed_items) ),
            ( "日時",    cblister_FixedPhrase(datetime_items) ),
            ( "その他",  cblister_FixedPhrase(other_items) ),
        ]

