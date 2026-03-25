# 打包说明

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

## 4. Developer ID 导出

归档后可在 Xcode Organizer 中导出，或使用：

```bash
xcodebuild -exportArchive \
  -archivePath build/SecretSync.xcarchive \
  -exportPath dist/export \
  -exportOptionsPlist packaging/ExportOptions-DeveloperID.plist
```

Apple 的文档说明，macOS 面向站外分发时应选择 `Developer ID` 分发方式：
- [Distribution methods](https://help.apple.com/xcode/mac/current/en.lproj/dev31de635e5.html)
- [Distribute outside the Mac App Store (macOS)](https://help.apple.com/xcode/mac/current/en.lproj/dev033e997ca.html)
