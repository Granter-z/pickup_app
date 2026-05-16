# Pickup App

一个中文取件管理 Flutter 应用，用来回答一个很具体的问题：现在有没有需要去取的快递。

应用支持导入快递短信、App 通知或截图内容，通过 OCR 和文本解析提取快递公司、取件码、运单号、手机号尾号、驿站位置和物流状态，并把待取、已取、异常等包裹集中管理。

## 功能特性

- 截图 OCR：基于 Google ML Kit 识别快递通知截图中的文字。
- 文本清洗：过滤电商页面、系统噪声和无关文本，保留物流关键信息。
- 快递解析：识别快递公司、取件码、运单号、手机号尾号、取件位置和物流状态。
- 多包裹处理：支持一段文本中包含多个取件码或多条物流信息。
- 待确认队列：低置信度或冲突信息不会直接入库，而是进入人工确认流程。
- 包裹去重：以取件码作为核心去重依据，避免重复导入同一个包裹。
- 本地持久化：使用 Hive 保存包裹数据。
- 本地提醒：包裹到达后发送通知，并支持 24 小时提醒。
- Android 通知监听：可解析通知来源中的物流信息。

## 技术栈

- Flutter / Dart
- Riverpod
- Hive
- Google ML Kit Text Recognition
- flutter_local_notifications
- Material 3

当前项目主要面向 Android，iOS 支持尚未完善。

## 项目结构

```text
lib/
  core/       纯 Dart 核心逻辑：模型、解析器、清洗器、决策引擎
  app/        应用编排：OCR pipeline、取件卡片决策、mock 数据导入
  platform/   平台适配：Hive、ML Kit OCR、系统通知
  ui/         Flutter UI：页面、组件、主题、Riverpod providers
test/
  fixtures/   回归测试样例
  mock_data/  手动导入和调试样例
```

整体依赖方向：

```text
ui -> app -> core
ui -> platform -> core
```

`lib/core/` 保持为纯 Dart 层，不依赖 Flutter、Hive、通知或 UI。

## 快速开始

### 环境要求

- Flutter SDK，Dart SDK 约束为 `^3.6.0`
- Android Studio 或可用的 Android SDK
- 一台 Android 设备或模拟器

### 安装依赖

```bash
flutter pub get
```

### 运行应用

```bash
flutter run
```

### 构建 Android APK

```bash
flutter build apk
```

## 测试和质量检查

运行全部测试：

```bash
flutter test
```

运行单个测试文件：

```bash
flutter test test/parser_regression_test.dart
```

静态检查：

```bash
flutter analyze
```

诊断某段 OCR 原始文本：

```bash
bash diagnose_error.sh test/mock_data/arrival_sms.txt
```

## 解析流程

```text
图片或文本
  -> OCR
  -> 文本清洗
  -> 冲突检测
  -> 多包裹解析
  -> 置信度判断
  -> 直接入库或进入待确认
```

高置信度结果会转成 `Package`，低置信度或存在明显冲突的结果会转成 `PendingConfirmation`。

## 常见开发任务

新增快递公司：

1. 在 `CourierType` 中添加枚举值。
2. 更新 `CourierExtractor` 的关键词或运单号规则。
3. 补充解析回归测试。

修复解析问题：

1. 在 `test/fixtures/` 中新增失败样例。
2. 修改 `lib/core/parser/` 下的解析逻辑。
3. 运行 `flutter test test/parser_regression_test.dart`。

新增 UI 功能：

1. 优先复用 `lib/ui/screens/home/widgets/` 中的组件模式。
2. 如需状态，放到 `lib/ui/providers/`。
3. 颜色、间距、圆角使用 `lib/ui/constants/app_constants.dart`。

## 许可证

当前仓库未声明许可证。
