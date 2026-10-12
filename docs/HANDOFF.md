# DDL 生存指南项目交接文档

> 交接文档版本：1.32
> 当前阶段：短截止任务级提醒与 SQLite v4 已接入；当前源码的 Release APK 已覆盖安装到 vivo，功能仍待真机验收
> 最后更新：2026-10-12

## 2026-10-12 vivo 安装记录

- 用户要求只打包当前最新源码并装机，不运行测试。`flutter build apk --release --no-pub` 成功，产物为 `build/app/outputs/flutter-apk/app-release.apk`（54.7 MB）；项目版本仍为 `1.0.0+1`，现有 Release 配置使用 Debug 签名。
- vivo V2362A（ADB 序列号 `10AE6R1GD0000RZ`）执行 `adb install --no-streaming -r`，返回 `Success`；覆盖安装保留应用数据。
- 本次未运行自动化或真机功能测试，也未启动应用、调试或读取日志。构建中 Kotlin 增量缓存曾输出跨磁盘路径异常，但 Gradle 最终退出码为 0 且生成 APK；后续正式发布仍需独立发布签名与功能验收。未执行 Git 命令。

## 2026-10-06 vivo 安装记录

- 按用户要求仅安装当前代码：`flutter build apk --debug --no-pub` 成功，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- vivo V2362A（ADB 序列号 `10AE6R1GD0000RZ`）执行 `adb install --no-streaming -r -t`，返回 `Success`；`-r` 覆盖安装并保留应用数据。
- 本次未启动应用、调试会话或真机功能测试；SQLite v4 升级运行结果与提醒送达仍待后续验收。

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
- 完成 SQLite v1 Schema、连接生命周期、任务 Repository、事务事件、乐观锁和稳定错误映射。
- 完成 SQLite v2 迁移，将任务标题/备注上限统一为 80/1000；已有任务、事件与提醒记录可随旧库升级保留。
- 完成任务闭环第一轮：启动、恢复前台和前台到点自动协调逾期；SQLite 原子写入 `TASK_OVERDUE`；到期后的普通完成转入忏悔录，并支持两种结案和统计刷新。
- 完成任务核心补齐：进行中任务可编辑全部用户字段；五因素可解释风险分接通列表、排序、详情与 SQLite 快照；有操作/结案历史的任务删除请求改为归档，仅新建未改任务可物理删除。
- 2026-10-04 在 vivo V2362A Android 15 保留数据原位安装新 APK，验证任务编辑、逾期双分支结案和冷启动持久化；测试任务的最终历史清理状态见当日交接。
- 完成 SQLite 设置、个人资料和提醒记录 Repository：偏好与资料单例默认值/编辑持久化，提醒记录事务替换、状态转换、取消与失败记录；生产入口接入设置/资料，个人中心可编辑并持久保存。提醒记录已在 10 月 5 日接入系统通知 Adapter。
- 完成共享 Dart 提醒计划与协调：按分钟目标、默认提前量、长任务缓冲及投影极高风险生成记录；免打扰顺延、同分钟去重、终态取消、增量幂等与失败状态保留；创建/编辑/结案/偏好变更、启动和恢复前台均会协调 SQLite 期望计划。
- 接入 `FlutterNotificationPort`：Android/iOS 本地通知排程、权限检查与用户主动申请、精确权限缺失时非精确降级、平台待处理通知对账、通知点按进入任务详情、设备 IANA 时区同步；Android 配置通知渠道与重启/升级恢复接收器。自动化测试和 Android Debug APK 构建已通过；vivo V2362A 已完成权限、后台精确送达及点按对照测试，结果受其后台耗电模式影响。
- Android/iOS 生产入口已切换为 SQLite；Web 开发预览保留内存 Repository。
- SQLite 版本已在 vivo V2362A Android 15 真机完成安装、创建、强制结束、重启读取和测试数据清理验证。
- 2026-10-05 按用户提供的黄色角色图更新应用图标，已生成 Android 各密度/自适应图标与 iOS AppIcon，并在 vivo 应用信息页确认全身可见。
- 新建/编辑任务页的分类新增“自定义”，选中后输入最多 12 个字符的单任务标签；删除“今天 23:00”“明天 18:00”“三天后”三个截止时间快捷示例，仍保留日期和时间选择器。
- SQLite 升至 v3：`tasks` 预留可空字段 `custom_category_label TEXT`，`categories` 增加 `custom` 稳定外键占位；v2→v3 保留旧任务且新字段默认为 `NULL`。本轮没有建立可复用标签库或分类管理后端。
- “默认提前提醒”设置已移除逗号文本输入，最新 UI 为小时/分钟双列轮选，保存单个分钟数；旧的“提醒一/提醒二”描述仅为历史记录。
- 短截止任务可在创建/编辑时设置本任务提醒提前量，留空则保存 5 分钟；SQLite v4 可空字段持久化后覆盖本任务的全局默认提醒，其他任务和全局偏好不变。

尚未完成或待验收：

- 首页的“通知中心”仍仅展示逾期任务，不是系统通知收件箱；系统本地排程由独立 Adapter 负责。SQLite 的 `PENDING` 仍不代表平台已排程或送达，`SCHEDULED` 仅代表排程调用成功或平台待处理 ID 存在。
- vivo V2362A 的“智能控制后台耗电”下，精确闹钟退后台后被系统记录为 `frozen`，目标分钟未送达；临时改为“允许后台高耗电”后，精确闹钟保留、01:43 通知送达且点按打开对应任务。测试后已恢复原来的智能控制，因此当前手机默认设置下仍不能承诺后台准点提醒。OPPO/iPhone、锁屏、重启、时间/时区后台变更仍未真机验收；后台时间/时区广播即时恢复尚未实现。
- 尚未实现 JSON 导入导出和本地文件权限流程。
- 自定义分类当前是每个任务上的文本标签，尚不支持标签复用、管理、颜色或单独统计。
- 短截止任务提醒已编码并通过自动化测试，尚未在真机验证实际通知送达；若截止前 5 分钟或自选触发点已过去，页面会提示且不会补发。
- 尚未加入生产字体；品牌图标已接入。
- 尚未进行 OPPO 与 iPhone 真机验证；vivo Android 15 已完成前端、SQLite 持久化及平台通知两种后台耗电模式的对照验证。
- 2026-10-04 任务核心和设置/资料 APK 已在 vivo 保留数据安装并回归；本轮收尾时 ADB 未发现在线设备，最后一次历史归档点击未能复核。
- 未进行部署。
- Git 已启用；前端与早期 SQLite 基线已有提交。2026-10-05 用户明确要求将当前后端、测试、文档与新图标进度纳入本地 Git 版本控制；仓库无远端，本轮不推送。

