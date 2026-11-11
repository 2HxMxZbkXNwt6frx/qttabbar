# QTTabBar 26H2対応フォーク（非公式）

Windows 11 26H2のエクスプローラーでQTTabBarのタブバーを使えるようにし、QTTabBar 2048 Beta2の機能を追加した、[indiff/qttabbar](https://github.com/indiff/qttabbar) の非公式フォークです。QuizoさんやindiffさんなどQTTabBarの作者とは無関係なので、このフォークの不具合を本家へ報告しないでください。

動作確認：Windows 11 Pro 26H2、ビルド 26300.9711。ほかのビルドでは動きが違う場合があります。

英語の説明と変更点の一覧は [README.md](README.md#about-this-fork) にあります。

## 用意するもの

[Releases](https://github.com/2HxMxZbkXNwt6frx/qttabbar/releases) の最新版から、次の2つをダウンロードします。

- `QTTabBar-Setup-1.6.4.msi`：本体のインストーラー
- `Source code (zip)`：下の手順で使うツールが入っています

ダウンロードしたら、2つとも右クリック → プロパティ →「許可する」にチェック → OK としてから、zipを展開します。

コマンドは、展開してできたフォルダーでPowerShellを開いて実行します。エクスプローラーでそのフォルダーを開き、アドレスバーに `powershell` と入力してEnterを押すと開けます。

「管理者として」と書いた手順だけは、スタートメニューでPowerShellを右クリック →「管理者として実行」で開き、`cd` でそのフォルダーへ移動してから実行します。

## 1. 準備

1. Windows 11を26H2に更新します。
2. ほかのQTTabBarをアンインストールして、PCを再起動します。QTTabBar 2048の設定を引き継ぐなら、先にXMLへエクスポートしておきます。
3. Windows 10風のリボン表示にしたい場合は、[ExplorerPatcher](https://github.com/valinet/ExplorerPatcher/releases) を入れて、サインインし直します（任意）。

## 2. 旧ツールバーを戻す（管理者として）

26H2ではWindowsの機能フラグでエクスプローラーの旧ツールバーが消されていて、そのままではQTTabBarを表示できません。

**この手順はWindows全体の設定を変更します。** 自己責任で行い、先に復元ポイントを作っておいてください。

- 旧ツールバーを消している設定をバックアップしてから削除し、代わりに無効化の設定を書き込みます。
- Windows Updateで元に戻された場合に備えて、起動時に修正を掛け直すタスク（SYSTEM権限）を登録します。
- Microsoftのサポート対象ではありません。今後の更新で動かなくなる可能性があります。

```
powershell -ExecutionPolicy Bypass -File .\Tools\Win11ToolbarFix\Win11ToolbarFix.ps1 -Action InstallTask
```

終わったら**PCを再起動**します。再起動後に次を実行し、`Result: OK` と出ることを確認します。

```
powershell -ExecutionPolicy Bypass -File .\Tools\Win11ToolbarFix\Win11ToolbarFix.ps1 -Action Status
```

## 3. QTTabBarを入れる

ダウンロードした `QTTabBar-Setup-1.6.4.msi` をダブルクリックして、画面の指示に従います。

- 「Install」を押すとUACの確認が1回出るので「はい」を選びます。そのあと、開いているエクスプローラーのウィンドウがすべて閉じ、タスクバーが一度消えて戻ります。ファイルのコピー中なら、終わるのを待ってから進めてください。
- 最後の画面ではチェックを入れたまま「Finish」を押します。エクスプローラーが再起動し、保存されたタブの入ったウィンドウが開きます。

## 4. バーを表示する

- ExplorerPatcherのリボン：[表示] タブ → [オプション] の矢印 → `QTTabBar` と `QTTab Standard Buttons` を選びます。
- Windows標準の画面：Altキーを押して離すとメニューバーが出るので、[表示] → [ツール バー] から選びます。

## 5. 確認

```
powershell -ExecutionPolicy Bypass -File .\Tools\QTTabBarDoctor\QTTabBarDoctor.ps1
```

最後が `Result: nothing wrong found.` なら完了です（レポートはデスクトップにも保存されます）。`!` で始まる行が出たら、その内容に従ってください。多くは「困ったとき」のRepairで直ります。

## 日本語で使う

オプション →「Language」→「Use built-in language」で「日本語」を選びます。Windowsが日本語なら、新規インストールでは最初から日本語になります。一部のプラグイン名と説明は、本家の中国語のままです。

## QTTabBar 2048 Beta2の設定を引き継ぐ（任意）

```
powershell -ExecutionPolicy Bypass -File .\Tools\Import2048Settings\Import-QTTabBar2048Settings.ps1 -XmlPath C:\path\to\export.xml
```

まず書き込みはせず、何がどう変換されるか（移せない項目も）を表示します。内容でよければ末尾に `-Apply` を付けて実行し、**QTTabBarのオプションを開く前に**サインインし直します。エクスプローラーが古い設定で上書きするのを防ぐためです。

## タブとウィンドウの動き

- ほかのアプリが開いたフォルダは、最後に使ったタブ付きウィンドウのタブとして開きます。
- タブをウィンドウの外へドラッグして離すと、そのタブだけの新しいウィンドウになります。別のタブ付きウィンドウの上で離すと、そのウィンドウへ移動します。
- タブ付きウィンドウからコントロールパネルを開くと、コントロールパネルは別のウィンドウに出ます。タブ付きウィンドウは一度閉じて、同じ場所に開き直されます。タブと並び順は残りますが、戻る・進むの履歴は消えます。

## 更新するとき

新しいMSIをダウンロードして、手順3と同じようにダブルクリックで入れるだけです。設定はそのまま残ります。

## 困ったとき

| 症状 | すること |
|---|---|
| タブバーが出ない | 手順2のStatusが `OK` か確認し、再起動していなければ再起動します。そのあと手順4を確認します |
| 動きがおかしい、更新したのに直らない | 手順5で状態を確認します。`!` の行が出たら、普通のPowerShellで `QTTabBarDoctor.ps1 -Action Repair -Msi "<MSIのパス>"` を実行します。エクスプローラーを閉じた状態でMSIを入れ直します |
| 今の設定を保存したい | `QTTabBarDoctor.ps1 -Action ExportSettings`（デスクトップに .reg を保存） |
| 保存した設定を戻したい | `QTTabBarDoctor.ps1 -Action ImportSettings -SettingsFile <.regのパス>` |
| 旧ツールバーの修正を元に戻したい | 管理者として `Win11ToolbarFix.ps1 -Action Restore` を実行し、PCを再起動します |
| QTTabBarを外したい | 設定 → アプリ から「QTTabBar 1.6.4 Beta(2026)」をアンインストールします |

## ライセンス

GPL v3（[LICENSE.txt](LICENSE.txt)）です。無保証です。QTTabBar 2048は別のソース非公開ソフトで、このプロジェクトの一部ではありません。このフォークに2048のコード、バイナリ、画像は含まれていません。
