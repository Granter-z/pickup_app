# RawEvent 架构设计

**问题：** 现在的管道太激进了。OCR 输出 → 直接 Package，一旦判断错就没有回头的余地。

**解决方案：** 引入中间层 `RawEvent`，允许**并行可能性**和**延迟决策**。

---

## 为什么 RawEvent 重要？

### 现实世界的不确定性

```
同一行文本可能有多种解释：

"JT 13位数字 取件码"
    ↓
    ├─ 极兔（JT Express） ← 90% 置信
    ├─ 京东到家（JingDong Dashu） ← 5% 置信
    └─ 未知快递商 ← 5% 置信

"待取件"
    ├─ arrived (待取件) ← 85% 置信
    ├─ preparing (备货中) ← 10% 置信
    └─ 用户输入的自由文本 ← 5% 置信

地址污染：
"转运中心 → 杭州中转站 → 用户自提柜"
    哪一个是真正的收货地址？
```

### 当前流程的问题

```
OCR 输出
  ↓
TextParser（一次性决策）
  ├─ courier = 极兔 ✓
  ├─ pickupCode = 15-3-6007 ✓
  ├─ status = arrived ❌ 应该是 preparing
  └─ location = 转运中心 ❌ 应该是杭州中转站
  
结果：Package 生成了错误数据，无法回溯

用户想纠正？没办法，Package 已经固化了。
```

### RawEvent 的优势

```
OCR 输出
  ↓
RawEvent（并行可能性）
  ├─ possibleCouriers: [极兔 (0.90), 京东到家 (0.05), 未知 (0.05)]
  ├─ possiblePickupCodes: [15-3-6007 (0.95)]
  ├─ possibleStatuses: [arrived (0.85), preparing (0.10), unknown (0.05)]
  ├─ possibleLocations: [用户自提柜 (0.80), 杭州中转站 (0.15), 转运中心 (0.05)]
  └─ confidence: 0.72 (加权综合)
  
Resolver（多策略决策）
  ├─ 高置信路线：自动选最高置信 → Package
  ├─ 中置信路线：用户确认 (PendingConfirmation) → 用户选择 → Package
  └─ 低置信路线：拒绝，要求用户重新拍照

用户体验：
- 看到多个选项
- 点击确认最合适的
- 系统学习用户反馈
```

---

## 数据模型

### RawEvent 定义

```dart
/// 从 OCR 原始文本提取的事件，包含多个可能性
class RawEvent {
  // 唯一标识
  final String id;
  final DateTime extractedAt;
  
  // OCR 原始输入
  final String rawText;
  final String source; // 'sms' / 'image' / 'manual'
  
  // 候选字段（排序后、带置信度）
  final List<(String value, double confidence)> possibleCouriers;
  final List<(String value, double confidence)> possiblePickupCodes;
  final List<(String value, double confidence)> possibleTrackingNumbers;
  final List<(String value, double confidence)> possibleStatuses;
  final List<(String value, double confidence)> possibleLocations;
  
  // 整体置信度（加权平均）
  final double overallConfidence;
  
  // 冲突信号（如果有）
  final List<String>? conflictSignals; // ['arriving', 'already_collected']
  
  // 元数据
  final Map<String, dynamic> metadata; // { device, image_quality, ocr_engine, ... }
  
  // 辅助信息
  final String? debugTrace; // 诊断信息
}
```

### 最佳候选 (TopCandidate)

```dart
/// RawEvent 中最高置信的候选组合
class TopCandidate {
  final String courier;
  final String? pickupCode;
  final String? trackingNumber;
  final String? status;
  final String? location;
  
  final double combinedConfidence;
  
  /// 判断是否应该自动转换为 Package
  bool shouldAutoResolve() => combinedConfidence >= 0.85;
  
  /// 是否需要用户确认
  bool needsUserConfirmation() => combinedConfidence >= 0.60 && combinedConfidence < 0.85;
  
  /// 是否应该拒绝
  bool shouldReject() => combinedConfidence < 0.60;
}
```

---

## 管道升级

### 现在的管道（有问题）

```
Image/SMS
  ↓
OCR (lib/platform/ocr/)
  ↓ raw_text
TextSanitizer (lib/core/sanitizer/)
  ↓ cleaned_text
TextParser (lib/core/parser/)
  ↓ parse_result (一次性决策)
Package ← 固化，无法改)
  ↓
Notifications
```

### 新管道（可逆、可解释）

```
Image/SMS
  ↓
OCR (lib/platform/ocr/)
  ↓ raw_text
TextSanitizer (lib/core/sanitizer/)
  ↓ cleaned_text
CONFIDENCE EXTRACTOR (新) ← 关键改变
  ↓ raw_event (并行可能性)
  
  RawEvent
  ├─ possibleCouriers: [...]
  ├─ possiblePickupCodes: [...]
  └─ overallConfidence: 0.72
  ↓
RESOLVER (新) ← 策略决策
  ├─ 高置信 (≥0.85) → autoResolve() → Package
  ├─ 中置信 (0.60-0.85) → needsConfirmation() → PendingConfirmation (让用户选)
  └─ 低置信 (<0.60) → reject() → 要求重拍
  ↓
Package 或 PendingConfirmation
  ↓
PackageListNotifier (去重、存储)
  ↓
Notifications
```

