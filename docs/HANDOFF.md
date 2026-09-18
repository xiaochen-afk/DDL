# DDL 生存指南项目交接文档

> 交接文档版本：1.8  
> 当前阶段：首次启动空状态与生存天数持久化完成，等待 SQLite 和系统通知 Adapter 接入  
> 最后更新：2026-09-18

## 1. 项目一句话说明

面向大学生的本地优先 DDL 管理应用，采用 Flutter + Dart 同时覆盖 Android 与 iOS，Android 重点适配 OPPO ColorOS 与 vivo OriginOS；通过未来三天危机仪表盘、动态四象限、系统通知、逾期忏悔录和轻量游戏化文案，帮助用户把截止时间压力转化为明确行动。HarmonyOS 为远期独立评估项，允许重写。

## 2. 当前完成情况

已完成：

- 读取 Stitch 项目 `DDL 生存指南`，Project ID 为 `7421687790638940156`。
- 盘点五个核心移动端页面及项目内技术简报。
- 输出产品需求文档 `docs/PRD.md`。
- 输出技术方案 `docs/TECHNICAL_SOLUTION.md`。
- 输出技术栈对比与决策 `docs/TECH_STACK_DECISION.md`。
- 建立项目级协作规则 `.cursor/rules/project-collaboration.mdc`。
- 初始化 Flutter Android/iOS 工程，应用包名为 `com.ddl.ddl_survival`。
- 完成首页、待办、创建任务、忏悔录、个人中心和任务详情界面。
- 使用内存 Repository 完成创建、完成、逾期处理、归档、删除和筛选交互闭环。
- 建立 `TaskRepository`、`NotificationPort`、`FilePort`、`ClockPort` 平台接口。
- 输出应用内部接口文档 `docs/API_CONTRACTS.md`。
- 补充状态单元测试和核心 Widget 交互测试。
- 默认任务数据改为空，不再向真实用户展示演示任务。
- 使用 `shared_preferences` 持久化首次启动日期，生存天数从第 1 天按自然日累计。

尚未开始：

- 尚未接入 SQLite，当前任务数据由内存 Repository 提供，重启后会重置；首次启动日期已单独持久化。
- 尚未接入 Android/iOS 本地系统通知，通知中心当前仅为前端交互原型。
- 尚未实现 JSON 导入导出和本地文件权限流程。
- 尚未加入生产字体与品牌图标资源。
- 尚未进行 OPPO、vivo 与 iPhone 真机验证。
- 未进行部署。
- 未使用 Git，也未创建任何 Git 提交。

## 3. 已确认的产品方向

- 当前目标平台：Android 与 iOS，使用 Flutter + Dart 共用主代码；正式工程初始化前必须通过双端技术 Spike。
- HarmonyOS 暂不适配；未来真正立项时允许使用 ArkTS + ArkUI 重写或重新选择方案。
- 核心导航：主页、待办、忏悔录、我的。
- 核心闭环：创建任务 → 动态排序与四象限 → 完成或到期 → 忏悔录处理 → 统计反馈。
- 用户决定任务重要度，系统根据截止时间、预计耗时与负载决定紧急度。
- MVP 使用确定性、可解释的规则算法；AI 能力放到后续阶段。
- 弱网与短时离线必须可查看、创建和完成任务。
- DDL 提醒全部采用 Android/iOS 本地通知，不依赖服务端、厂商远程推送或 APNs 远程推送。
- 任务、设置、统计和历史全部保存在本机 SQLite；当前没有账号、云数据库或跨设备同步。
- 锁屏与横幅受系统权限、Android 通知渠道、iOS 展示设置、勿扰模式和用户选择控制，不承诺强制置顶。
- 品牌文案应紧迫但不羞辱用户，并提供中性或温和模式。

## 4. 推荐技术栈摘要

应用层：

