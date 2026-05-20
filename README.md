<div align="center">
  <img src="./Resources/clipy_logo.png" width="400">
</div>

<br>

![CI](https://github.com/Clipy/Clipy/workflows/CI/badge.svg)
[![Release version](https://img.shields.io/github/release/Clipy/Clipy.svg)](https://github.com/Clipy/Clipy/releases/latest)
[![OpenCollective](https://opencollective.com/clipy/backers/badge.svg)](#backers)
[![OpenCollective](https://opencollective.com/clipy/sponsors/badge.svg)](#sponsors)

Clipy is a Clipboard extension app for macOS.

This repository is a fork of the original [Clipy/Clipy](https://github.com/Clipy/Clipy) project. This fork is maintained for local self-build use on Apple Silicon Macs. It is not intended to publish an official ARM-only distribution, notarized package, or Sparkle appcast.

---

__Requirement__: macOS 13 Ventura or later

__Distribution Site__ : <https://clipy-app.com>

<img src="http://clipy-app.com/img/screenshot1.png" width="400">

### Development Environment
* macOS 26 Tahoe
* Xcode 26.2

### How to Build
For normal development:

1. Open `Clipy.xcodeproj` in Xcode.
2. Select the `Clipy` scheme and a macOS destination.
3. Build or run from Xcode.

For a local Apple Silicon app that can be installed manually, use the local build lane:

```sh
bundle install
bundle exec fastlane build_local
```

The `build_local` lane builds a Release app for `arm64`, passes `-D LOCAL_ARM_BUILD`, and verifies that Mach-O binaries inside the app bundle include an `arm64` slice. The `LOCAL_ARM_BUILD` flag disables Sparkle automatic updates so a self-built app is not replaced by the official public release.

If Bundler is not available with the version required by `Gemfile.lock`, the equivalent direct build command is:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Clipy.xcodeproj \
  -scheme Clipy \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/local-arm64/DerivedData \
  -skipPackagePluginValidation \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  OTHER_SWIFT_FLAGS='$(inherited) -D LOCAL_ARM_BUILD' \
  build
```

### Local Apple Silicon Install
After `build_local` succeeds, the app is created at:

```text
build/local-arm64/DerivedData/Build/Products/Release/Clipy.app
```

To install it for local use:

1. Quit any running Clipy app.
2. Copy the built app to `/Applications`.

```sh
ditto build/local-arm64/DerivedData/Build/Products/Release/Clipy.app /Applications/Clipy.app
```

You can verify the installed app is native Apple Silicon with:

```sh
file /Applications/Clipy.app/Contents/MacOS/Clipy
```

The output should include `arm64`.

### Localization Contributors
Clipy is looking for localization contributors.  
If you can contribute, please see [CONTRIBUTING.md](https://github.com/Clipy/Clipy/blob/master/.github/CONTRIBUTING.md)

### Distribution
If you distribute derived work, especially in the Mac App Store, I ask you to follow two rules:

1. Don't use `Clipy` and `ClipMenu` as your product name.
2. Follow the MIT license terms.

Thank you for your cooperation.

### Backers

Support us with a monthly donation and help us continue our activities. [[Become a backer](https://opencollective.com/clipy#backer)]

<a href="https://opencollective.com/clipy#backers"><img src="https://opencollective.com/clipy/backers.svg?avatarHeight=36&width=600" /></a>

### Sponsors

Become a sponsor and get your logo on our README on Github with a link to your site. [[Become a sponsor](https://opencollective.com/clipy#sponsor)]

<a href="https://opencollective.com/clipy#sponsors"><img src="https://opencollective.com/clipy/sponsors.svg?avatarHeight=36&width=600" /></a>

### Licence
Clipy is available under the MIT license. See the LICENSE file for more info.

Icons are copyrighted by their respective authors.

### Special Thanks
__Thank you for [@naotaka](https://github.com/naotaka) who have published [ClipMenu](https://github.com/naotaka/ClipMenu) as OSS.__