---

## 职责划分

### Layer: lib/core/models/ (新增)

```dart
// RawEvent 和 TopCandidate 的不可变模型
// 纯 Dart，零 Flutter 依赖
```

### Layer: lib/core/confidence/ (新增)

```dart
/// 从提取结果计算置信度
class ConfidenceCalculator {
  /// 计算每个字段的置信度
  double calculateCourierConfidence(String courier, String trackingNumber) 
    → courier 前缀是否匹配？keyword 是否已知？
  
  double calculatePickupCodeConfidence(String code, String line)
    → 格式是否符合？周围上下文？
  
  double calculateStatusConfidence(String status, String line)
    → keyword 是否明确？是否有冲突信号？
  
  /// 计算整体置信度（加权）
  double calculateOverallConfidence(
    courier: 0.90,
    pickupCode: 0.95,
    status: 0.70,  ← 低，有冲突
    location: 0.60,  ← 低，可能污染
  ) → (0.90 * 0.4 + 0.95 * 0.3 + 0.70 * 0.2 + 0.60 * 0.1) = 0.79
}
```

### Layer: lib/core/extractor/ (改进)

现在的 `Extractor` 只返回：
```dart
class ExtractionResult<T> {
  T value;
  bool isValid;
}
```

改为返回**带置信度的候选列表**：
```dart
class ExtractionResult<T> {
  List<(T value, double confidence)> candidates; // 排序后
  T get topValue => candidates.first.value;
  double get topConfidence => candidates.first.confidence;
}
```

### Layer: lib/core/raw_event/ (新)

```dart
/// RawEvent 工厂和构建器
class RawEventBuilder {
  RawEvent build(
    rawText: String,
    extractionResults: Map<String, ExtractionResult>,
    source: 'sms' | 'image',
    metadata: Map
  ) {
    final possibleCouriers = extractionResults['courier'].candidates;
    final possiblePickupCodes = extractionResults['pickupCode'].candidates;
    // ...
    
    final overallConfidence = confidenceCalculator.calculate(...);
    
    return RawEvent(
      rawText: rawText,
      possibleCouriers: possibleCouriers,
      possiblePickupCodes: possiblePickupCodes,
      // ...
      overallConfidence: overallConfidence,
    );
  }
}
```

### Layer: lib/app/resolver/ (新)

```dart
/// 根据 RawEvent 生成最终 Package 或 PendingConfirmation
class RawEventResolver {
  /// 从 RawEvent → (Package | PendingConfirmation)
  Future<ResolveResult> resolve(RawEvent event) async {
    final topCandidate = event.topCandidate();
    
    if (topCandidate.shouldAutoResolve()) {
      // 自动生成 Package
      return ResolveResult.package(
        Package(
          courier: topCandidate.courier,
          pickupCode: topCandidate.pickupCode,
          // ...
          confidence: topCandidate.combinedConfidence,
        ),
      );
    }
    
    if (topCandidate.needsUserConfirmation()) {
      // 生成待确认项，包含所有候选选项
      return ResolveResult.pending(
        PendingConfirmation(
          rawEvent: event,
          suggestions: [topCandidate, ...otherCandidates],
        ),
      );
    }
    
    // 低置信，拒绝
    return ResolveResult.rejected(
      reason: 'overallConfidence ${event.overallConfidence} < 0.60',
    );
  }
  
  /// 用户确认后 → Package
  Package confirmPending(
    PendingConfirmation pending,
    selectedIndex: int
  ) {
    final selected = pending.suggestions[selectedIndex];
    return Package(
      courier: selected.courier,
      pickupCode: selected.pickupCode,
      // ...
      confirmedByUser: true,
      userConfidenceBoost: 0.95, // 用户确认后，置信度提升
    );
  }
}
```

### Layer: lib/ui/providers/ (更新)

```dart
// 现有的 packageListProvider 改为：
// 1. 接收 RawEvent
// 2. 调用 Resolver
// 3. 根据结果生成 Package 或 PendingConfirmation
// 4. UI 显示确认框给用户选择
```

---

## 数据流示例

### 场景 1：高置信（自动通过）

```
SMS: "顺丰 SF123456 15-3-6007 已到达"

RawEvent:
  courier: [(顺丰, 0.98)]
  trackingNumber: [(SF123456, 0.99)]
  pickupCode: [(15-3-6007, 0.96)]
  status: [(arrived, 0.95)]
  location: [(default, 0.60)]
  overallConfidence: 0.91
  
TopCandidate.shouldAutoResolve() = true (0.91 >= 0.85)

Resolver → Package (自动创建)
  ├─ courier: 顺丰
  ├─ trackingNumber: SF123456
  ├─ pickupCode: 15-3-6007
  ├─ status: arrived
  └─ confidence: 0.91
```

