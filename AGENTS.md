# 项目约定（Antunes 二改）

本文件是本仓库的硬性约定，与 `~/.dsh/AGENTS.md` 并列生效；冲突时以本文件为准。

## 音质锁定：极高（2026-11-19 用户指令）

**播放与下载的音质一律锁定为极高（`exhigh`），设置里不再提供任何档位选择。**

- `Sources/Kumone/Core/Storage/SettingsManager.swift`：init 里 `audioQuality = .exhigh`、
  `downloadQuality = .exhigh`，并把 `settings.quality` / `settings.downloadQuality` 写回 `exhigh`
  （旧键保留只为兼容历史数据，值不再被读取）。
- 取流点固定为常量：`PlayerServiceIOS.swift` 与 `PlayerService.swift` 里
  `let quality = AudioQuality.exhigh.rawValue`，不得改回读偏好。
- `SyncedPreferences` 忽略其它设备推来的档位；`SettingsView` 的「播放音质/下载音质」Picker
  已删除，只留一行只读的「音质 · 极高」。
- 安卓：`app.js` 设置页同样只留只读行；`MainActivity` 的 `quality`/`downloadQuality` 操作无视入参、
  只写 `exhigh`；`MusicApi.audioURL` 与 `PlaybackService` 固定传 `exhigh`。
- 实测事实（防止以后又凭猜改）：`/song/enhance/player/url/v1` 对同一首歌各档位返回的 `time` 一致
  （213529ms）、无 `freeTrialInfo`；`hires` 实际回落到 `lossless`（同为 flac、862786bps）。
- 要解除锁定必须先拿到「非极高文件为何音画不同步」的实证，并在真机逐档验收。

## `.cache/`：项目私有、随时可删（2026-11-22 用户指令）

所有「删掉不坏项目、也不拖慢构建」的产物**一律写项目根的 `.cache/`**，不要再丢 `/tmp`：

- `shots/`：验证截图、裁剪后的证据图、录屏；
- `scratch/`：一次性脚本（CDP 探测、正则替换草稿）、日志重定向产物；
- `package-ios-XXXXXX/`：`Scripts/package.sh ios` 的 `Payload` 暂存，脚本结束即删。

清理：`./Scripts/package.sh clean`（清空 `.cache/`、保留 `README.md`），或直接 `rm -rf .cache/*`。
**不要**把源码、`build/latest` 的交付物、以及会拖慢构建的中间物（`ios/DerivedData`、`.build`、
`android/build`、`android/.gradle`）放进 `.cache/`。

## 回归处理

用户报「又坏了 / 不对了」时，先回退到最近一次用户验收正确的状态并装机验证，
再谈原因；一次只动一个变量。已验收的参照实现见 `~/.dsh/AGENTS.md` 的回归章节。

## 发布分支：源码 + 安装包一起进同版本名分支（2026-11-23 用户指令）

「上传仓库」= 在上游仓库**新建**与该版本同名的新分支，里面同时有源码和安装包：

- 分支名 = 版本号（如 `1.7`），同时打同名 tag 指向同一提交。
- 安装包放仓库内 `dist/`，文件名带版本号：`dist/Antunes-<版本>.apk`、`dist/Antunes-<版本>.ipa`。
  本次没有安装包时忽略此项，并在提交信息里写明「无安装包」。
- `Scripts/package.sh` 打完包后会自动把 `build/latest/` 里的本版安装包同步到 `dist/`（`sync_dist`），
  但**不自动提交**；需要上传时再建分支提交。
- GitHub Release 的附件与 `dist/` 保持一致（1.7 起照此执行）。
