# PRD: Key — Menubar Keybind Viewer for macOS

## Overview
macOSメニューバーに常駐し、クリックまたはグローバルショートカットでキーバインド一覧をポップアップ表示するネイティブアプリ。ダークテーマの固定サイズウィンドウに、カテゴリ別カラムレイアウトでキーバインドを表示する。データはローカルJSONファイルで管理し、ユーザーが自由に編集可能。

## Goals
- メニューバーアイコン（⌘）からワンクリックでキーバインド一覧を確認できる
- グローバルキーボードショートカットでポップアップを表示/非表示できる
- Editor、Git、Multiple Cursorセクションのキーバインドをカテゴリ別に表示する
- ローカルJSONファイルによるカスタマイズ可能なデータ管理
- spec.pngに準拠したダークテーマ・マルチカラムレイアウト

## Quality Gates

These commands must pass for every user story:
- `swift build` - ビルド成功
- `swiftlint` - Lint通過

## User Stories

### US-001: メニューバー常駐アプリの基盤作成
SwiftUIでmacOSメニューバー常駐アプリの基盤を作成する。起動時にDockに表示されず、メニューバーに「⌘」テキストアイコンで常駐する。

**Acceptance Criteria:**
- [ ] macOS menubar extra として「⌘」テキストアイコンが表示される
- [ ] Dockにアプリアイコンが表示されない（LSUIElement設定）
- [ ] メニューバーアイコンクリックでポップアップウィンドウが表示される
- [ ] ポップアップ外クリックでウィンドウが閉じる
- [ ] アプリ終了メニュー項目が存在する

### US-002: JSONキーバインドデータの読み込み
アプリバンドル内のデフォルトJSONと、`~/.config/key/keybinds.json`のユーザーカスタムJSONを読み込む仕組みを作成する。

**Acceptance Criteria:**
- [ ] デフォルトのキーバインドJSONがアプリバンドルに含まれる
- [ ] JSONスキーマ: カテゴリ名、キーバインド配列（アクション名+ショートカットキー）
- [ ] `~/.config/key/keybinds.json`が存在すればそちらを優先読み込み
- [ ] 存在しない場合はバンドル内デフォルトを使用
- [ ] JSONパースエラー時はデフォルトにフォールバック

### US-003: Editorセクションのキーバインドデータ作成
Editorセクション（Move Cursor, Selection, Scroll, Code Edit, Find, Split Editor Window, Code Jump, IntelliSense, File Explorer, IDE Feature, AI）のキーバインドデータをJSONで作成する。

**Acceptance Criteria:**
- [ ] Move Cursorカテゴリ: ^F/^B/^P/^N等のカーソル移動10項目
- [ ] Selectionカテゴリ: 範囲選択系12項目
- [ ] Scrollカテゴリ: ページ移動5項目
- [ ] Code Editカテゴリ: 編集操作14項目
- [ ] Findカテゴリ: 検索/置換4項目
- [ ] Split Editor Windowカテゴリ: 分割操作5項目
- [ ] Code Jumpカテゴリ: ジャンプ操作10項目
- [ ] IntelliSenseカテゴリ: 補完1項目
- [ ] File Explorerカテゴリ: ファイル操作8項目
- [ ] IDE Featureカテゴリ: IDE機能16項目
- [ ] AIカテゴリ: AI機能3項目

### US-004: Git・Multiple Cursorセクションのキーバインドデータ作成
Git（1項目）とMultiple Cursor（6項目）セクションのキーバインドデータをJSONに追加する。

**Acceptance Criteria:**
- [ ] Gitカテゴリ: Git Blame（^G ^B）
- [ ] Multiple Cursorカテゴリ: 6項目（Rectangular Selection等）
- [ ] 全データがUS-003と同一JSONファイル内に統合されている

### US-005: ダークテーマのポップアップウィンドウUI
spec.pngに準拠したダークテーマのポップアップウィンドウを実装する。固定サイズで、カテゴリをマルチカラムレイアウトで表示する。

**Acceptance Criteria:**
- [ ] 固定サイズのポップアップウィンドウ（約800x500pt程度）
- [ ] ダークテーマ背景（#1E1E1E系のダークグレー）
- [ ] モノスペースフォント使用（SF Mono or Menlo）
- [ ] カテゴリ名がボールドで表示される
- [ ] ショートカットキーが右寄せで表示される
- [ ] 修飾キー凡例がウィンドウ下部に表示される（⌘=command, ⌃=control, ⌥=option, ⇧=shift, ⏎=return）

