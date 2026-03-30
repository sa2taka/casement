# Casement

macOS 向けの高速キーボード駆動ウィンドウスイッチャー。

Casement は、開いている全てのウィンドウをアプリ名やタイトルで検索し、数キーストロークで即座にフォーカスを切り替えます。ウィンドウ版の Spotlight です。

## 機能

- **グローバルホットキー** --- `Option+Space` でどこからでも検索パネルを起動
- **あいまい検索** --- アプリ名、タイトル、頭文字（アクロニム）、部分一致で検索
- **スマートランキング** --- テキスト一致度、最近使用順（MRU）、ディスプレイ/Space のコンテキスト、学習ショートカットで順位付け
- **学習ショートカット** --- クエリとウィンドウ選択の対応を記憶し、次回以降の順位に反映
- **ウィンドウ切替** --- アプリの activate、ウィンドウの raise、最小化解除、Space 跨ぎをリトライ付きで処理
- **アプリ除外** --- ノイズになるアプリを検索対象から除外可能
- **メニューバー常駐** --- Dock アイコンなしでメニューバーに常駐

## 要件

- macOS 14.0 (Sonoma) 以降
- Xcode 16.3 以降 (Swift 6.3)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- **Accessibility 権限**（ウィンドウ列挙とフォーカス切替に必須）

## セットアップ

### 1. 依存ツールのインストール

```bash
brew install xcodegen
```

### 2. Xcode プロジェクトの生成

```bash
git clone <repository-url>
cd casement
xcodegen generate
```

`project.yml` から `Casement.xcodeproj` が生成されます。

### 3. ビルドと実行

```bash
xcodebuild -project Casement.xcodeproj -scheme Casement -configuration Debug -derivedDataPath build build
```

```bash
open build/Build/Products/Debug/Casement.app
```

または Xcode で `Casement.xcodeproj` を開き、`Cmd+R` で実行。

初回起動時に Accessibility 権限の許可を求められます。**システム設定 > プライバシーとセキュリティ > アクセシビリティ** で Casement を有効にしてください。

### 4. Release ビルド

```bash
xcodebuild -project Casement.xcodeproj -scheme Casement -configuration Release -derivedDataPath build build
```

```bash
open build/Build/Products/Release/Casement.app
```

Release ビルドはコンパイラ最適化が有効で、日常利用に適しています。

### 5. テスト実行

```bash
xcodebuild test -project Casement.xcodeproj -scheme Casement -destination 'platform=macOS'
```

## 使い方

| 操作 | キー |
|---|---|
| 検索パネルを開く | `Option+Space`（設定で変更可能） |
| 検索パネルを閉じる | `Escape` |
| 候補を移動 | `Up`/`Down` 矢印キー or `Ctrl+P`/`Ctrl+N` |
| 選択したウィンドウへ切替 | `Enter` |
| 選択中のウィンドウのアクションを開く | `Tab` |
| アクションメニューを閉じる | `Escape` |

検索パネルが開いたら:
1. 文字を入力してアプリ名やタイトルで絞り込む
2. 矢印キー（または Ctrl+N / Ctrl+P）で候補を選択
3. Enter で対象ウィンドウへ切替
4. Tab でアクションを開く（例: アプリを検索対象から除外）

空クエリの場合は全ウィンドウが MRU 順で表示されます。

検索パネルはカーソルがあるディスプレイに表示されます。

### 設定

メニューバーアイコンから Preferences を開くか、`Cmd+,` で開けます:
- グローバルホットキーの変更
- 最小化/ユーティリティウィンドウの表示切替
- 除外アプリの管理
- 学習ショートカットデータのクリア

## アーキテクチャ

```
Casement/
  App/            -- エントリーポイント、AppDelegate、メニューバー
  Models/         -- WindowRecord, WindowStableID, RankingTypes
  Services/       -- コアロジック (WindowTracker, SearchIndex, RankingEngine, FocusEngine 等)
  ViewModels/     -- SearchPanelViewModel
  Views/          -- SwiftUI ビュー + NSPanel ラッパー
CasementTests/    -- ユニットテスト (36 テスト)
project.yml       -- XcodeGen プロジェクト定義
```

主要コンポーネント:
- **WindowTracker** --- CGWindowList + Accessibility API でウィンドウ列挙。イベント駆動 + ポーリングのハイブリッド
- **SearchIndex** --- インメモリインデックス。prefix / contains / acronym / subsequence マッチング
- **RankingEngine** --- 多要素スコアリング（テキスト一致、MRU 減衰、コンテキストボーナス、学習ショートカット、ペナルティ）
- **FocusEngine** --- ウィンドウ切替ステートマシン（activate > unminimize > raise > verify）リトライ付き

## 開発

`project.yml` を変更した場合は Xcode プロジェクトを再生成してください:

```bash
xcodegen generate
```

`.xcodeproj` は生成ファイルのため、バージョン管理にはコミットしません。

## ライセンス

未定