## 3. 已确认的产品方向

- 当前目标平台：Android 与 iOS，使用 Flutter + Dart 共用主代码；正式工程初始化前必须通过双端技术 Spike。
- HarmonyOS 暂不适配；未来真正立项时允许使用 ArkTS + ArkUI 重写或重新选择方案。
- 核心导航：主页、待办、忏悔录、我的。
- 核心闭环：创建任务 → 动态排序与四象限 → 完成或到期 → 忏悔录处理 → 统计反馈。
- 用户决定任务重要度，系统根据截止时间、预计耗时与负载决定紧急度。
- MVP 使用确定性、可解释的规则算法；AI 能力放到后续阶段。
- 弱网与短时离线必须可查看、创建和完成任务。
- DDL 提醒全部采用 Android/iOS 本地通知，不依赖服务端、厂商远程推送或 APNs 远程推送。
- 已确认所有 DDL 定时提醒以指定分钟为目标；实际送达受系统权限与省电等策略影响，非精确降级时必须明确告知；Adapter 已编码，仍待真机送达验收。
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

## 6. 后续后端开发建议顺序

按批次交付、测试和评审；已完成第 1—3 批，后续批次仍按审批节奏推进。具体验收点见 2026-10-03 每日交接。

1. 已完成：P0 任务核心补齐及 vivo 逾期闭环回归；接通任务编辑、可解释风险规则与有历史记录任务的归档/删除策略。
2. 已完成：P0 本地数据层，包括 `PreferenceRepository`、`ProfileRepository`、`ReminderRepository` 的 SQLite 持久化、默认值、事务与测试；设置页面读写真实数据。提醒 Repository 尚未承担系统排程。
3. 已完成：P0 提醒计划，根据任务与偏好生成分钟级目标时间，处理免打扰、重复去重、状态变更取消、失败状态保留及启动/恢复协调；当前仅同步 SQLite 期望记录。
4. P0 平台通知：Android/iOS Adapter、授权与降级提示、通知点击、Android 重启恢复、前台时间/时区变更修复的代码及自动化测试已完成；vivo 已验证通知授权、精确权限、后台送达和点按，但智能控制模式失败、允许后台高耗电模式成功。仍需确定可接受的 vivo 设置引导/降级策略，并完成锁屏、重启、OPPO/iPhone 与后台时间/时区变更验收；不得标记整项通过。
5. P0 数据安全：提供完整 JSON 导出和二次确认的本机数据清除。P1 再实现版本化导入、覆盖恢复和归档历史。
6. 发布前可靠性：完成迁移、离线、时间回拨、权限撤销、通知送达、性能和本地诊断回归；iOS 构建和真机验证依赖 macOS/Xcode 环境。

品牌字体、启动画面和无障碍等界面工作另按产品验收推进。每轮结束同步本交接文档和当天文件。

## 7. 开工前必须确认

- SQLite 是否启用 SQLCipher，以及密钥保存和恢复策略。
- OPPO、vivo 首批支持的具体机型、Android 版本、ColorOS 与 OriginOS 版本。
- APK 内测、OPPO 软件商店、vivo 应用商店或其他分发渠道的优先级。
- 分钟级提醒目标已确认；后续通知开发时仍需确认 Android 精确提醒特殊权限申请与应用商店审核策略。
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

每次新对话开始、进行项目判断或修改前，先完整阅读本文件，再阅读第 12 节指向的当期每日交接文件。不得只凭聊天记录推断项目状态。

从 2026-09-22 起执行七天建档制：每连续 7 个自然日建立一个 `docs/handoffs/YYYY-MM-DD_to_YYYY-MM-DD/` 目录；目录内按上海时区日期每天保留一份 `YYYY-MM-DD.md`。同一天多次工作续写同一文件，第 8 天新建下一期目录，旧目录和每日文件永久保留。若某天没有项目工作，不强制生成空文件；下一次工作时写明空档。

进入新一天后，必须先阅读前一日交接文件，在当天文件开头写出“前一日摘要、遗留问题和今天的衔接”；前一日没有文件时，明确写“前一日无记录”，并总结最近一份已有文件。然后才能续写当天开发记录。`docs/HANDOFF.md` 保持为最新项目状态、待办和归档索引；第 11 节既有历史记录原样保留，不因轮换删除。

每次完成有意义的开发工作后，在结束前更新本文件和当天文件，至少记录：

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

### 2026-09-18：SQLite 任务数据层第一轮

本次目标：

- 按技术方案完成应用内 SQLite 后端第一轮，不引入服务器、账号、云数据库或远程服务。
- 保持现有页面与 `TaskRepository` 调用方式不变，使 Android/iOS 生产入口具备任务持久化能力。

实际完成：

- 新增 SQLite v1 Schema，包含 `tasks`、`task_events`、`categories`、`reminders`、`preferences`、`profile`、`app_meta` 和文档要求的索引。
- 默认写入学习、工作、生活、娱乐四个系统分类，并开启 SQLite 外键约束。
- 新增 `AppDatabase`，实现单连接复用、并发打开保护、建库、前向迁移入口、关闭和稳定错误映射。
- 新增 `SqliteTaskRepository`，实现任务 CRUD、字段校验、UTC 毫秒持久化、UUID、乐观版本校验和状态机。
- 创建、更新和状态流转均在同一事务中写入任务与 `task_events`；重复提交相同终态不会重复写事件。
- 新增 `AppFailure`，提供 `TASK_NOT_FOUND`、`VALIDATION_FAILED`、`DATABASE_UNAVAILABLE`、`MIGRATION_FAILED`、`STORAGE_FULL` 等稳定错误码。
- `TaskItem` 增加 `updatedAt` 和 `version`；Controller 与 Repository 支持注入 `ClockPort`。
- Android/iOS 生产入口切换到 SQLite Repository；Web 仅作为开发预览，继续使用内存 Repository。

