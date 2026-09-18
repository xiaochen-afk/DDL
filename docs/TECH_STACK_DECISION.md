# DDL 生存指南技术栈选型决策

> 决策版本：1.1  
> 决策日期：2026-09-17  
> 决策状态：采用 Flutter + Dart，开工前完成 Android/iOS 技术 Spike  
> 当前目标平台：Android、iOS  
> 远期平台：HarmonyOS，届时允许重写或重新选型

## 1. 决策结论

本项目采用 **Flutter + Dart** 作为 Android 与 iOS 的主应用技术栈，用一套 UI、领域逻辑和数据访问代码交付两端应用。

系统能力不直接散落在页面中。通知、本地数据库、文件导出、系统时间和生命周期统一通过 `NotificationPort`、`TaskRepository`、`FilePort`、`ClockPort` 等接口访问。优先使用成熟 Flutter 插件；插件不能覆盖的 Android/iOS 差异，分别通过 Kotlin、Swift 和 Flutter Platform Channel 补齐。

HarmonyOS 不再影响当前技术栈。未来确有鸿蒙用户和商业目标时，再根据当时生态选择 Flutter/OpenHarmony 适配、ArkTS + ArkUI 重写或其他方案。当前只保留产品规则、设计令牌、数据 Schema、JSON 导入导出协议和测试向量等可迁移资产，不为鸿蒙提前增加工程复杂度。

## 2. 为什么现在选择 Flutter

### 2.1 Android 与 iOS 是 Flutter 的正式目标平台

Flutter 官方支持 Android 与 iOS。对当前双端范围，一套 Dart/Flutter 主代码可以复用页面、交互、状态机、风险算法、SQLite Repository 和大部分通知编排逻辑。

### 2.2 系统级能力不是阻断项

Flutter 可以通过插件和 Platform Channel 调用 Kotlin、Swift 原生代码。本项目关心的通知权限、Android 通知渠道、锁屏可见性、精确闹钟、开机恢复、iOS UserNotifications、文件选择和系统设置跳转，都可以放在平台 Adapter 内实现。

“使用 Flutter”不代表通知一定强制置顶。Android 顶部横幅、锁屏内容和声音仍由通知渠道、系统版本、勿扰模式、OPPO/vivo 后台策略以及用户设置决定；iOS 同样受系统通知授权和展示设置控制。

### 2.3 SQLite 有清晰的双端路径

Flutter 官方 SQLite 示例使用 `sqflite`，其目标平台包含 Android 与 iOS。本项目在其上增加 Repository、事务、索引、连续版本迁移和 JSON 导入导出，不使用云数据库。

### 2.4 当前没有需要保留的生产级 Vue 代码

Stitch 提供的是设计和页面参考，不是已经上线的 Vue 业务工程。此时改用 Flutter 的重写成本主要是 UI 复现，而不是迁移已有生产系统，因此更适合优先换取 Android/iOS 的长期一致性。

## 3. 其他方案为何不作为主选

### 3.1 Vue 3 + Capacitor

优势：

- 最容易映射 Stitch 的 HTML/CSS 结构，Web 前端开发速度快。
- Capacitor 官方支持 Android 与 iOS，也能通过插件访问原生 SDK。
- 对表单、列表和本地 CRUD 应用，性能通常足够。

不作为主选的原因：

- 关键页面运行在 WebView 中，UI 适配、键盘、安全区和复杂滚动更依赖 Web 与原生容器协作。
- 系统能力仍需维护 Capacitor 插件或原生插件，和 Flutter 相比并没有消除原生适配工作。
- 当前没有必须复用的 Vue 生产代码，Vue 的最大迁移优势并不存在。

如果团队成员只熟悉 Vue、交付时间远高于长期移动端维护质量，可以重新启用该方案，但需要记录为新的技术决策。

### 3.2 ArkUI-X + ArkTS

它适合把 HarmonyOS 作为近期硬目标的项目。现在鸿蒙已经推迟，继续采用 ArkUI-X 会让 Android/iOS 首版承担较小生态、第三方组件和调试资料不足的成本，收益与当前范围不匹配，因此不再采用。

### 3.3 Kotlin + Swift 双原生

系统集成最强，但需要维护两套页面和大量重复业务代码。当前应用以表单、任务列表、风险计算和本地通知为主，没有足够理由承担双原生成本。

## 4. 推荐技术栈

### 4.1 应用与界面

- Flutter、Dart。
- Material 3 作为可访问性和交互基础，自建 Widget 与 Design Tokens 复现 Stitch 品牌视觉。
- `go_router`：页面导航、通知点击深链和路由守卫。
- `flutter_riverpod`：依赖注入、页面状态和异步查询状态；不保存永久业务数据。
- Flutter `Form` 与自有 Validator：任务输入和导入文件校验。
- `intl`：中文日期和本地化格式；时间计算统一封装，不散落在 Widget 中。