### 场景 2：中置信（用户确认）

```
SMS: "JT 13位数字 取件码"

RawEvent:
  possibleCouriers: [
    (极兔, 0.85),
    (京东到家, 0.10),
    (unknown, 0.05)
  ]
  pickupCode: [(codes, 0.92)]
  status: [(arrived, 0.70), (delivering, 0.20)]
  overallConfidence: 0.72
  
TopCandidate.needsUserConfirmation() = true (0.72 在 0.60-0.85)

Resolver → PendingConfirmation (需要用户选择)
  ├─ 建议 1: 极兔 (0.85)
  ├─ 建议 2: 京东到家 (0.10)
  └─ 用户可看到多个选项
  
用户点击"确认 极兔"

Package (用户确认创建)
  ├─ courier: 极兔
  ├─ confirmedByUser: true
  └─ confidence: 0.95 (用户确认后提升)
```

### 场景 3：低置信（拒绝）

```
SMS: "不清楚的文本，手写的纸条"

RawEvent:
  courier: [(unknown, 0.15), (generic, 0.10)]
  pickupCode: [(unsure, 0.40)]
  status: [(unknown, 0.25)]
  overallConfidence: 0.18
  
TopCandidate.shouldReject() = true (0.18 < 0.60)

Resolver → Rejected
  └─ 用户需要重新拍照或手动输入
```

---

## 迁移计划（不破坏现有代码）

### Phase 1: 核心模型（第一周）

```
✅ 创建 lib/core/models/raw_event.dart
✅ 创建 lib/core/confidence/confidence_calculator.dart
✅ 更新 Extractor 返回 candidates list (可向后兼容)
```

### Phase 2: RawEvent 构建（第二周）

```
✅ 创建 lib/core/raw_event/raw_event_builder.dart
✅ 测试：RawEvent 从 OCR 输出正确构建
```

### Phase 3: Resolver 实现（第三周）

```
✅ 创建 lib/app/resolver/raw_event_resolver.dart
✅ 实现 autoResolve / needsConfirmation / reject 逻辑
✅ 测试：Resolver 根据置信度正确生成 Package
```

### Phase 4: UI 集成（第四周）

```
✅ 更新 OCRPipeline 生成 RawEvent
✅ 更新 PackageListNotifier 处理 RawEvent
✅ UI 展示 PendingConfirmation 确认框
✅ 用户确认后生成 Package
```

### Phase 5: 监测和优化（持续）

```
✅ 收集用户确认数据
✅ 调整置信度阈值 (0.85, 0.60)
✅ 改进 ConfidenceCalculator 权重
```

---

## 现有代码兼容性

### 保持不变
- `Package` 模型（添加 `confidence` 字段）
- `TextParser` 逻辑（只是返回更详细的信息）
- `lib/core/` 的不可变性（RawEvent 也是不可变）
- 存储层（Hive 无需改动）

### 新增
- `RawEvent` 类
- `ConfidenceCalculator` 类
- `RawEventResolver` 类
- `PendingConfirmation` 扩展（支持多选项）

### 调整
- `OCRPipeline` 流程更新
- `PackageListNotifier` 增加 resolve 逻辑
- UI 展示 pending 确认框

---

## 文件结构规划

```
lib/core/
├── models/
│   ├── package.dart (已存在，添加 confidence 字段)
│   ├── pending_confirmation.dart (已存在，扩展)
│   └── raw_event.dart (新)
│
├── confidence/ (新)
│   └── confidence_calculator.dart
│
├── raw_event/ (新)
│   ├── raw_event_builder.dart
│   └── extraction_result.dart (更新现有 Extractor)
│
└── parser/ (已存在，无需改)

lib/app/
├── ocr_pipeline.dart (更新，生成 RawEvent)
├── resolver/ (新)
│   └── raw_event_resolver.dart
└── ...

lib/ui/
├── providers/
│   └── package_provider.dart (更新，处理 RawEvent)
├── screens/home/widgets/
│   └── pending_confirmation_dialog.dart (新)
└── ...

test/
├── raw_event_test.dart (新)
├── confidence_calculator_test.dart (新)
├── resolver_test.dart (新)
└── fixtures/
    ├── real_world/... (现有)
    └── raw_events/ (新，测试用例)
```

---

## 关键决策点

| 问题 | 决策 | 理由 |
|------|------|------|
| 置信度阈值多少？ | 自动 0.85，确认 0.60 | 基于用户体验和准确率平衡 |
| 用户确认后置信度如何变化？ | 提升到 0.95 | 用户行为是最强信号 |
| 多个包裹粘连怎么办？ | 生成多个 RawEvent | 每个取件码 = 一个事件 |
| 缺失字段怎么处理？ | 允许为 null，confidence 为 0 | 不强制所有字段存在 |
| 与现有去重逻辑的关系？ | RawEvent 层无去重，Package 层保持原有 | 去重发生在最终 Package 生成后 |