- Flutter、Dart、Material 3、自有 Widget 与 Stitch 设计令牌。
- `go_router`、`flutter_riverpod`、Flutter `Form`、`intl`。
- `sqflite` + `path` / SQLite，通过 Repository 管理事务、迁移和查询。
- `flutter_local_notifications` + `timezone`，并通过 Kotlin/Swift Platform Channel 补齐系统差异。
- `flutter_test`、`integration_test`、Android UI Automator、XCUITest 和双端真机测试。

选型状态：

- Flutter 是 Android/iOS 当前正式技术方向，具体 SDK 与插件版本等待 Spike 后锁定。
- Vue 3 + Capacitor 不作为主选，因为当前没有必须复用的 Vue 生产代码。
- ArkUI-X 不再采用，因为 HarmonyOS 已从近期范围移除。

当前不包含：

- 业务后端、云数据库和 Redis。
- 登录、账号和跨设备同步。
- OPPO PUSH、vivo Push、FCM 等远程推送。
- 云端 AI 服务。

选型比较与回退条件见 `docs/TECH_STACK_DECISION.md`；数据模型、接口和部署策略见 `docs/TECHNICAL_SOLUTION.md`。

## 5. Stitch 设计来源

项目设计系统：

- 主色：`#FF6B35`。
- 高危色建议：`#EE4266`。
- 成功色建议：`#06D6A0`。
- 背景色：`#F8F9FA`。
- 标题字体：Plus Jakarta Sans。
- 正文字体：Be Vietnam Pro。
- 标准圆角：8px。
- 设计基准宽度：390px。

核心页面：

- 首页：`projects/7421687790638940156/screens/7684dcdabe7e459b80d779419cce8582`
- 四象限待办：`projects/7421687790638940156/screens/db8c258325e8453a91d30b390612ab19`
- 创建任务：`projects/7421687790638940156/screens/613aa8e7139e4e6ab33a2ec5eb95a3b8`
- 忏悔录：`projects/7421687790638940156/screens/f5ba0563dfbd43ea9426e6ae109d42c7`
- 个人中心：`projects/7421687790638940156/screens/1038d9b27bc443f59aad63086da86153`

Stitch 项目还包含项目简报、核心技术难点、工程实施路径和架构示意，可在继续设计或编码前按需重新读取。

## 6. 下一位开发者的建议起步顺序

1. 与产品负责人确认 PRD 第 15 节的待确认事项和当前前端文案。
2. 引入 `sqflite` 与 `path`，实现数据库 v1 Schema、迁移和 `TaskRepository`。
3. 为 Repository 补充 CRUD、事务、升级和异常恢复测试，然后替换内存实现。
4. 引入 `flutter_local_notifications` 与 `timezone`，实现通知权限、渠道、滚动排程和取消逻辑。
5. 通过现有 `NotificationPort` 分别补齐 Android 与 iOS Adapter，必要时增加 Kotlin/Swift 桥接。
6. 实现 `FilePort`、版本化 JSON 导出导入与清除数据确认。
7. 补齐品牌字体、图标、启动画面、无障碍语义和小屏适配。
8. 在 OPPO、vivo 真机验证锁屏、息屏、重启、低电量、权限撤销与后台限制。
9. 在 iPhone 真机验证通知授权、前台/后台/锁屏展示、排程窗口、时区变化和应用升级。
10. 每完成一个阶段更新本交接文档。

## 7. 开工前必须确认

- SQLite 是否启用 SQLCipher，以及密钥保存和恢复策略。
- OPPO、vivo 首批支持的具体机型、Android 版本、ColorOS 与 OriginOS 版本。
- APK 内测、OPPO 软件商店、vivo 应用商店或其他分发渠道的优先级。
- 是否要求提醒精确到分钟；若需要，确认特殊权限申请和应用商店审核策略。
- 默认紧急阈值、预计耗时和缓冲时间。
- 通知渠道与免打扰默认值。
- 危机文案的默认强度及审核责任人。
- 本地数据导出格式、文件保存位置和恢复流程。
- iOS 最低系统版本、首批 iPhone 测试机、Apple 开发者账号和上架时间。
- 是否具备 macOS、Xcode 与 iPhone 真机环境。
- Flutter Spike 是否全部通过，以及需要 Kotlin/Swift 补齐的 API 和维护成本。
- HarmonyOS 暂不设适配日期，未来立项时重新确认技术方案。