### 4.2 数据与离线

- `sqflite` + `path`：Android/iOS 本机 SQLite。
- Repository：隔离 SQL、事务、迁移和行对象转换。
- 连续整数 Schema 版本与显式升级脚本。
- 版本化 JSON：手动导出、导入与未来跨平台迁移。
- 无账号、无云数据库、无后台同步。

### 4.3 本地通知

- `flutter_local_notifications`：Android/iOS 本地通知、排程、取消、点击事件和权限入口。
- `timezone`：按设备时区生成排程时间，处理跨日和夏令时。
- Android：NotificationChannel、AlarmManager、`POST_NOTIFICATIONS`、精确提醒权限、重启恢复和厂商设置引导。
- iOS：UserNotifications 授权、前台展示策略、锁屏隐私与待处理通知数量控制。
- Kotlin/Swift Platform Channel：只补齐插件无法可靠覆盖的能力，不把原生 API 暴露给页面层。

### 4.4 测试与质量

- `flutter_test`：Widget、状态机、风险算法和校验逻辑。
- `integration_test`：创建任务、状态流转、数据恢复和通知点击入口。
- SQLite 集成测试：事务回滚、约束、迁移和损坏导入。
- Android UI Automator / `adb`：OPPO、vivo 锁屏、息屏、重启、Doze 和权限场景。
- iOS XCTest / XCUITest 与真机测试：通知授权、锁屏展示、时间变化和应用升级。
- `flutter analyze`、Dart formatter：静态检查和格式化。

## 5. 开工前技术 Spike

建议用 3 至 5 个工作日完成一个纵向切片：

1. 使用同一 Flutter 工程构建 Android 与 iOS；iOS 构建必须在 macOS、Xcode 环境完成。
2. 按 390px 设计基准复现首页卡片、底部导航和创建任务表单，验证安全区、键盘、滚动和字体。
3. 使用 `sqflite` 完成任务 CRUD、事务回滚、索引查询、数据库升级和 1000 条任务性能验证。
4. 使用 `flutter_local_notifications` 完成 Android/iOS 通知排程、取消、点击跳转和权限拒绝降级。
5. Android 真机验证锁屏、横幅、精确提醒、重启恢复和 OPPO/vivo 后台限制。
6. iOS 真机验证锁屏、前台通知、时区变化，并实现“只排程最近一批提醒”的窗口策略，避免超过系统待处理通知限制。
7. 完成 JSON 导出、校验、覆盖导入和损坏文件拒绝。
8. 记录所有需要 Kotlin/Swift 补齐的能力、插件版本、最低系统版本和已知限制。

Spike 未通过时优先更换单个插件或自研平台 Adapter；只有 Flutter 构建链、渲染或核心系统能力出现不可控阻断时，才重新比较 Vue + Capacitor 与双原生方案。

## 6. HarmonyOS 远期策略

- 当前不创建 HarmonyOS 工程，不要求现有 Flutter 插件兼容鸿蒙。
- 当前代码不为假想中的鸿蒙兼容牺牲 Android/iOS 质量或开发效率。
- 必须保持可迁移的资产：PRD、设计令牌、领域规则、风险算法说明、SQLite 逻辑 Schema、版本化 JSON、通知文案和测试向量。
- 真正启动鸿蒙版本时重新评估当时的 Flutter 生态、ArkTS/ArkUI 和其他跨端框架。
- 允许用 ArkTS + ArkUI 重写 UI 与平台层；通过相同 JSON 协议迁移数据，通过同一测试向量验证业务规则。

## 7. 决策边界

- Flutter 为 Android/iOS 当前正式技术方向，但具体 SDK 与插件版本在 Spike 通过后锁定。
- 未经用户明确允许，不执行任何 Git 命令。
- 改变技术栈、SQLite 方案或当前目标平台前，必须同步更新 PRD、技术方案和交接文档。

## 8. 官方与一手参考

- [Flutter 官方支持平台](https://docs.flutter.dev/reference/supported-platforms)
- [Flutter 平台通道](https://docs.flutter.dev/platform-integration/platform-channels)
- [Flutter SQLite 实践](https://docs.flutter.dev/cookbook/persistence/sqlite)
- [Flutter iOS 开发环境](https://docs.flutter.dev/platform-integration/ios/setup)
- [flutter_local_notifications 包说明](https://pub.dev/packages/flutter_local_notifications)
- [Capacitor 官方文档](https://capacitorjs.com/docs)
- [ArkUI-X 项目概览](https://github.com/arkui-x/docs/blob/master/zh-cn/ArkUI-X-Overview-zh.md)