主要变更文件：

- `lib/src/core/app_failure.dart`
- `lib/src/data/database/app_database.dart`
- `lib/src/data/database/schema.dart`
- `lib/src/data/sqlite_task_repository.dart`
- `lib/src/domain/task.dart`
- `lib/src/domain/ports.dart`
- `lib/src/data/in_memory_task_repository.dart`
- `lib/main.dart`
- `test/sqlite_task_repository_test.dart`
- `pubspec.yaml`、`pubspec.lock`
- `README.md`、`docs/TECHNICAL_SOLUTION.md`、`docs/API_CONTRACTS.md`

依赖变化：

- 新增生产依赖：`sqflite`、`path`、`uuid`。
- 新增测试依赖：`sqflite_common_ffi`。
- 未启用 SQLCipher；继续使用应用私有目录中的标准 SQLite，等待产品确认密钥恢复策略。

验证结果：

- `dart format lib test`：通过。
- `flutter analyze`：通过，`No issues found`。
- `flutter test`：通过，共 11 项测试；其中 7 项覆盖建库、索引、默认分类、事务事件、连接重开持久化、合法/非法状态流转、幂等、乐观锁、事务回滚和稳定错误码。
- `flutter build apk --debug`：成功，生成 `build/app/outputs/flutter-apk/app-debug.apk`。
- 构建过程中 Kotlin 增量缓存报告 C:/D: 跨盘符异常，但 Gradle 自动回退后构建成功；未发现 SQLite 或 Dart 编译错误。

已知问题与待确认：

- 本轮未把 APK 重新安装到真机，因此任务跨进程持久化目前由文件型 SQLite 自动化测试验证，尚待 vivo 真机复核。
- 当前只实现任务 Repository；偏好、提醒、资料、导入导出和系统通知 Adapter 尚未实现。
- v1 是首个正式 Schema，没有可供测试的旧生产 Schema；迁移入口已建立，首个升级测试应在 v2 出现时补充。
- PRD 规定标题/备注上限为 80/1000，当时 UI 与接口契约暂沿用 60/300；该差异已于 2026-09-22 按用户决定解决。
- 物理删除仍沿用现有 UI 行为；“有历史记录优先归档”的 Use Case 策略尚未独立实现。

版本控制：

- 本次未执行任何 Git 命令，也未创建提交、分支或远程操作。

### 2026-09-18：SQLite 版本 vivo Android 15 真机验证

设备与安装：

- 设备：vivo `V2362A`，Android 15 / API 35，ARM64，1080 × 2400。
- Flutter 正常识别 USB 设备并成功构建、安装、启动 Debug APK。
- 首次安装被手机端 USB 安装确认拒绝；保持解锁并在第二次弹窗允许后安装成功。
- 包名与 Activity：`com.ddl.ddl_survival/.MainActivity`。

验证步骤与结果：

- 首次启动显示“生存第 1 天”“0 个未完成”，SQLite 空库状态正确。
- 通过真实创建页新增 `USB_SQLite_Persist_20260918`，首页立即显示 1 个未完成和对应风险卡片。
- 使用 `am force-stop` 强制结束应用，再重新启动 Activity；测试任务仍存在，证明真机跨进程持久化通过。
- 通过任务详情和删除二次确认清理测试任务；首页恢复“0 个未完成”，未清除应用数据或首次启动日期。
- 使用 `am start -W` 测得冷启动 `TotalTime: 1609ms`，低于 PRD 2.5 秒目标。
- 重启后的应用日志未发现 Flutter 未捕获异常、SQLite 异常、数据库打开失败或崩溃。

观察到的系统日志：

- vivo/MediaTek 图形栈报告 `mali_gralloc` 格式尝试失败、`BLASTBufferQueue` 已获取帧数告警和一次 `Skipped 31 frames`。
- 系统还报告 `UltraFrameworkComponentFactoryImpl` 缺失及 `OnBackInvokedCallback` 未启用。
- 当前界面持续可见、交互正常、持久化正确；上述日志未造成用户可见故障。后续应在 Profile/Release 构建和更多 vivo/OPPO 机型上复核，区分 Debug/Impeller 与厂商系统噪声。

代码与版本控制：

- 本轮未修改业务代码，仅更新本交接记录。
- 未执行任何 Git 命令。

### 2026-09-18：品牌 App 图标接入

本次目标：

- 将用户提供的计时器/箭头图标移除外侧米白背景，并用于 Android/iOS 应用图标。

实际完成：

- 使用内置图像编辑能力执行透明背景抠图，保留橙色圆角底板及黑、米白、橙色计时器箭头主体。
- 主图标保存为 `assets/branding/app_icon.png`，尺寸 1254 × 1254，像素格式为 32 位 ARGB。
- 新增 `flutter_launcher_icons 0.14.4` 开发依赖及生成配置。
- 生成 Android mdpi 至 xxxhdpi 传统图标、Android 自适应图标前景及 `#F46A3B` 背景。
- 生成 iOS AppIcon 全尺寸资源；1024 图标 Alpha 为 255，透明区域使用 `#F46A3B` 填充，满足 iOS 不透明要求。

验证结果：

- `dart run flutter_launcher_icons`：成功生成 Android/iOS 图标。
- `flutter analyze`：通过，`No issues found`。
- `flutter test`：通过，共 11 项测试。
- `flutter build apk --debug`：成功。
- 新 APK 已安装到 vivo V2362A；设备当时处于锁屏状态，未完成桌面图标截图核对。

数据影响：

- `flutter install` 本次输出显示先卸载旧版再安装，因此应用私有数据被重置。
- 安装前已确认应用为 0 个任务的空状态，没有任务数据损失；首次启动日期重置为当天。
- 后续含真实用户数据的真机更新必须改用保留数据的 `adb install -r` 或等价升级安装流程。

