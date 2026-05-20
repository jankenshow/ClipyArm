# ARM Mac Build Plan

## Goal

Clipy を自分の Apple Silicon Mac でローカル利用できるように、`arm64` ネイティブでビルド、起動、基本動作確認できる状態にする。ARM only 成果物を公開配布することは想定しない。公開配布向けの Universal 2、Developer ID 署名、notarization、Sparkle appcast 更新は今回の主目的から外す。

## Current Findings

- 作業ブランチ: `arm-mac-build`
- Xcode プロジェクト内に `ARCHS = x86_64`、`VALID_ARCHS`、`EXCLUDED_ARCHS = arm64` のような明示的な Intel 固定は見つからない。
- Project の Debug 設定のみ `ONLY_ACTIVE_ARCH = YES` がある。Release 設定には明示されていないため、Release/archive の成果物アーキテクチャは実際の archive コマンドと destination に依存する。
- `fastlane/Fastfile` の `release` lane は TODO のままで、archive、export、署名、notarization、成果物検証が未実装。
- CI は `bundle exec fastlane test` のみを実行している。ただし `fastlane/Fastfile` の `scan_clipy` は `skip_build: true` のため、ARM build の保証にはならない。
- Swift Package 依存に `realm-swift` `10.7.2` が exact pin されている。これは古く、Apple Silicon ネイティブビルドや Xcode 26 系との相性で最初に疑うべき依存。
- Realm の SwiftPM requirement は `Clipy.xcodeproj/project.pbxproj` 側に `kind = exactVersion`、`version = 10.7.2` として定義されている。依存更新時は `Package.resolved` だけでなく `project.pbxproj` 側の requirement も更新が必要。
- Sparkle 2 系を使っているが、今回は公開配布しないため appcast、署名、ダウンロード URL、更新配信条件の変更は不要。一方で、ローカル Release `.app` が本番 appcast から公開 Intel 版へ自動更新されるリスクは別途対策する。

## Implementation Notes

- ローカル ARM build 用の `LOCAL_ARM_BUILD` compile flag を追加し、この flag が付いた build では Sparkle updater を生成しない。
- `LOCAL_ARM_BUILD` 時は `Constants.Update.enableAutomaticCheck` のデフォルトを `false` にし、既存の通常 build では従来どおり `true` を維持する。
- Updates preference は `updaterController == nil` を明示的に扱い、最終更新日時表示をローカル build 用の disabled 表示にし、Check For Updates ボタンを無効化する。
- 個人利用向けに `fastlane build_local` を追加し、`ARCHS=arm64`、`ONLY_ACTIVE_ARCH=YES`、`OTHER_SWIFT_FLAGS='$(inherited) -D LOCAL_ARM_BUILD'` を指定して Release build する。
- `fastlane build_local` は build 後に `.app` 内の Mach-O を走査し、`arm64` slice を含まないバイナリがあれば失敗する。
- SwiftLint build tool plugin は Apple Silicon ローカル build 中に SourceKit の読み込みエラーで build を止めるため、Xcode project の package plugin dependency から外した。lint は必要に応じて standalone の `swiftlint lint` として実行する。
- shared scheme では `ClipyTests` を running build 対象から外した。Release build で tests が同時に compile され、`@testable import Clipy` が `-enable-testing` 不在で失敗するため。testing/analyzing 対象としては維持する。
- Realm など runtime package の更新は今回不要だった。ARM Release/Debug build は現行 pin のまま成功している。

## Implementation Plan

1. Baseline build の確認

   - 現在の `develop` 相当の設定で `arm64` build が通るか確認する。
   - Debug と Release/archive を分けて確認し、失敗箇所が Xcode 設定、Swift Package、コード、署名のどれかを切り分ける。
   - 署名や配布パッケージではなく、未署名またはローカル署名の build 成功を優先する。

   Candidate commands:

   ```sh
   xcodebuild \
     -project Clipy.xcodeproj \
     -scheme Clipy \
     -configuration Debug \
     -destination 'platform=macOS,arch=arm64' \
     -skipPackagePluginValidation \
     ARCHS=arm64 \
     build

   xcodebuild \
     -project Clipy.xcodeproj \
     -scheme Clipy \
     -configuration Release \
     -destination 'generic/platform=macOS' \
     -archivePath build/Clipy-arm64.xcarchive \
     -skipPackagePluginValidation \
     ARCHS=arm64 \
     archive
   ```

   Sparkle 無効化用の compile flag を実装した後は、ローカル利用する build に `OTHER_SWIFT_FLAGS='$(inherited) -D LOCAL_ARM_BUILD'` も追加する。

