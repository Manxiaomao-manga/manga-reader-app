# 漫小猫 Android App

<p align="center">
  <img src="https://manga.come100.com/assets/pwa-icon-src.png" width="120" alt="漫小猫"/>
</p>

<p align="center">
  <strong>漫小猫 — 免费韩漫 / 日漫阅读平台</strong><br/>
  官方 Android 客户端 · WebView 封装
</p>

<p align="center">
  <a href="https://manga.come100.com">🌐 官方网站</a> ·
  <a href="https://github.com/Manxiaomao-manga/manga-reader-app/releases/download/v1/MangaXiaomao.apk">📥 下载 APK</a>
</p>

---

## 📖 关于漫小猫

[漫小猫](https://manga.come100.com) 是一个免费的韩漫 / 日漫在线阅读平台，提供大量正版授权漫画，支持 VIP 会员与阅读券系统。

- 海量韩漫 · 日漫 · BL 内容持续更新
- 每日签到领取阅读券
- VIP 会员无限阅读
- 支持章节离线下载（PWA / App 均可）
- 实时客服支持

## 📱 App 功能

| 功能 | 说明 |
|------|------|
| WebView 内核 | 完整网站体验，支持所有功能 |
| 离线章节下载 | 通过 Service Worker 缓存章节图片 |
| 下拉刷新 | SwipeRefreshLayout 支持 |
| 返回键导航 | 在页内历史记录内后退 |
| 文件上传 | 支持头像上传等文件选择 |
| 沉浸阅读 | 全屏阅读体验 |
| 深色主题 | 跟随网站深色风格 |

## ⬇️ 下载安装

### 直接下载 APK

点击下方按钮下载最新版本：

**[📥 下载 MangaXiaomao.apk](https://github.com/Manxiaomao-manga/manga-reader-app/releases/download/v1/MangaXiaomao.apk)**

> 安装前请在手机设置中开启「允许安装未知来源应用」

### 安装步骤

1. 点击上方链接下载 APK 文件
2. 打开下载的 `MangaXiaomao.apk`
3. 系统提示时选择「仍要安装」
4. 安装完成后在桌面找到「漫小猫」图标

### 或者使用 PWA（免安装）

直接用手机浏览器访问 [manga.come100.com](https://manga.come100.com)，点击浏览器菜单「添加到主屏幕」即可获得类 App 体验。

## 🔧 技术栈

- **语言**：Java
- **最低 Android 版本**：Android 5.0（API 21）
- **目标 Android 版本**：Android 14（API 34）
- **核心组件**：
  - `WebView`（启用 JS / DOM Storage / 数据库）
  - `SwipeRefreshLayout`（下拉刷新）
  - `ActivityResultLauncher`（文件选择器）
  - `WebChromeClient`（进度条 / 权限处理）
- **CI/CD**：GitHub Actions 自动构建 APK 并发布 Release

## 🏗️ 构建说明

```bash
# 克隆仓库
git clone https://github.com/Manxiaomao-manga/manga-reader-app.git
cd manga-reader-app

# 构建 Debug APK
./gradlew :app:assembleDebug

# APK 输出路径
app/build/outputs/apk/debug/app-debug.apk
```

**环境要求**
- JDK 17+
- Android SDK（compileSdk 34）
- Gradle 8.6

## 🔄 自动发布

每次推送到 `main` 分支，GitHub Actions 会自动：

1. 构建 Debug APK
2. 更新 `v1` Release 中的 `MangaXiaomao.apk`

下载链接始终固定为：
```
https://github.com/Manxiaomao-manga/manga-reader-app/releases/download/v1/MangaXiaomao.apk
```

## 🌐 相关链接

- 官方网站：[manga.come100.com](https://manga.come100.com)
- APK 下载：[最新版本](https://github.com/Manxiaomao-manga/manga-reader-app/releases/latest)
- 问题反馈：请在官网联系客服

---

## 📄 版权声明

Copyright © 2026 [漫小猫](https://manga.come100.com) · All Rights Reserved.

本项目为漫小猫原创作品，受版权法保护。未经授权，禁止复制、修改或用于任何商业用途。详见 [LICENSE](./LICENSE) 文件。

---

<p align="center">
  © 2026 漫小猫 · <a href="https://manga.come100.com">manga.come100.com</a>
</p>