版本控制：

- 本次未执行任何 Git 命令。

### 2026-09-22：字段上限统一与提醒精度决策（待审批）

本次目标与实际完成范围：

- 用户确认任务标题最多 80 字符、备注最多 1000 字符；创建页、内存 Repository、SQLite Repository 与接口文档已统一。
- SQLite 从 v1 升至 v2；旧库升级在事务中保留任务、任务事件和提醒记录，重建 `tasks` 字段长度约束及索引，并检查外键完整性。
- 用户确认所有 DDL 定时提醒以指定分钟为目标；PRD、技术方案与接口契约已写明 Android 精确提醒权限、降级提示和实际送达限制。本轮未接入系统通知，不宣称分钟级提醒已经可用。
- 按用户指定的审批门槛，本轮未开始启动时逾期协调、忏悔录结案等任务闭环开发；获得明确审批后再开展。

主要变更文件：

- `lib/src/domain/task.dart`、`lib/src/screens/create_task_screen.dart`
- `lib/src/data/in_memory_task_repository.dart`、`lib/src/data/sqlite_task_repository.dart`
- `lib/src/data/database/schema.dart`、`lib/src/data/database/app_database.dart`
- `test/sqlite_task_repository_test.dart`
- `docs/PRD.md`、`docs/TECHNICAL_SOLUTION.md`、`docs/API_CONTRACTS.md`、`docs/HANDOFF.md`

验证结果：

- `dart format`：通过。
- `flutter analyze`：通过，`No issues found`。
- `flutter test test/sqlite_task_repository_test.dart`：通过，9 项测试，其中新增 80/1000 边界与真实 v1→v2 升级保留数据测试。
- `flutter test`：通过，共 13 项测试。
- 尚未在 vivo 上安装 v2 APK 或执行真机通知测试；需在审批后的集成阶段验证保留数据升级路径。

版本控制：

- 本次未执行 Git 命令，未创建提交或推送。

### 2026-09-22：vivo V2362A 真机更新与界面修正

本次目标与范围：

- 在已连接的 vivo V2362A（Android 15）上更新当前 Flutter Debug APK，并检查启动、SQLite v2 与主要页面。
- 仅修复真机截图确认的创建入口遮挡和两处未实现功能的错误文案；未开展待审批的任务闭环或系统通知开发。

主要变更文件：

- `lib/src/app.dart`：仅在待办页有可见任务时显示悬浮“新任务”按钮；主页及空待办页使用各自已有的创建入口，避免重叠遮挡。
- `lib/src/screens/home_screen.dart`：通知中心空态不再声称未接入的通知调度器正常运行。
- `lib/src/screens/profile_screen.dart`：数据管理文案明确任务已存入本机 SQLite，JSON 导入导出尚未接入。
- `test/widget_test.dart`：创建流程测试改用待办页顶部“新增”入口。
- `docs/HANDOFF.md`：记录本次真机验证。

验证结果：

- `flutter analyze`：修改前及业务代码修改后通过，无问题。
- `flutter test`：最终 13 项全部通过。修改悬浮按钮后首次运行有 1 项测试仍寻找旧入口，已更新测试并复跑通过。
- `flutter build apk --debug --no-pub`：成功。使用 `adb install --no-streaming -r -t` 原位更新，返回 `Success`，未卸载或清除应用数据。
- 安装时间更新为 2026-09-22 19:44:01，首次安装时间仍为 2026-09-18 23:36:31；设备内安装包与构建包 SHA-256 一致。
- 应用可启动，首页、待办、忏悔录和“我的”均可打开；修正后首页截图确认底部创建入口不再被悬浮按钮遮挡。
- 真机数据库 `PRAGMA user_version=2`、`app_meta.schema_version=2`。通过创建页新增临时任务 `VIVOTEST`，SQLite 同时出现 1 条任务和 1 条事件；强制结束并冷启动后首页仍显示该任务（`am start -W` 的 `TotalTime: 2241ms`）；随后通过任务详情二次确认删除，任务、事件和提醒表均恢复为 0 行。
- 应用日志未见 Flutter 或 SQLite 异常，只有 vivo 系统 `UltraFrameworkComponentFactoryImpl` 缺失噪声。

环境与后续事项：

- `flutter doctor -v` 显示 Android cmdline-tools 缺失、许可证状态未知，但本次构建及安装成功；后续需补齐工具链配置。
- 系统通知、JSON 导入导出、启动/前台逾期协调仍未实现；须按现有审批门槛确认后推进。当前 APK 为 Debug 构建，版本号仍是 `1.0.0+1`。
- 本次开头在读取项目规则前执行过一次只读 `git status --short --branch`；之后未再执行 Git 命令，也未提交、切换分支或推送。

### 2026-09-22：任务闭环第一轮（审批后）

目标与完成范围：

- 用户已批准启动任务闭环开发。本轮实现到期判定 `now >= dueAt`：应用冷启动、恢复前台、前台单一定时器及创建过去截止时间任务时，自动把到期未完成任务移入忏悔录。
- `TaskRepository.reconcileOverdue(asOf)` 对 SQLite 的到期任务在单一事务中更新状态、版本和风险快照，并逐项写入 `TASK_OVERDUE` 事件；重复调用不重复变更。内存 Repository 实现相同状态行为，用于 Web 预览与测试。
- 到期瞬间发起普通“完成”时，Repository 原子改为 `OVERDUE_REVIEW`，页面引导至忏悔录，避免误记为按时完成。忏悔录“逾期完成”“确认错过”沿用已有状态机和事件记录，结案后列表、压力指数和统计刷新。
- 前台只使用一个截止时间定时器，最长每分钟复核一次；应用退到后台时暂停，恢复前台立即协调。通知 Adapter、后台系统闹钟和 JSON 导入导出不在本轮范围。

主要变更文件：

