<div align="center">

<img src="docs/app-icon.png" width="120" alt="Antunes" />

# Antunes

随心而听的第三方网易云音乐客户端 · Android / iOS

</div>

## 简介

Antunes 是一个第三方网易云音乐客户端，一套源码同时产出 Android 与 iOS 两端。
界面沿用 iOS 端的玻璃质感设计语言，Android 端用 WebView + 原生播放服务复刻同一套布局与交互：
同一份 `app.js` / `app.css` 驱动界面，原生侧只负责音频播放、缓存、下载与系统集成。

本项目基于 [missuo/kumone](https://github.com/missuo/kumone) 的 iOS 客户端改造而来，
Android 端移植、双端界面统一与后续维护由 [Anyu](https://github.com/Anyu1014) 完成。

## 功能

- **双端一致**：推荐、精选、搜索、我的、漫游五大板块，Android 与 iOS 布局与文案对齐。
- **漫游**：按口味持续推荐，队列自动补歌不重复。
- **歌词**：逐字跟随擦亮，播放页与横屏漫游共用同一份渲染；横屏时左封面右歌词，当前行贴在屏幕竖直中线。
- **横屏**：列表与详情页全部左右分区，两栏各自滚动、互不干扰；顶部为自建的渐进模糊，不遮挡内容。
- **玻璃质感**：可选原生磨砂、清透、关闭三档；底栏展开/收缩与切换板块均为可抢占的独立动画。
- **离线**：下载、缓存、本地歌词、睡眠定时、音质与音效设置。
- **登录**：手机号 / 邮箱 / Cookie 登录，歌单、收藏、听歌排行同步。

## 下载

| 平台 | 文件 | 说明 |
| --- | --- | --- |
| Android | `Antunes-1.6.apk` | Android 10（API 29）及以上 |
| iOS | `Antunes-1.6.ipa` | iOS 17 及以上，需自签名安装 |

安装包见本仓库的 [Releases](https://github.com/Anyu1014/Antunes/releases) 页面。

## 构建

依赖：Xcode 26+、JDK 21、Android SDK 36、Node 22+。

```sh
# iOS
./Scripts/package.sh ios

# Android
./Scripts/package.sh android

# 双端
./Scripts/package.sh all
```

产物落在 `build/latest/`，历史版本自动归档到 `build/history/`。

## 致谢

- **[missuo](https://github.com/missuo)** —— [kumone](https://github.com/missuo/kumone) 作者。本项目的 iOS 端、界面设计与绝大部分业务逻辑来自他的工作；没有 kumone 就没有 Antunes。
- **kumone 的贡献者与 MOE AI LLC** —— 上游协议实现、歌词与播放内核。
- **node-qrcode**（Ryan Day、Soldair、Enrico La Monica）—— 二维码渲染，MIT License。

## 许可证

沿用上游协议，本项目以 **LGPL-3.0-only** 发布，详见 [LICENSE](LICENSE) 与 [COPYING](COPYING)。
本项目与网易云音乐官方无关，仅为个人学习与自用。
