# RawEvent 架构实现清单

## 📋 已创建的设计文档和代码框架

### 1. 设计文档

| 文件 | 内容 | 用途 |
|------|------|------|
| **RAW_EVENT_DESIGN.md** | 完整架构设计 | 理解为什么需要 RawEvent，数据流，迁移计划 |

### 2. 核心数据模型（lib/core/models/）

| 文件 | 类 | 职责 |
|------|---|----|
| **raw_event.dart** | `RawEvent` | 从 OCR 输出提取的事件，包含多个候选值和置信度 |
| | `TopCandidate` | RawEvent 中最高置信的候选组合 |
| | `ResolveDecision` | 决策枚举（autoResolve / needsConfirmation / reject） |

### 3. 置信度计算（lib/core/confidence/）

| 文件 | 类 | 职责 |
|------|---|----|
| **confidence_calculator.dart** | `ConfidenceCalculator` | 计算每个字段和整体的置信度 |
| | `ConfidenceWeights` | 权重配置（快递商 35%，取件码 30%，等等） |
| | `ConfidenceThresholds` | 决策阈值（0.85 / 0.60） |

### 4. RawEvent 构建（lib/core/raw_event/）

| 文件 | 类 | 职责 |
|------|---|----|
| **raw_event_builder.dart** | `RawEventBuilder` | 从 OCR 输出和提取结果构建 RawEvent |

### 5. 测试示例（test/）

| 文件 | 覆盖 | 用途 |
|------|------|------|
| **raw_event_test.dart** | 9 个测试用例 | 展示如何测试各个场景 |

---

## 🎯 数据流对比

### ❌ 现在（过于激进）

```
OCR 输出
  ↓
TextParser
  ↓
Package ✓✓✓（一次性固化）
  ↓
错了？没办法改
```

### ✅ 新（可控、可逆）

```
OCR 输出
  ↓
ConfidenceExtractor
  ↓
RawEvent（多个候选）
  ├─ possibleCouriers: [(顺丰, 0.98), (未知, 0.02)]
  ├─ possiblePickupCodes: [(15-3-6007, 0.96)]
  └─ overallConfidence: 0.91
  ↓
Resolver（策略决策）
  ├─ ≥0.85: autoResolve → Package
  ├─ 0.60-0.85: needsConfirmation → PendingConfirmation（用户选）
  └─ <0.60: reject → 要求重拍
  ↓
Package 或 PendingConfirmation
```

---

## 🔑 关键改进

| 方面 | 现在 | 之后 |
|------|------|------|
| **可逆性** | 一旦固化就无法改 | RawEvent 层允许多个选项 |
| **可见性** | 黑箱决策 | 每个字段的置信度都可见 |
| **用户控制** | 无法干预 | 中置信情况下用户可选择 |
| **错误根因** | 模糊 | 清晰分离（字段置信度差） |
| **学习能力** | 无 | 可以从用户确认学习 |
| **多包裹处理** | 粘连 | 分离成独立 RawEvent |

---

## 📊 置信度权重

```
快递商:        35% ← 最重要，影响整体判断
取件码:        30% ← 也很关键，用户需要拿货
快递单号:      20% ← 辅助识别
状态:          10% ← 可能有冲突信号
地址:          5%  ← 最不关键，可以为空
                ────
总计:         100%
```

## 🚦 决策阈值

```
≥ 0.85  →  自动生成 Package（不需要用户干预）
0.60-0.85 →  展示确认框，让用户选择
< 0.60  →  拒绝，提示重新拍照
```

---

## 📝 下一步实现路线

### 第一阶段：Extractor 改进（1 周）

```dart
// 现在
class ExtractionResult<T> {
  T value;
  bool isValid;
}

// 改为
class ExtractionResult<T> {
  List<(T value, double confidence)> candidates; // ← 返回多个候选
  T get topValue => candidates.first.value;
}
```

**任务：**
- [ ] 更新 `CourierExtractor` 返回候选列表
- [ ] 更新 `PickupCodeExtractor` 返回候选列表
- [ ] 更新其他 Extractor
- [ ] 确保向后兼容

### 第二阶段：OCRPipeline 集成（2 周）

**任务：**
- [ ] 在 `lib/app/ocr_pipeline.dart` 中生成 RawEvent
- [ ] 调用 `RawEventBuilder.build()`
- [ ] 传递提取结果、冲突信号、元数据
- [ ] 编写集成测试

### 第三阶段：Resolver 实现（2 周）

**任务：**
- [ ] 创建 `lib/app/resolver/raw_event_resolver.dart`
- [ ] 实现 `resolve()` 方法
- [ ] 根据置信度分叉生成 Package 或 PendingConfirmation
- [ ] 编写单元测试

### 第四阶段：UI 集成（2 周）

**任务：**
- [ ] 更新 `PackageListNotifier` 处理 RawEvent
- [ ] 创建 `PendingConfirmationDialog` 展示多个选项
- [ ] 用户确认后生成 Package
- [ ] 手动测试 UI 流程

### 第五阶段：监测和优化（持续）

**任务：**
- [ ] 收集用户确认数据（哪些选项被选中）
- [ ] 分析用户选择vs自动决策的差异
- [ ] 调整 `ConfidenceWeights` 和 `ConfidenceThresholds`
- [ ] 改进 `ConfidenceCalculator` 的计算逻辑

---

## ✅ 验证清单

### 代码完成后需要验证

- [ ] `RawEvent` 模型能从各种 OCR 输出正确构建
- [ ] 置信度计算符合直觉（高质量输入 ≥ 0.85）
- [ ] 高置信场景自动生成 Package，无用户干预
- [ ] 中置信场景展示 PendingConfirmation 对话框
- [ ] 低置信场景被拒绝，提示用户重拍
- [ ] 冲突信号正确降低状态字段置信度
- [ ] 多包裹场景生成独立 RawEvent（不粘连）
- [ ] 现有去重逻辑继续工作
- [ ] 现有通知逻辑继续工作
- [ ] 用户能从 PendingConfirmation 中选择正确选项

---

## 💡 设计原则（保持）

✅ **Core 层不变**
- RawEvent 和 ConfidenceCalculator 都在 `lib/core/`
- 零 Flutter 依赖
- 纯 Dart，100% 可测试

✅ **向后兼容**
- 现有 `Package` 模型只需添加 `confidence` 字段
- 现有 Extractor 可以逐步改进
- 现有去重逻辑无需改动

✅ **渐进式迁移**
- 可以先在 `OCRPipeline` 中试用，再逐步推广
- 旧的直接 `TextParser → Package` 和新的 `RawEvent → Resolver → Package` 可并存

---

## 📖 参考文档

- [RAW_EVENT_DESIGN.md](./RAW_EVENT_DESIGN.md) — 详细设计
- [ERROR_CLASSIFICATION.md](./ERROR_CLASSIFICATION.md) — 错误诊断系统
- [ERROR_TRACKING.md](./ERROR_TRACKING.md) — 已知错误列表