- `lib/src/domain/ports.dart`
- `lib/src/data/in_memory_task_repository.dart`、`lib/src/data/sqlite_task_repository.dart`
- `lib/src/state/app_controller.dart`、`lib/src/app.dart`
- `lib/src/screens/home_screen.dart`、`lib/src/screens/todo_screen.dart`、`lib/src/screens/task_detail_sheet.dart`
- `test/app_controller_test.dart`、`test/sqlite_task_repository_test.dart`、`test/widget_test.dart`
- `docs/PRD.md`、`docs/TECHNICAL_SOLUTION.md`、`docs/API_CONTRACTS.md`、`docs/HANDOFF.md`、当天每日交接文件

验证结果：

- `dart format`：通过；`flutter analyze`：无问题。
- `flutter test`：22 项全部通过，新增到期边界、幂等、事务失败回滚、创建过去截止时间任务、前台到点、恢复前台和忏悔录双分支测试。
- `flutter build apk --debug --no-pub`：成功，生成 `build/app/outputs/flutter-apk/app-debug.apk`。

已知限制与后续：

- 本轮检查 Android SDK 内的 `adb devices`，未发现在线设备，因此未安装 APK 到 vivo，也未做 OPPO/iPhone 真机验证；`2 秒内进入忏悔录`的设备端耗时仍需真机测量。
- 应用不运行时不会自行写入 SQLite 逾期状态；下次启动或恢复前台立即协调。真正的分钟级系统通知仍待后续 Adapter 实现。
- 逾期协调若遇数据库错误会按一分钟间隔重试并上报 Flutter 错误；持久错误的用户可见提示仍待统一错误界面。
- 未新增依赖、环境变量或 Schema 迁移；未执行 Git 命令。

### 2026-10-03：后端进度复核

- 对照交接、代码目录、依赖和测试确认：当前后端为应用内 SQLite v2 与任务领域逻辑，没有业务服务端。
- 任务 CRUD、v1→v2 迁移、逾期协调和忏悔录双分支已实现；提醒、偏好、资料 Repository、系统通知 Adapter 和 JSON 导入导出仍未实现。
- 本次 `flutter test` 22 项通过，`flutter analyze` 无问题；未改业务代码、依赖或 Schema，未进行 APK 构建或真机测试，未执行 Git 命令。详见 2026-10-03 每日交接。
- 同日按 PRD、技术方案和代码缺口拟定第 6 节后续后端开发批次，待用户审批；尚未开始功能开发。

### 2026-10-04：P0 任务核心补齐（已审批）

- 复用创建表单作为编辑页，预填名称、截止分钟、重要度、分类、预计耗时和备注；增加自定义分钟输入。仅进行中任务可编辑，使用版本号防止旧页面覆盖；改为过去截止时间会立即进入忏悔录，不能靠编辑绕过结案。
- 引入纯 Dart 风险引擎：时间 45、重要度 20、工作量 15、24 小时 DDL 密度 10、同类错过率 10；详情逐项解释，首页/待办统一排序与展示。SQLite 快照与配置版本 2 随任务写入、状态变更和启动逾期协调刷新，Schema 仍为 v2，无破坏性迁移。
- `TASK_CREATED` 不算需要保留的操作历史；更新、到期或结案后删除请求会归档并保留事件，新建未改的进行中任务才物理删除。逾期待结案任务先结案再归档。
- `flutter analyze` 无问题；`flutter test` 31 项全部通过，新增编辑、风险、密度象限、历史、SQLite 快照和界面交互测试。最终代码 Android Debug APK 构建成功。vivo 真机未验：`adb devices` 无在线设备，未安装、卸载或清理设备数据。
- 未开发待审批的设置/提醒/双端通知/导出批次；未执行 Git 命令。详见 2026-10-04 每日交接。

### 2026-10-04：真机回归协作规则补充

- 用户确认可在开发中途请求其通过 USB 连接 vivo，以便及时执行真机回归；已写入始终生效的 `.cursor/rules/project-collaboration.mdc`。
- 用户确认连接后先核实 ADB 设备与机型；更新应用须保留现有数据，不擅自卸载、清除应用数据或删除真实任务。真机不可用时继续其他验证并记录未覆盖项。
- 本次仅更新协作规则和交接文档，未重新连接设备、安装 APK、修改业务代码或执行 Git 命令。

### 2026-10-04：vivo 任务核心回归及 P0 本地数据层

- 在已授权连接的 vivo V2362A（Android 15）通过 `adb install --no-streaming -r -t` 原位安装 Debug APK，保留原有应用数据；首次安装时间未变。真实页面验证新建并编辑过去截止分钟的任务会进入忏悔录，“逾期完成”和“确认错过”两条结案分支均可完成，强制结束后重启仍保留任务状态；未发现 Flutter/SQLite 崩溃。
- 两条临时测试记录按历史策略不会被普通完成操作物理删除；对其中一条执行了“归档”点击，但随后的读取因工具用量限制中断，结果未核实。另一条已结案的 `MISSED` 历史记录仍可能留在本机；不得把它们当作用户真实任务或声称已全部清理。本次收尾 ADB 未发现在线设备，待下次连接后复核。
- 新增本地设置、个人资料、提醒记录领域模型与 Repository 的 SQLite/内存实现；单例默认值和保存、事务替换、提醒状态转换与取消已覆盖自动化测试。Android/iOS 生产入口注入设置和资料 Repository；个人中心可保存昵称、签名、通知开关、免打扰时段、默认提前量和文案强度。手机上验证通知开关与昵称跨进程重启持久化后，恢复了测试前的值。
- 提醒 Repository 仅负责存储计划和状态，尚未接入任务变更协调、系统通知、权限申请或分钟级送达；通知开关也仅是应用偏好。Schema 仍为 v2，无新依赖或数据迁移。
- `dart format` 完成；`flutter analyze` 无问题，`flutter test` 38 项全部通过，最终 `flutter build apk --debug --no-pub` 成功。设置/资料 APK 曾在 vivo 原位安装验证；最后几处 Repository 小修订已包含在最终 APK，但因设备离线未重新装机。
- 本次未执行 Git 命令。下一批建议按第 6 节第 3 项开发提醒计划与协调，之后再接平台通知；OPPO/iPhone 真机与 JSON 数据安全能力仍未验证或实现。详见 2026-10-04 每日交接。