### US-006: マルチカラムレイアウトの実装
spec.pngのようにカテゴリを複数カラムに配置するレイアウトを実装する。

**Acceptance Criteria:**
- [ ] カテゴリが3〜4カラムに分散配置される
- [ ] 各カラムの高さがバランスよく配分される
- [ ] カテゴリ間に適切な余白がある
- [ ] カテゴリ名とキーバインドリストが視覚的に区別できる
- [ ] スクロール不要で全データが1画面に収まる

### US-007: グローバルキーボードショートカット
グローバルキーボードショートカットでポップアップの表示/非表示を切り替える機能を実装する。

**Acceptance Criteria:**
- [ ] デフォルトのグローバルショートカットが設定されている（例: ⌘⇧K）
- [ ] ショートカットでポップアップのトグルが動作する
- [ ] 他のアプリがフォーカス中でもショートカットが機能する
- [ ] ショートカットキーの設定はJSONまたはアプリ設定で変更可能

### US-008: 設定メニューとアプリ管理
右クリックまたはメニューから設定ファイルを開く、ショートカット変更、アプリ終了などの管理機能を提供する。

**Acceptance Criteria:**
- [ ] メニューバーアイコン右クリックでコンテキストメニュー表示
- [ ] 「Edit Keybinds...」で`~/.config/key/keybinds.json`をデフォルトエディタで開く
- [ ] 「Reload」でJSONを再読み込みしてUIに反映
- [ ] 「Quit」でアプリ終了
- [ ] 初回起動時に`~/.config/key/`ディレクトリとデフォルトJSONを作成

## Functional Requirements
- FR-1: アプリはmacOS menubar extra（MenuBarExtra API）として動作する
- FR-2: メニューバーに「⌘」テキストが表示される
- FR-3: クリックで固定サイズのポップアップウィンドウが表示される
- FR-4: ポップアップはダークテーマのマルチカラムレイアウト
- FR-5: キーバインドデータは`~/.config/key/keybinds.json`から読み込む
- FR-6: ファイルが存在しない場合はバンドル内デフォルトJSONを使用
- FR-7: グローバルショートカットでポップアップをトグル可能
- FR-8: 修飾キーは記号表記を使用（⌘⌃⌥⇧）
- FR-9: 右クリックメニューから設定ファイル編集・リロード・終了が可能
- FR-10: Dockにアプリアイコンを表示しない

## Non-Goals
- Webページからのスクレイピング・自動同期
- キーバインドのアプリ内GUI編集
- ライトテーマ対応
- 検索/フィルター機能
- macOS以外のプラットフォーム対応
- Login Items（ログイン時自動起動）の設定UI（手動でシステム設定から追加可能）

## Technical Considerations
- **最小対応OS**: macOS 14.0 (Sonoma) 以上（MenuBarExtra API活用）
- **フレームワーク**: SwiftUI + AppKit（NSPanel for popup挙動制御が必要な場合）
- **グローバルショートカット**: Accessibility権限が必要な場合あり。`CGEvent`タップまたは`NSEvent.addGlobalMonitorForEvents`を検討
- **JSON構造例**:
```json
{
  "sections": [
    {
      "name": "Move Cursor",
      "keybinds": [
        { "action": "Cursor Right", "key": "^ F" },
        { "action": "Cursor Left", "key": "^ B" }
      ]
    }
  ]
}
```
- **ポップアップ制御**: `NSPanel`のfloating/non-activatingを使用して他アプリのフォーカスを奪わない設計

## Success Metrics
- メニューバーアイコンクリックから0.2秒以内にポップアップ表示
- 全キーバインド（約90項目）が1画面にスクロールなしで表示される
- JSONファイル編集→リロードで即座にUI反映
- グローバルショートカットが他アプリ使用中でも確実に動作

## Open Questions
- グローバルショートカットのデフォルトキーは ⌘⇧K で良いか？
- ポップアップの正確な固定サイズは開発中にデザイン調整で決定するか？
- macOS 13 (Ventura) サポートは必要か？