2. Xcode build settings の明示化

   - Debug のローカル実行は Apple Silicon Mac 上なら `ONLY_ACTIVE_ARCH = YES` のままでも問題ない。
   - Release/archive を使う場合は、ローカル利用なら `ARCHS=arm64` をコマンド側で指定すればよい。
   - プロジェクト全体を ARM 専用に固定しない。将来 Intel/Universal 2 配布に戻す可能性を残す。
   - 明示的な Intel 固定が追加されないことを維持する。

3. Swift Package 依存の ARM 対応

   - `realm-swift` `10.7.2` と `realm-core` `10.5.5` を最優先で検証する。
   - ARM build で Realm 関連の compile/link エラーが出た場合は、現在の Xcode と macOS deployment target に対応する Realm Swift へ更新する。
   - Realm 更新時は Xcode の Package Dependencies UI、または同等の project file 変更で `Clipy.xcodeproj/project.pbxproj` の `XCRemoteSwiftPackageReference "realm-swift"` requirement を更新する。
   - `Clipy.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` は、上記 requirement に合わせて解決結果として更新する。
   - Realm を更新する場合は、DB migration への影響を `Clipy/Sources/Extensions/Realm+Migration.swift` と model 群で確認する。
   - `pincache`、`PINOperation`、`SwiftHEXColors` など古い Objective-C/Swift package も、ARM build で link エラーが出た場合に順次更新または置き換えを検討する。

4. Sparkle auto update 対策

   - Release build を `/Applications` に置いて使う場合、Sparkle が本番 `SUFeedURL` から公開 x86_64-only 版を提示または適用し、ローカル ARM build を上書きする可能性がある。
   - 推奨対策は、ローカル ARM build 用の compile flag または build setting を追加し、Sparkle updater を起動しないようにすること。
   - 最小実装案:
     - `LOCAL_ARM_BUILD` のような Swift flag をローカル build 時だけ付ける。
     - `CPYUtilities.registerUserDefaultKeys()` で `Constants.Update.enableAutomaticCheck` のデフォルトをローカル build 時だけ `false` にする。
     - `AppDelegate.applicationDidFinishLaunching` でローカル build 時は `SPUStandardUpdaterController` を生成しない。
     - `CPYUpdatesPreferenceViewController` で `updaterController == nil` のローカル build 状態を明示的に扱い、Updates 画面と Check For Updates 操作がクラッシュせず意図どおり無効化されるようにする。
     - Updates 画面では Check For Updates ボタンを disabled にするか、押してもネットワーク更新確認を開始しない no-op として扱う。最終更新日時も updater 不在時に不正な値を表示しない。
   - ローカル build 用 flag は既存の Debug/Release 設定へ固定で入れず、ローカル専用 scheme、手元の `xcodebuild` 引数、または個人用 fastlane lane で渡す。
   - コード変更を避ける一時運用にする場合は、初回起動後にアプリの更新設定で自動チェックを無効化する。ただし誤操作や初回起動前のリスクが残るため、恒久対応としては compile flag で無効化する。