## 8. 已知风险

- OPPO、vivo 的后台管理和通知设置存在系统版本差异，必须使用真机测试，不能只依赖模拟器。
- Android 13 及以上通知权限可能被拒绝；Android 14 及以上精确提醒权限通常不会默认授予。
- iOS 通知权限可能被拒绝，且待处理本地通知数量有限，必须采用滚动排程窗口。
- 顶部横幅和锁屏内容由系统通知渠道及用户设置决定，应用无法强制覆盖。
- 卸载应用或清除应用数据会删除 SQLite 数据，必须提供导出能力和清晰提示。
- 设备时间不可信；时间被手动修改会影响逾期判断和提醒，需要监听变化并重新协调。
- 四象限自动漂移可能让用户困惑，必须展示原因并提供算法说明。
- 过强文案可能放大焦虑，需要强度设置和合规审查。
- SQLite Schema 升级失败可能阻断启动，必须建立版本迁移、事务回滚和真实旧版本升级测试。
- 若启用 SQLCipher 但密钥管理不可靠，用户可能永久失去数据。
- 本地数据导出文件离开应用私有目录后，需要明确提醒用户妥善保管。
- Flutter 插件不能消除 OPPO/vivo 与 iOS 的系统规则差异，通知、文件和生命周期能力必须真机验证并保留原生 Adapter 边界。
- iOS 构建、签名和上架依赖 macOS、Xcode、Apple 开发者账号和 Provisioning Profile。

## 9. 交接更新规范

每次完成有意义的开发工作后，在结束前更新本文件，至少记录：

- 本次目标与实际完成范围。
- 新增、修改和删除的文件。
- 关键设计或技术决策及原因。
- 执行过的测试、检查命令和结果。
- 未完成事项、已知缺陷和复现方式。
- 环境变量、数据迁移、依赖或部署变化。
- 下一步建议和可能的阻塞项。

不得只写“已完成”而不提供验证信息。交接文档应保证不依赖聊天记录也能继续工作。

## 10. Git 与版本控制约定

本项目当前约定：未经用户明确允许，不使用 Git 进行版本控制。

具体含义：

- 不执行任何 `git` 命令，包括只读命令。
- 不初始化 Git 仓库。
- 不创建或切换分支。
- 不提交、合并、变基、打标签或推送。
- 不修改 `.git` 内容。
- 不假设“开发任务”自动包含 Git 授权。

只有用户在当前任务中明确授权后，才能进行授权范围内的 Git 操作。授权一次不自动扩展到未来任务。

## 11. 本次交接记录

以下内容按时间顺序保留历史决策；如有冲突，以日期更晚的记录及当前文档顶部摘要为准。

### 2026-09-17：需求与技术方案阶段

完成内容：

- 基于 Stitch 项目提取五个核心页面的结构、字段和文案。
- 明确 Vue + Capacitor Android、Local-first、规则风险引擎和分阶段 AI 的方案。
- 新建 PRD、技术方案、交接文档和协作规则。

验证方式：

- 已核对 Stitch 项目标题、设备类型、设计主题和核心页面列表。
- 已读取 Stitch 项目简报、技术难点和工程实施路径。
- 已检查文档是否覆盖产品范围、技术栈、数据模型、接口、测试、部署、交接和 Git 约束。

未完成：

- 尚未由产品负责人确认 PRD 中的开放问题。
- 尚未进行工程 Spike 或编码验证。

### 2026-09-17：Android 通知范围调整

新增决策：

