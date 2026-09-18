# DDL 生存指南

一个面向大学生的本地优先 DDL 管理应用。当前使用 Flutter + Dart 构建 Android 与 iOS 共用界面，采用“校园应急指挥台”的视觉语言，把临近截止时间转化为清晰、可执行的任务队列。

## 当前能力

- 首页压力仪表盘、三日雷区与通知中心。
- 动态四象限待办、时间筛选、任务详情和完成操作。
- 创建任务表单、快速截止时间、重要度、分类、预计耗时与备注。
- 忏悔录逾期处理流程。
- 个人统计、通知偏好、文案语气和数据工具入口。
- 内存 Repository 驱动的完整交互闭环，便于先验证体验。
- Repository、Notification、File、Clock 平台接口，为 SQLite 和系统通知接入预留边界。
- 首次启动日期本地持久化，“生存天数”从第 1 天按自然日累计。

当前任务数据会在应用重启后重置，但首次启动日期会保留；SQLite、本地系统通知和文件导入导出将在下一阶段接入。

## 运行与验证

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

Android 可在 Windows 上构建。iOS 构建、签名与真机验证需要 macOS、Xcode 和 Apple 开发者配置。

## 文档

- 产品需求：`docs/PRD.md`
- 技术方案：`docs/TECHNICAL_SOLUTION.md`
- 技术选型：`docs/TECH_STACK_DECISION.md`
- 应用内部接口：`docs/API_CONTRACTS.md`
- 开发交接：`docs/HANDOFF.md`

## 协作约定

未经用户明确允许，不执行任何 Git 命令，也不进行提交、分支或推送操作。