5. Local install flow の整理

   - Xcode から直接 Run できることを最優先にする。
   - 必要であれば `xcodebuild` で Release build し、生成された `Clipy.app` を手元の `/Applications` へコピーして使う手順を README または計画に残す。
   - Developer ID 署名、notarization、dmg/zip 作成、Sparkle appcast 更新は対象外にする。
   - ローカル成果物の確認として、main executable だけでなく `.app` 内の Mach-O バイナリ全体が `arm64` を含むことを確認する。

   Candidate architecture check:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   APP=build/Clipy-arm64.xcarchive/Products/Applications/Clipy.app
   if [ ! -d "$APP" ]; then
     echo "error: app bundle not found: $APP" >&2
     exit 1
   fi

   checked=0
   missing=0

   while IFS= read -r -d '' file; do
     description=$(file "$file")
     case "$description" in
       *Mach-O*)
         checked=$((checked + 1))
         archs=$(lipo -archs "$file")
         echo "$file: $archs"
         case " $archs " in
           *" arm64 "*) ;;
           *)
             echo "error: missing arm64 slice: $file ($archs)" >&2
             missing=1
             ;;
         esac
         ;;
     esac
   done < <(find "$APP" -type f -print0)

   if [ "$checked" -eq 0 ]; then
     echo "error: no Mach-O binaries found under $APP" >&2
     exit 1
   fi

   if [ "$missing" -ne 0 ]; then
     exit 1
   fi
   ```

   将来 fastlane lane に組み込む場合も、`arm64` を含まない Mach-O が見つかったら non-zero exit にして失敗させる。

6. CI の扱い

   - 個人利用が目的なら CI 追加は必須ではない。
   - 変更の回帰を抑えたい場合だけ、既存 test job に ARM build check を追加する。
   - cross-compile の確認だけなら `xcodebuild ... -destination 'platform=macOS,arch=arm64' build` を使う。
   - ARM 実機での runtime test は手元の Mac で行う。
   - `bundle exec fastlane test` は回帰確認としては有用だが、現状は `skip_build: true` なので ARM build の合格条件にはしない。
   - sandbox では Xcode の package/build metadata 書き込みで失敗する可能性があるため、最終確認は full Xcode が選択された手元環境で行う。

7. Runtime QA on Apple Silicon

   - Apple Silicon Mac で `Clipy.app` を起動し、Activity Monitor または `file` で Rosetta ではなく ARM ネイティブで動いていることを確認する。
   - Pasteboard 監視、menu bar 表示、hotkey、snippets editor、accessibility permission、login item を重点確認する。
   - ローカル build では Sparkle の自動更新チェックが開始されず、公開版への更新通知が出ないことを確認する。
   - Updates preference を開き、最終更新日時表示と Check For Updates ボタンがローカル build の updater 無効化状態と矛盾しないことを確認する。
   - 公開配布をしないため、Intel Mac や Universal 2 成果物の検証は今回の範囲外にする。

## Required Code/Config Changes

- `Clipy.xcodeproj/project.pbxproj`
  - 明示的な Intel 固定がない状態を維持する。
  - 必要が出た場合のみ、Release build を `arm64` で安定させる最小限の build setting を追加する。
  - Realm 更新が必要になった場合は、`XCRemoteSwiftPackageReference "realm-swift"` の requirement も更新する。
- `Clipy.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  - ARM build で詰まる依存があれば、`project.pbxproj` の requirement 更新後に解決結果として更新する。最初の候補は `realm-swift`。
- `Clipy/Sources/Utility/CPYUtilities.swift`
  - ローカル ARM build 用 flag を使う場合、`Constants.Update.enableAutomaticCheck` のデフォルトを `false` にする。
- `Clipy/Sources/AppDelegate.swift`
  - ローカル ARM build 用 flag を使う場合、`SPUStandardUpdaterController` を生成しない分岐を追加する。
- `Clipy/Sources/Preferences/Panels/CPYUpdatesPreferenceViewController.swift`
  - ローカル ARM build で `updaterController == nil` でも Updates 画面がクラッシュしないことを維持する。
  - Check For Updates ボタンや最終更新日時表示を no-op または disabled state として明示的に扱う。
- `fastlane/Fastfile`
  - 今回は release lane 実装を必須にしない。
  - 必要なら個人利用向けに `build_local` のような lane を追加し、`ARCHS=arm64`、`LOCAL_ARM_BUILD`、architecture check だけを行う。
- `.github/workflows/CI.yml`
  - 今回は必須変更なし。
  - 必要なら ARM build check のみ追加する。
- `README.md` または release docs
  - 必要ならローカル ARM build 手順を追記する。

## Verification Checklist

- `xcodebuild` の Debug `arm64` build が成功する。
- 必要に応じて `xcodebuild` の Release `arm64` build が成功する。
- `.app` 内の main executable と runtime load 対象の framework/Mach-O バイナリに `arm64` が含まれる。
- architecture check は `arm64` を含まない Mach-O を検出したら non-zero exit で失敗する。
- ローカル Release build では Sparkle 自動更新が無効化され、公開 x86_64-only 版へ戻らない。
- ローカル Release build で Updates preference を開いてもクラッシュせず、Check For Updates 操作が意図どおり無効化される。
- `bundle exec fastlane test` は回帰確認として必要に応じて実行する。ただし ARM build の保証には使わない。
- Apple Silicon Mac で Rosetta なしに起動し、主要機能が動作する。

## Open Decisions

- ローカル利用は Xcode Run で足りるか、Release build した `.app` を `/Applications` に置く運用にするか。
- 依存更新が必要になった場合、Realm をどのバージョンまで上げるか。
- Sparkle 無効化を compile flag で行うか、ローカル用 bundle identifier/appcast 無効化で行うか。
- CI に ARM build check を追加するか、手元検証だけで済ませるか。