- 当前版本只实现 Android，首批重点设备为 OPPO 与 vivo；iOS 与 HarmonyOS 留待后续版本。
- 正式交付从纯 PWA 调整为 Vue 3 + Capacitor Android 安装包。
- 本地通知承担全部 DDL 定时提醒；当前不接入远程推送。
- PRD 和技术方案已补充通知权限、精确提醒、通知渠道、开机恢复、厂商 SDK 与真机验证要求。

仍待验证：

- 目标机型上的锁屏、顶部横幅、低电量与后台限制行为。
- SQLite 插件、Capacitor 主版本与目标 Android SDK 的兼容性。

### 2026-09-17：改为 SQLite 纯本地数据方案

新增决策：

- 任务、分类、设置、统计和历史事件统一保存在本机 SQLite。
- 移除 PostgreSQL、Redis、NestJS、账号体系、云同步和远程推送方案。
- 使用 Repository 隔离 `@capacitor-community/sqlite`，数据库迁移必须有自动化测试。
- 本地通知直接读取 SQLite 任务排程，不依赖网络。
- 增加 JSON 导出、导入、清除确认和卸载数据丢失提示要求。

仍待验证：

- SQLite 插件与最终锁定的 Capacitor 版本兼容性。
- 是否启用 SQLCipher，以及密钥恢复方案。
- OPPO、vivo 真机上的 SQLite 升级与本地通知恢复。

### 2026-09-17：明确未来 iOS 与 HarmonyOS 规划

纠正范围：

- Android 是当前首发范围，不是永久唯一平台。
- 后续需要适配 iOS 与 HarmonyOS，但当前阶段不创建对应工程。
- iOS 优先复用 Capacitor、Vue 和 TypeScript 领域层。
- HarmonyOS 在适配阶段评估 ArkWeb 复用 Vue 与 ArkTS / ArkUI 原生实现，不能假设 Capacitor Android 插件直接兼容。
- 当前新增平台无关的 Repository、Notification、File、Clock 接口约束。
- 跨平台数据迁移统一通过带版本号的 JSON 协议，不直接复制 SQLite 文件或平台通知 ID。

### 2026-09-17：重新评估跨平台技术栈

本次目标：

- 以代码复用率、Android/HarmonyOS/iOS 覆盖、系统级能力、生态成熟度和长期维护成本重新比较 Vue + Capacitor、Flutter、ArkUI-X 与三端原生方案。

新增决策：

- 主推荐调整为 ArkUI-X + ArkTS，从 Android 首版开始建立可复用的页面、领域逻辑和平台接口。
- Flutter 不作为主栈：其官方支持平台列表未包含 HarmonyOS，社区适配不能消除引擎、插件和升级风险。
- Vue 3 + Capacitor 从原主方案调整为回退方案；如回退，Android/iOS 使用 Capacitor，HarmonyOS 使用 ArkTS + ArkUI。
- ArkUI-X 必须先完成 3 至 5 个工作日技术 Spike，验证 Android 构建、OPPO/vivo 真机 UI、SQLite、通知、精确提醒桥接、重启恢复、JSON 导入导出和最小 HarmonyOS 复用。

变更文件：

- 新增 `docs/TECH_STACK_DECISION.md`。
- 更新 `docs/PRD.md`、`docs/TECHNICAL_SOLUTION.md`、`docs/HANDOFF.md` 和 `.cursor/rules/project-collaboration.mdc`。

验证结果：

- 已核对 Flutter 官方支持平台与 Platform Channel 文档。
- 已核对 Capacitor 官方 Android/iOS 与原生插件边界。
- 已核对 ArkUI-X 项目声明的 OpenHarmony、HarmonyOS、Android、iOS 支持范围，以及关系型数据库、通知、文件和平台桥接 API 清单。
- 尚未运行 ArkUI-X 工程和真机测试；技术选择仍以 Spike 通过为锁定条件。

环境与版本控制：

