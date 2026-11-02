# QTTabBar 26H2 キット 手順書

このフォルダーだけで、別の PC（Windows 11 26H2）に今の PC と同じ QTTabBar 環境を作れます。
作ったときの情報（版・日時）は `kit-info.txt` にあります。

## 中身

| ファイル | 用途 |
|---|---|
| `QTTabBar Setup *.msi` | QTTabBar 本体のインストーラー（手順 3 で使う） |
| `tools\QTTabBarDoctor.ps1` | インストール・修復・状態確認・設定の書き出し/取り込み |
| `tools\Win11ToolbarFix.ps1` | 26H2 で消されたエクスプローラーの旧ツールバーを戻す（QTTabBar の置き場所） |
| `tools\Import-QTTabBar2048Settings.ps1` | QTTabBar 2048 Beta2 の設定（XML）をこの版に変換 |
| `settings\`（ある場合） | 元の PC の QTTabBar 設定、ExplorerPatcher の設定 |

## 0. 準備

1. Windows 11 を 26H2 に更新しておく（設定 → Windows Update）。
2. **QTTabBar 2048 を使っている PC では**、先に 2048 のオプションで設定を XML にエクスポートしてから、
   設定 → アプリ から QTTabBar 2048 をアンインストールし、PC を再起動する。
3. このフォルダーを PC にコピーする（例: `C:\QTTabBar-26H2-Kit`）。
   zip で持ってきた場合は、展開する前に zip を右クリック → プロパティ → 「許可する」にチェック → OK。
4. 以下のコマンドは、このフォルダーで PowerShell を開いて実行する
   （エクスプローラーでこのフォルダーを開き、アドレスバーに `powershell` と入力して Enter）。
   「管理者として」と書いた手順だけ、スタートメニューで PowerShell を右クリック → 管理者として実行 し、
   `cd` でこのフォルダーに移動してから実行する。

## 1. ExplorerPatcher（今の PC と同じ Windows 10 風リボン表示にする場合）

1. https://github.com/valinet/ExplorerPatcher/releases から最新の `ep_setup.exe` を入れる。
2. `settings` に `ExplorerPatcher_*.reg` があれば、ダブルクリックして取り込む。
3. サインアウトしてサインインし直す。

## 2. 旧ツールバーを戻す（必須・管理者として）

26H2 では Windows の機能フラグでエクスプローラーの旧ツールバーが消されており、そのままでは QTTabBar が表示されません。

```
powershell -ExecutionPolicy Bypass -File .\tools\Win11ToolbarFix.ps1 -Action InstallTask
```

修正を入れ、Windows Update で元に戻されたときに起動時に自動で掛け直すタスクも登録します。
**終わったら PC を再起動**。再起動後に次を実行し、`Result: OK` と出ることを確認します。

```
powershell -ExecutionPolicy Bypass -File .\tools\Win11ToolbarFix.ps1 -Action Status
```

## 3. QTTabBar を入れる（普通の PowerShell で）

```
powershell -ExecutionPolicy Bypass -File .\tools\QTTabBarDoctor.ps1 -Action Repair
```

- 開いているエクスプローラーが一度閉じ、タスクバーが消えます。UAC の確認が 1 回出るので「はい」。
- 最後に `Repaired: QTTabBar.dll in the GAC is the build that was installed.` と出れば完了。

## 4. 設定を入れる（A か B のどちらか）

### A. 元の PC の設定をそのまま使う（`settings\QTTabBar-settings-*.reg` がある場合）

```
powershell -ExecutionPolicy Bypass -File .\tools\QTTabBarDoctor.ps1 -Action ImportSettings -SettingsFile .\settings\QTTabBar-settings-<PC名>-<日付>.reg
```

- エクスプローラーを閉じてから取り込み、取り込み後に起動し直します（開いたままだと設定が上書きされるため）。
- それまでの設定は `%TEMP%` に自動でバックアップされます。
- 前回のタブ・グループ・アプリも一緒に入ります。
- タブのスキン画像・ボタンバーの画像は元の PC の場所（例: `C:\Users\<名前>\OneDrive\qtt\…`）を指しています。
  ユーザー名や OneDrive の場所が同じならそのまま表示されます。違う場合は QTTabBar のオプション → 外観 / ボタンバー で選び直してください。

### B. その PC の 2048 Beta2 の設定を変換する

```
powershell -ExecutionPolicy Bypass -File .\tools\Import-QTTabBar2048Settings.ps1 -XmlPath <エクスポートした XML>
```

まずは書き込まずに、何がどう変換されるか（移せない項目も）を表示します。内容でよければ `-Apply` を付けて実行し、
**QTTabBar のオプションを開く前に**サインアウト → サインインします（エクスプローラーが古い設定で上書きするのを防ぐため）。

## 5. 確認

```
powershell -ExecutionPolicy Bypass -File .\tools\QTTabBarDoctor.ps1
```

最後が `Result: nothing wrong found.` なら完了です（レポートはデスクトップにも保存されます）。
`!` で始まる行が出たら、その内容に従ってください（多くは手順 3 の Repair で直ります）。

## 6. （任意）Windows 標準のエクスプローラータブを止める

元の PC では Windows 11 のエクスプローラータブを ViVeTool で止めています。この版の QTTabBar では必須ではありませんが、
同じにする場合は ViVeTool（https://github.com/thebookisclosed/ViVe/releases ）を管理者として:

```
vivetool /disable /id:37634385,39145991,36354489
```

→ PC を再起動。手順 5 のレポートの「Windows feature flags」で状態を確認できます
（元の PC で他に有効にしている ID もそこに一覧されます。QTTabBar とは関係ありません）。

## 更新するとき

新しいキット（または新しい MSI）が届いたら、手順 3 のコマンドを実行するだけです。設定はそのまま残ります。

## 困ったとき

| 症状 | すること |
|---|---|
| タブバーが出ない | 手順 2 の Status が `OK` か確認。再起動していなければ再起動 |
| 動きがおかしい・更新したのに直らない | 手順 5 で状態を確認し、`!` の行に従う（多くは手順 3 で直る） |
| 左のツリーの中クリックなどで何が起きているか知りたい | `QTTabBarDoctor.ps1 -Action Watch` を実行してから中クリック |
| 今の設定を保存したい | `QTTabBarDoctor.ps1 -Action ExportSettings`（デスクトップに .reg を保存） |
| 旧ツールバーの修正を元に戻したい | 管理者として `Win11ToolbarFix.ps1 -Action Restore` → 再起動 |
| QTTabBar を外したい | 設定 → アプリ から「QTTabBar 1.6.4 Beta(2026)」をアンインストール |