### 2026-10-04：P0 提醒计划与协调（用户批准下一步）

- 新增 `ReminderPlanner`，按任务截止分钟和偏好生成稳定业务 ID 的 `PENDING` 目标记录：默认 24 小时/3 小时，长任务增加预计耗时加缓冲的提前点，投影极高风险时增加紧急阈值目标；免打扰顺延、超过截止或已过期舍弃、同一分钟去重并优先紧急渠道。
- 新增 `ReminderCoordinator` 及 `ReminderRepository.syncPlanForTask()`：SQLite 事务内增量新增和取消待处理记录，保留已触发/已取消及同计划的 `SCHEDULE_FAILED` 记录；重复对账零变更。控制器在任务和偏好变化、冷启动、前台恢复及原有前台定时复核时调用。协调失败只显示稳定错误码，不阻断任务页面，后续协调可重试。
- Android/iOS 入口注入 SQLite 提醒 Repository；个人中心明确“计划保存在本机，系统通知尚未接入”，并在同步失败时显示错误码。Schema v2、依赖、环境变量未变化；未请求权限或向平台排程，设备时区 IANA 自动识别与时间/时区系统广播仍待通知 Adapter 批次。
- `flutter analyze` 无问题，`flutter test` 49 项全部通过，`flutter build apk --debug --no-pub` 成功；新增纯计划、SQLite 幂等/失败保留、编辑/完成取消、开关再启用、数据库重开和控制器流转测试。未进行本批真机安装或 iOS 构建；未执行 Git 命令。

### 2026-10-05：P0 平台本地通知适配（真机验收待完成）

- 新增 `FlutterNotificationPort` 和 `PlatformReminderCoordinator`：SQLite 期望记录与 Android/iOS 平台待处理通知对账，使用稳定平台 ID 排程、撤销失效通知、保存 `SCHEDULED`/`SCHEDULE_FAILED` 状态并在后续协调重试；iOS 最多保留最近 60 条、Android 最多 120 条。排程按设备 IANA 时区处理，时区变化在启动/恢复前台时重排。
- Android 配置通知权限、精确闹钟权限、开机/应用升级恢复接收器、core library desugaring 和普通/紧急渠道；精确权限缺失时使用非精确模式并在“我的”明确提示无法保证指定分钟。iOS 配置 UserNotifications delegate，授权仅由用户主动触发。通知点按在冷启动/运行中打开任务详情，payload 仅含任务 ID，通知正文不泄露标题或备注。
- `flutter_local_notifications 22.3.1`、`flutter_timezone 5.1.1`、`timezone 0.11.1` 已加入依赖；Android Debug APK 构建成功，manifest 合并结果已核对。`flutter analyze` 无问题；自动化测试覆盖授权拒绝/重试、平台差异修复、滚动窗口、精确降级和通知点按。最终测试数量及设备情况见 10 月 5 日每日交接。
- 本批未检测到 ADB 在线设备，未安装新 APK；vivo/OPPO/iPhone 实际送达、权限弹窗、锁屏和系统重启行为未验。后台系统时间/时区广播即时修复仍未实现；应用重新启动或返回前台会对账。未改 SQLite Schema，未执行 Git 命令。

### 2026-10-05：vivo V2362A 平台通知真机对照回归

- 用户重新连接 vivo V2362A（Android 15/API 35）并授权真机调试。使用 `adb install --no-streaming -r -t` 原位安装本轮 Debug APK，返回 `Success`；首次安装时间仍为 2026-09-18 23:36:31，未卸载或清除数据。应用冷启动正常，初始系统通知未授权且未自动弹窗；点击应用“申请权限”后系统弹窗出现，用户手动允许。精确闹钟未授权时页面明确显示非精确降级；用户通过“申请精确”进入 vivo 系统页并手动开启后，页面显示目标分钟排程。
- 第一轮保留 vivo 原“智能控制后台耗电”设置。为凌晨测试将应用免打扰暂改为 02:00—03:00，创建唯一测试任务 `VIVO_NOTIFY_TEST_20261005`，截止 04:25。系统一度有 01:25 `RTC_WAKEUP` 精确闹钟（`exactAllowReason=permission`、`window=0`）；退后台后活跃闹钟消失，系统近期记录为 `Reason=frozen`，01:25 后未见本应用通知。该观察支持后台策略影响，但未单独证明其唯一根因。
- 用户明确允许仅调整本应用后台耗电设置做对照。记录原状态为“智能控制后台耗电”选中、“允许后台高耗电”未选中；临时切换后创建第二条唯一测试任务 `VIVO_NOTIFY_BATTERY_TEST_20261005`，截止 04:43，系统 01:43 精确闹钟在退后台后仍活跃，01:43:23 从 `dumpsys notification` 确认 `ddl_normal` 通知送达；点按通知打开对应任务详情。两条无操作历史测试任务均通过应用删除确认流程物理删除，待办恢复 0 条；插件待通知缓存 `[]`。免打扰恢复 23:00—07:30，后台耗电恢复原“智能控制”，通知与精确闹钟权限由用户手动授权后保留。仅清理了本轮 `uiautomator` 临时 XML；未改其他应用或真实任务。
- 本轮未改业务代码、依赖或 Schema，未执行 Git 命令。vivo 当前恢复到会冻结闹钟的原后台模式，不可声称已彻底解决后台准点送达；需用户评审持久引导与默认体验。OPPO/iPhone、锁屏、重启和后台时间/时区变更仍待测。细节见 10 月 5 日每日交接。

### 2026-10-05：黄色角色应用图标替换与 vivo 原位更新

