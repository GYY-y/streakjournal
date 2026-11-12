# 坚持记录（StreakJournal）

个人每日记录与坚持周期管理的 macOS 原生应用。

- **技术栈**：纯 Swift + SwiftUI，零第三方依赖，本地 SQLite（系统库）
- **平台**：仅 Apple Silicon（M 系列），macOS 14+
- **分发**：GitHub Releases 提供 DMG，不上架 App Store
- **数据**：完全本地保存，无需账号、无需网络、无广告无付费

## 功能（对应 PRD V1.0）

| 页面 | 功能 |
|---|---|
| 首页 | 当前坚持天数、开始日期、历史最长、鼓励语（按天数分档）、今日状态、开启新周期 / 补录破戒 |
| 每日记录 | 心态（单选）、情绪（多选）、状态、变化感知、自由记录、行为情况（三态独立字段）；自动保存 |
| 历史记录 | 月历视图（周期开始 / 坚持中 / 破戒 / 有记录四类标记）、时间线视图、按周期 / 破戒 / 有记录筛选 |
| 统计 | 基础统计、周度汇总、月度汇总（周期起止、破戒次数、最长周期） |
| 设置 | 目标天数、主题（浅色 / 深色 / 跟随系统）、日期格式、周期与破戒记录管理、导出 / 导入 JSON、自动 / 手动备份与恢复 |

## 核心规则（PRD 4.3）

- 每次坚持是一条独立周期；开启新周期**不删除任何历史**
- 破戒日独立保存，不属于任何周期、不计入坚持天数（周期 1 结束于破戒日前一天，新周期从次日或用户指定日开始）
- 补录破戒会自动调整对应周期并重新计算
- 删除每日记录不影响周期数据
- 未填写记录的日期不会被认定为"坚持成功"

## 数据位置与备份

- 数据库：`~/Library/Application Support/StreakJournal/streakjournal.db`
- 自动备份：启动时距上次备份超过 24 小时则自动备份，保留最近 10 份
- 手动备份：菜单 File → 手动备份（⌘⇧B）或设置页
- 导出 / 导入：设置页，JSON 格式，恢复前有覆盖确认

## 本地开发构建

```bash
./scripts/build_app.sh     # 编译 + 图标 + 组装 .app + ad-hoc 签名
./scripts/make_dmg.sh      # 制作 DMG（拖拽安装布局）
open build/StreakJournal.app
```

> 说明：本脚本优先使用 SwiftPM 构建；若本机 Command Line Tools 的
> PackageDescription 库损坏（manifest 链接失败），会自动回退到
> `swiftc` 直编并使用影子资源目录修复 CLT 的重复 module map 问题。

## 发布流程

1. `git tag v1.0.0 && git push origin v1.0.0`
2. GitHub Actions（macos-14 Apple Silicon runner）自动构建并产出 DMG
3. DMG 自动附加到对应 Release（含自动 Release Notes）

如需避免 "应用已损坏" 提示：正式分发建议用 Developer ID 签名与公证；
未签名版本用户需执行 `xattr -cr /Applications/StreakJournal.app`。

## 目录结构

```
Sources/StreakJournal/
  App/       应用入口
  Core/      数据模型、SQLite、业务逻辑（Store）、日期工具、鼓励语
  Views/     首页 / 记录 / 历史 / 统计 / 设置 / 组件
scripts/     构建与打包脚本
tools/       图标生成器
.github/     Release 工作流
```
