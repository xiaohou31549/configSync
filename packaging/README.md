# 打包说明

仓库当前提供两条路径：

- 本机测试包：适合你自己机器上快速构建一个已签名 `.app/.dmg`
- 正式分发包：适合发给其他人下载，走 `Developer ID + 公证 + DMG`

## 1. 生成 Xcode 工程

```bash
cd /Users/tough/Work/SecretSync
scripts/generate_xcodeproj.sh
```

## 2. 本机测试安装包

生成一个适合本机测试的已签名 `.app` 和 `.dmg`：

```bash
TEAM_ID=你的TeamID scripts/package_dmg.sh
```

可选参数：

```bash
TEAM_ID=你的TeamID BUNDLE_ID=com.your.bundleid CONFIGURATION=Release scripts/package_dmg.sh
```

输出位置：

- `dist/SecretSync.dmg`
- `build/DerivedData/Build/Products/Release/SecretSync.app`

## 3. 归档

```bash
TEAM_ID=你的TeamID scripts/archive_release.sh
```

输出位置：

- `build/SecretSync.xcarchive`

默认会用 `Developer ID Application` 身份归档。若你只是本机调试，也可以显式覆盖：

```bash
TEAM_ID=你的TeamID SIGNING_IDENTITY="Apple Development" scripts/archive_release.sh
```

## 4. Developer ID 导出

归档后可在 Xcode Organizer 中导出，或使用：

```bash
xcodebuild -exportArchive \
  -archivePath build/SecretSync.xcarchive \
  -exportPath dist/export \
  -exportOptionsPlist packaging/ExportOptions-DeveloperID.plist
```

## 5. 一键生成可分发安装包

正式对外分发建议直接使用：

```bash
TEAM_ID=你的TeamID \
NOTARY_KEYCHAIN_PROFILE=你已保存的notarytool凭据名 \
scripts/release_notarized_dmg.sh
```

如果你还没提前保存 `notarytool` 凭据，也可以临时传入 Apple ID 与 app 专用密码：

```bash
TEAM_ID=你的TeamID \
APPLE_ID=你的AppleID邮箱 \
APP_SPECIFIC_PASSWORD=你的app专用密码 \
scripts/release_notarized_dmg.sh
```

脚本会执行：

1. `archive`
2. `Developer ID` 导出
3. 生成 `DMG`
4. `notarytool submit`
5. `stapler staple`
6. `stapler validate` 与 `spctl` 校验

输出位置：

- `build/SecretSync.xcarchive`
- `dist/export/SecretSync.app`
- `dist/SecretSync.dmg`

常用可选参数：

```bash
TEAM_ID=你的TeamID \
BUNDLE_ID=com.your.bundleid \
DMG_NAME=SecretSync-0.1.0 \
NOTARY_KEYCHAIN_PROFILE=你的profile \
scripts/release_notarized_dmg.sh
```

只想先检查流程拼接是否正确，不真正构建/公证：

```bash
DRY_RUN=1 \
TEAM_ID=你的TeamID \
APPLE_ID=你的AppleID邮箱 \
APP_SPECIFIC_PASSWORD=假的占位密码也可以 \
scripts/release_notarized_dmg.sh
```

如需先跳过公证，生成一个未公证的候选包：

```bash
TEAM_ID=你的TeamID SKIP_NOTARIZATION=1 scripts/release_notarized_dmg.sh
```

## 6. 校验脚本

```bash
scripts/validate_packaging.sh
```

该脚本会做两件事：

- 对发布相关脚本执行 `zsh -n` 语法校验
- 用 `DRY_RUN=1` 验证正式发布链路包含 `archive/export/dmg/notary/staple/spctl`

Apple 的文档说明，macOS 面向站外分发时应选择 `Developer ID` 分发方式，并在站外分发前完成公证：
- [Distribution methods](https://help.apple.com/xcode/mac/current/en.lproj/dev31de635e5.html)
- [Distribute outside the Mac App Store (macOS)](https://help.apple.com/xcode/mac/current/en.lproj/dev033e997ca.html)
- [Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