- 使用用户提供的 874×951 角色图，经内置 imagegen 按原角色外观重排为 1254×1254 白底方形图标母版，替换 `assets/branding/app_icon.png`；不增加文字或其他物件。
- `pubspec.yaml` 将 Android 自适应图标与 iOS 图标背景改为白色。首次生成的 0% 自适应前景内缩在 vivo 应用信息页裁掉头部；改为 16% 后复查，头部、手和脚均完整显示。
- `dart run flutter_launcher_icons` 成功重新生成 Android mipmap、adaptive foreground/background 与 iOS AppIcon。最终 Android 最高密度传统图标为 192×192，iOS 1024 图标为 RGB 无透明通道。
- `flutter analyze` 无问题，`flutter test` 56 项全部通过，`flutter build apk --debug --no-pub` 成功。vivo V2362A（Android 15）使用 `adb install --no-streaming -r -t` 原位更新返回 `Success`；设备 APK 与本地构建包 SHA-256 一致。
- 真机 `firstInstallTime` 仍为 2026-09-18 23:36:31，最后更新时间为 2026-10-05 02:17:40；更新前后任务均为 2 条、SQLite Schema 均为 v2，已授权的通知权限仍在。应用冷启动 `TotalTime: 1458ms`，前台运行，应用进程日志未匹配 Flutter/SQLite/崩溃错误。
- 本轮只更换图标资源与生成配置；未改业务逻辑、依赖或数据库，也未执行 Git 命令。iOS 图标已生成，但 Windows 环境未做 iOS 构建/真机验收；vivo 原后台智能控制模式的提醒限制仍按今日交接处理。当前安装包仍为 Debug 版 `1.0.0+1`。

### 2026-10-05：当前开发进度本地 Git 归档（用户授权）

- 用户明确表示只需本地 Git 版本控制，不需要远端上传。当前 `main` 在早期 SQLite 基线提交之后累计了任务核心、提醒 Repository/计划、Android/iOS 本地通知适配、vivo 对照回归、交接规则与黄色角色图标资源；本次按这些实际进度制作一个本地提交，不声称平台通知批次已全部验收。
- 提交前 `git diff --check` 无空白错误，`flutter analyze` 无问题，`flutter test` 56 项全部通过。仓库 `git remote -v` 为空；不新增远端、不推送、不创建 PR。具体提交标识以 Git 历史为准。

### 2026-10-05：待办页密度优化与悬浮创建入口移除

- 根据用户真机截图，收紧四象限网格到筛选栏的垂直空白：嵌套 `GridView` 明确设为非主滚动、零内部 padding，外部固定间距从 20dp 调整为 12dp，避免系统安全区被重复计入。
- 从应用壳彻底移除待办页中央悬浮“新任务”按钮；右上角“新增”和空状态“新建任务”入口继续保留，创建能力不减少。
- 新增 Widget 回归断言：页面不存在带“新任务”文字的 `FloatingActionButton`，四象限网格底部到筛选栏顶部的距离为 12dp，右上角“新增”仍能进入创建页。
- `dart format` 通过，`flutter analyze` 无问题，定向 Widget 测试通过，完整 `flutter test` 56 项全部通过。Web 预览已在 `http://127.0.0.1:51876` 启动；自动浏览器截图因 Windows 沙箱 helper 刷新异常未完成，需用户或后续会话人工目视复核。
- 本轮未改数据库、依赖、通知或原生配置，未进行真机安装，未执行 Git 命令。

### 2026-10-05：创建页自定义分类与 SQLite v3 预留字段

- 用户要求仅调整前端与数据库预留字段。新建/编辑任务页在学习、工作、生活、娱乐之外新增“自定义”选项；选中后渐进展开标签输入框，去除首尾空白后必填且最多 12 个字符。列表卡片和详情使用该自定义文本作为分类章。
- 截止时间区域删除“今天 23:00”“明天 18:00”“三天后”三个预设快捷项；用户继续通过日期/时间选择器设置精确分钟。
- SQLite 从 v2 升至 v3。`tasks` 新增可空的 `custom_category_label TEXT`，`categories` 新增 `id='custom'`、`name='自定义'` 的系统占位行，使 `category_id='custom'` 仍满足外键。v2→v3 使用 `ALTER TABLE`，既有任务值为 `NULL`，不重建任务表。仅完成单字段读写与验证，未新增标签管理 Repository、独立表、同步或云端能力。
- 变更文件：`lib/src/domain/task.dart`、`lib/src/screens/create_task_screen.dart`、`lib/src/widgets/common.dart`、`lib/src/screens/task_detail_sheet.dart`、内存/SQLite 任务 Repository、SQLite Schema/建库入口、对应测试与文档。
- 验证：`dart format lib test` 通过；`flutter analyze` 无问题；SQLite 定向测试 17 项与 Widget 定向测试 8 项通过，完整 `flutter test` 58 项全部通过。覆盖 v1→v3、v2→v3、旧数据保留、自定义标签持久化及三个快捷截止项不存在。Web 预览已在 `http://127.0.0.1:51876` 重新启动；Windows UI helper 连续两次在连接浏览器时重置，未完成自动截图目视。
- 本轮无新依赖、环境变量、云服务或原生通知变化；未进行真机安装。按当前任务权限未执行任何 Git 命令。

### 2026-10-06：默认提醒双列纵向轮选 UI

- 根据用户截图，移除“提前分钟数，以逗号分隔”的文本框。弹窗改为左右双列、上下滚动并定位吸附的轮选器：左列“提醒一”必选，右列“提醒二·可选”可选“不设置”。选项直接显示“2 分钟前”“3 小时前”“1 天前”等可读文案，不再暴露 1440/180 这类分钟数据。
- 两列选中相同提前量时保存自动去重，保存后按从远到近排序，继续调用现有 `AppController.setDefaultReminderOffsets(List<int>)`。本轮未改 `AppPreferences`、Repository、SQLite Schema、`ReminderPlanner` 或平台通知。
- 产品需求已登记但未开发：若任务从现在到截止时间的剩余时长小于全部系统默认提前量，创建/编辑页应出现任务级提醒可选字段；用户不填时只对该任务使用截止前 5 分钟，不回写或改动全局 `defaultReminderOffsetsMinutes`。实现时需单独设计任务字段、SQLite 迁移、编排分支及边界测试。
- 变更文件：`lib/src/screens/profile_screen.dart`、`test/widget_test.dart`、`docs/HANDOFF.md`、`docs/handoffs/2026-10-06_to_2026-10-12/2026-10-06.md`。新周期档案目录已建立。
- 验证：`dart format lib test` 通过，`flutter analyze` 无问题，完整 `flutter test` 59 项全部通过。新增 Widget 测试确认弹窗为两个 `ListWheelScrollView`、不存在逗号输入提示，且滚动后保存为预期分钟列表。Web 预览已在 `http://127.0.0.1:51876` 以新代码重启。
- 本轮无新依赖、环境变量、SQLite/通知迁移或真机安装；未执行任何 Git 命令。