- 未初始化工程、未安装依赖、未改变运行环境。
- 未执行任何 Git 命令。

### 2026-09-17：当前范围收敛为 Android 与 iOS

范围调整：

- 当前只要求适配 Android 与 iOS，二者进入当前产品和技术范围。
- HarmonyOS 推迟到远期，真正立项时允许重写或重新选择跨端方案。
- 当前工程不再为 HarmonyOS 兼容承担额外框架、插件或构建约束。

技术决策：

- 主技术栈从 ArkUI-X + ArkTS 调整为 Flutter + Dart。
- 本机数据采用 `sqflite` / SQLite；通知采用 `flutter_local_notifications` + `timezone`。
- Android/iOS 系统差异通过 `NotificationPort` 等接口隔离，必要时使用 Kotlin/Swift Platform Channel。
- iOS 纳入当前测试、通知、数据迁移、签名和发布方案。

变更文件：

- 更新 `docs/TECH_STACK_DECISION.md` 至 1.1。
- 更新 `docs/PRD.md`、`docs/TECHNICAL_SOLUTION.md`、`docs/HANDOFF.md` 和 `.cursor/rules/project-collaboration.mdc`。

验证与未验证项：

- 已核对 Flutter 官方 Android/iOS 支持范围、Platform Channel 和 SQLite 实践。
- 已核对 `flutter_local_notifications` 的 Android/iOS 支持、Android 精确提醒/重启配置和 iOS 待处理通知限制。
- 尚未运行 Flutter 工程、安装插件或执行 Android/iOS 真机测试。
- 未执行任何 Git 命令。

### 2026-09-18：Flutter 前端与接口契约阶段

本次目标：

- 开始正式开发，优先完成移动端前端页面、核心交互闭环和接口文档。

实际完成：

- 使用 Flutter 3.38.9、Dart 3.10.8 初始化 Android/iOS 工程，Android Application ID 为 `com.ddl.ddl_survival`。
- 建立“校园应急指挥台 / 纸质紧急通告”视觉系统，统一颜色、排版、卡片、状态章、背景网格和压力仪表盘。
- 完成首页、待办四象限、创建任务、忏悔录、个人中心和任务详情六类界面。
- 完成底部导航、筛选、创建、完成、逾期确认、归档、删除、偏好开关和底部弹层等交互。
- 用 `InMemoryTaskRepository` 提供样例数据和完整状态流，当前无需数据库即可演示核心体验。
- 定义 `TaskRepository`、`NotificationPort`、`FilePort`、`ClockPort`，避免后续页面直接依赖插件。
- 新建 `docs/API_CONTRACTS.md`，说明领域模型、状态迁移、异步约定、错误语义、通知能力和 JSON 交换格式。
- 更新 Android/iOS 应用显示名称、README 与本交接文档。

主要文件：

- 应用入口与导航：`lib/main.dart`、`lib/src/app.dart`。
- 领域和端口：`lib/src/domain/task.dart`、`lib/src/domain/ports.dart`。
- 状态与临时数据：`lib/src/state/app_controller.dart`、`lib/src/data/in_memory_task_repository.dart`。
- 页面：`lib/src/screens/`。
- 设计系统与共享组件：`lib/src/theme/app_theme.dart`、`lib/src/widgets/common.dart`。
- 测试：`test/app_controller_test.dart`、`test/widget_test.dart`。

验证结果：

- `dart format lib test`：通过。
- `flutter analyze`：通过，`No issues found`。
- `flutter test`：通过，共 3 项测试；覆盖任务状态生命周期、导航与创建任务、逾期任务处理。
- `flutter build apk --debug`：代码编译前的 Android SDK 准备已完成，但 Google Maven 下载 `androidx.core:core-ktx:1.13.1` 时 TLS 握手被远端中断；自动重试长时间无响应后停止。本次未生成 APK，属于依赖网络阻断，尚无项目代码编译错误证据。
- iOS 未构建；当前 Windows 环境不具备 Xcode 构建条件。