## 12. 七天交接档案索引

- 上一周期（2026-09-22 至 2026-09-28）：`docs/handoffs/2026-09-22_to_2026-09-28/`
- 2026-09-22 每日交接：`docs/handoffs/2026-09-22_to_2026-09-28/2026-09-22.md`
- 2026-09-17 至 2026-09-22 的既有历史记录仍保留在本文件第 11 节；从本周期起每日独立留档，不追溯改写旧记录。
- 上一周期（2026-09-29 至 2026-10-05）：`docs/handoffs/2026-09-29_to_2026-10-05/`
- 2026-10-03 每日交接：`docs/handoffs/2026-09-29_to_2026-10-05/2026-10-03.md`
- 2026-10-04 每日交接：`docs/handoffs/2026-09-29_to_2026-10-05/2026-10-04.md`
- 2026-10-05 每日交接：`docs/handoffs/2026-09-29_to_2026-10-05/2026-10-05.md`
- 当前周期（2026-10-06 至 2026-10-12）：`docs/handoffs/2026-10-06_to_2026-10-12/`
- 2026-10-06 每日交接：`docs/handoffs/2026-10-06_to_2026-10-12/2026-10-06.md`
- 2026-10-12 每日交接：`docs/handoffs/2026-10-06_to_2026-10-12/2026-10-12.md`
## 2026-10-06 默认提前提醒选择器口径修正（v1.28）

- 用户澄清：该弹窗选择的是**一个提前提醒时长**，不是“提醒一 / 提醒二”两条提醒。
- 当前 UI：左列为小时 `0–24`，右列为分钟 `0–60`，均采用上下滑动滚轮；保存值为单元素分钟列表 `[小时 × 60 + 分钟]`，继续复用现有偏好设置接口。
- `00 时 00 分` 不允许保存，并提示“至少提前 1 分钟”；本次只修改前端和预留交互，不改 SQLite 表结构、提醒调度器或原生通知实现。
- 既有待实现规则保持不变：若任务剩余时间短于系统默认提前提醒时间，在任务创建页提供可选的单任务提醒时间；未填写时仅该任务按截止前 5 分钟提醒，不改变系统默认值。
- 本节覆盖文档中同日较早的“两条提醒滚轮”描述；后续开发与验收均以本节口径为准。

## 2026-10-06 待开发需求复核（v1.29）

- 本次仅对照本交接、当天交接、PRD、技术方案和当前代码做需求盘点；未修改业务代码、依赖、Schema 或原生配置，未执行 Git 命令。
- 最新口径以当天小时/分钟双列单一提醒时长为准；早先“提醒一/提醒二”描述已被覆盖。短截止任务的任务级提醒、默认提前 5 分钟回退及不回写全局设置尚未开发，需要任务字段、SQLite 迁移、计划分支与边界测试。
- 当前测试基线不通过：`flutter analyze` 在 `test/reminder_duration_picker_dialog_test.dart:40` 报 `ScrollController` 没有 `jumpToItem`；`flutter test` 为 58 通过、2 失败，除该编译错误外，`test/widget_test.dart:445` 仍断言旧弹窗 Key，已与新 UI 不一致。下一轮先修测试并重新验证。
- 其余待开发按批次：P0 JSON 全量导出及二次确认本机清除；平台通知的 vivo 后台设置引导/降级、后台时间/时区即时修复与 OPPO/iPhone/锁屏/重启验收；发布前迁移、离线、权限、时间回拨、性能和诊断回归。P1 版本化 JSON 导入/恢复、标签复用管理与更完整历史等另行评审。首页“通知中心”目前仍非系统收件箱。
- 文档范围有待统一：`docs/PRD.md` 12.2 仍把 JSON 导出列于 P1，而本交接第 6 节与技术方案第 12 节将 P0 全量导出、P1 导入作为当前执行顺序；后续开发前应明确并同步 PRD。

## 2026-10-06 提醒测试修复与短截止任务闭环（v1.30）

- 用户批准先完成前两组待办。修正新提醒选择器测试的 `FixedExtentScrollController` 类型及旧弹窗 Key/旧多值断言，定向测试通过。
- 表单在全部全局默认提醒点已过且任务尚未到期时显示可选“本任务提醒时间”，复用小时/分钟轮选；留空时保存该任务 5 分钟提前量，自选正整数只覆盖该任务默认提醒，不改全局偏好。所选触发点已过去时提示不会补发。
- 新增 `TaskDraft`/`TaskItem.taskReminderOffsetMinutes`、SQLite v4 `tasks.task_reminder_offset_minutes` 正数可空字段与 v3→v4 前向迁移；v1/v2/v3 升级均保留旧任务及提醒记录。提醒计划用该字段替换该任务的全局默认提前列表，保留免打扰、去重、最晚开始和极高风险提醒规则。
- 变更范围：`lib/src/domain/` 模型与计划、`lib/src/data/` 内存/SQLite Repository 及 Schema/建库入口、`lib/src/screens/` 创建页与轮选弹窗、相关测试、PRD/技术方案/接口文档和交接文档。无新依赖、环境变量、云服务或原生通知配置。
- 验证：提醒选择器、任务领域/迁移/Widget 定向测试通过；最终 `flutter analyze` 无问题，完整 `flutter test` 69 项全部通过；`flutter build apk --debug --no-pub` 成功。
- 尚未进行 vivo/OPPO/iPhone 真机安装或短截止提醒送达验证；vivo 智能后台限制仍可能冻结系统闹钟。既有 SQLite 偏好可能含两个旧默认提前量，直到用户重新保存选择器才变为单值；本轮保留旧值，避免隐式丢弃用户设置。未执行 Git 命令。