环境变化：

- Flutter 官方测试依赖已写入 `pubspec.lock`；生产依赖仍只有 Flutter SDK。
- Android SDK 首次构建自动安装了 NDK 28.2.13676358、Build-Tools 35.0.0 和 Platform 36 revision 2。
- 未新增环境变量、数据库或远程服务配置。
- 因本机没有 Android 真机或模拟器，已补充 `web/` 开发预览入口；可用 `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 51876` 在本地预览同一套 Flutter 前端。Web 仅用于开发展示，不改变 Android/iOS 正式目标范围。

未完成与下一步：

- 网络恢复后重跑 `flutter build apk --debug`，完成 Android 实际打包验证。
- 接入 `sqflite` / `path` 并用 SQLite Repository 替换内存实现。
- 接入 `flutter_local_notifications` / `timezone`，再进行 OPPO、vivo 与 iPhone 真机验证。
- 实现 JSON 导入导出、品牌资源、无障碍和不同屏幕尺寸回归。

版本控制：

- 本次未执行任何 Git 命令，也未创建提交、分支或远程操作。

### 2026-09-18：vivo Android 15 真机调试

设备与环境：

- 设备型号：vivo `V2362A`。
- 系统：Android 15 / API 35，ARM64。
- 设备分辨率：1080 × 2400，Flutter 逻辑宽度约 360dp。
- USB ADB 已授权，设备序列号仅用于本次本地调试。

执行结果：

- `flutter run -d <device>` 成功完成 Debug 构建。
- APK 已生成：`build/app/outputs/flutter-apk/app-debug.apk`。
- APK 已通过 USB 安装并启动，包名为 `com.ddl.ddl_survival`。
- Activity Manager 确认 `com.ddl.ddl_survival/.MainActivity` 处于 `RESUMED`、可见且全屏状态。
- Flutter 使用 Impeller Vulkan 渲染后端，启动日志未发现 Flutter 页面异常。
- 已抓取真机截图 `build/device-preview.png`；首页中文字体、压力卡片、任务卡片、底部导航和浮动按钮显示正常，未见明显溢出或黑屏。

开发预览：

- Web 本地预览仍可使用 `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 51876` 启动。
- Android 真机调试优先使用 USB 设备，后续接入系统通知时必须继续在该设备验证权限、锁屏横幅和后台限制。

版本控制：

- 本次未执行任何 Git 命令。

### 2026-09-18：首次启动数据清理与生存天数修正

本次目标：

- 新用户首次使用从“生存第 1 天”开始，之后按自然日累计。
- 删除所有默认任务案例，首次进入呈现真实空状态。
- 本轮仅验证 Web 本地预览，不进行真机部署。

实际完成：

- 删除 `InMemoryTaskRepository` 中 6 条预置任务，任务 ID 从 1 开始生成。
- 新增 `InstallationStore`，通过 `SharedPreferencesInstallationStore` 持久保存首次启动日期。
- `AppController.survivalDays` 按本地自然日计算，首日为 1，并对异常未来日期下限保护为 1。
- 空任务时压力分、击败 DDL 数和趣味统计均从 0 开始。
- Widget 测试不依赖生产演示数据；逾期流程测试在测试内部显式创建临时任务。
- 更新接口文档至 1.1，补充首次启动日期接口与实现映射。

依赖变化：

- 新增 `shared_preferences`，实际解析版本为 2.5.5，用于 Android、iOS、Web 的轻量首次启动日期持久化。

验证结果：

- `flutter analyze`：通过，`No issues found`。
- `flutter test`：通过，共 4 项测试。
- Web 预览：`http://127.0.0.1:51876` 已启动并确认显示“生存第 1 天”“0 个未完成”“今天没有警报”。
- 本轮按用户要求未执行真机安装或调试；此前真机调试会话已停止。

版本控制：

- 本次未执行任何 Git 命令。
