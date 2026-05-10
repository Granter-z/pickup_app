# 错误分类系统

**目标：** 系统地分类所有错误，清晰区分 OCR 层 vs Parser 层问题，建立修复优先级。

**关键原则：** 先诊断，再修复。不要看到 bug 就改。

---

## 错误诊断决策树

```
发现错误
    ↓
问：最终输出（Package）错了吗？ 
    ├─ 否 → 不是错误，可能是设计决策
    └─ 是 ↓
      问：OCR 输出的 raw text 看对吗？
          ├─ 否 → 📍 OCR 层错误（责任：ML Kit / 图像预处理）
          └─ 是 ↓
            问：Parser 能从这行 text 正确提取吗？
                ├─ 否 → 📍 Parser 层错误（责任：TextParser / Extractors）
                └─ 是 → 这不是错误，是设计决策或冲突检测在工作
```

---

## 错误类型矩阵

| # | 错误类型 | 责任层 | 示例 | 修复地点 |
|---|---------|-------|------|---------|
| **1** | **OCR 字符误识** | OCR | 极免 → 极兔 | 后处理纠正或 ML Kit 配置 |
| **2** | **OCR 行漂移** | OCR | 行分割错误，两行合并成一行 | 图像预处理 |
| **3** | **OCR 方向错误** | OCR | 横排被识别成竖排 | 图像旋转检测 |
| **4** | **OCR 全局失败** | OCR | 整张图没有文字输出 | 图像质量检测 |
| **5** | **Parser 字段误判** | Parser | "派送中" 识别成 "待取件" | 状态提取逻辑 |
| **6** | **Parser 取件码误提** | Parser | 随机数字被误认为取件码 | 正则或上下文规则 |
| **7** | **Parser 地址污染** | Parser | "转运中心" 被识别成收货地址 | 噪音过滤规则 |
| **8** | **UI 角标污染** | Parser | "(待取件2)" 的 "2" 被提取 | 文本清理规则 |
| **9** | **多包裹粘连** | Parser | 两个 SMS 合并，两个取件码在同一行 | 分割逻辑或冲突检测 |
| **10** | **信息缺失** | Parser | 完全没有取件码 | 降级策略（需要用户补充） |
| **11** | **状态信号冲突** | 设计 | 文本既说"派送中"又说"待取件" | 冲突检测器在工作 |
| **12** | **图像格式问题** | OCR 配置 | 图像太小 / 太模糊 / 旋转 | 预处理或用户提示 |

---

## 按层级分类

### 📍 OCR 层错误（lib/platform/ocr/ + lib/core/ocr/ImagePreprocessor）

**症状：** OCR 输出的 raw text 就是错的

**修复方案：**
1. **后处理纠正** — `TextSanitizer` 中添加常见字符替换规则
2. **图像预处理** — `ImagePreprocessor` 调整对比度/亮度/旋转检测
3. **OCR 配置** — ML Kit 的识别参数调整
4. **降级反馈** — 告诉用户图像质量不足

**现有工具：**
- `lib/core/ocr/image_preprocessor.dart` — 图像处理
- `lib/platform/ocr/mlkit_ocr_adapter.dart` — ML Kit 调用
- `TextSanitizer.correctCommonTypos()` — 字符替换

---

### 📍 Parser 层错误（lib/core/parser/ + lib/core/sanitizer/）

**症状：** OCR 输出正确，但 Parser 提取错误

**修复方案：**
1. **增强提取器** — 改进 `CourierExtractor`, `PickupCodeExtractor` 等的正则和规则
2. **强化过滤器** — 改进 `TextSanitizer` 的噪音过滤
3. **冲突检测** — 改进 `ConflictDetector` 的逻辑
4. **优先级排序** — 调整 `_findExistingPackage()` 的匹配优先级

**现有工具：**
- `lib/core/parser/extractors.dart` — 六大提取器
- `lib/core/sanitizer/text_sanitizer.dart` — 噪音过滤
- `lib/app/ocr_pipeline.dart` — ConflictDetector
- `lib/ui/providers/package_provider.dart` — 去重逻辑

---

### 📍 设计层（不是 bug）

**症状：** 系统行为正确，只是不符合期望

**例：**
- 冲突检测器拒绝了模糊的信号 ✓ 设计如此
- 用户没有补充缺失的取件码 ✓ 需要用户操作
- 图像太模糊被拒绝 ✓ 需要更好的图像

**修复方案：** 改进用户提示或补充流程

---

## 错误根因清单

### 快速诊断：看哪一行失败了？

```
Image
  → [OCR 在这里] ← 极免 vs 极兔
    ↓
OCR Output: "极免 SF123456 15-3-6007"
  → [Parser 在这里] ← 派送中 vs 待取件, 地址污染
    ↓
ParseResult: { courier: 极兔, trackingNumber: SF123456, pickupCode: 15-3-6007 }
  → [去重在这里] ← 多包裹粘连, 冲突信号
    ↓
Package: { courier: 极兔, status: arrived, location: 自提柜 }
```

**每个阶段的常见错误：**

| 阶段 | 错误类型 | 症状 | 快速诊断 |
|------|---------|------|---------|
| **OCR 输入** | 图像质量 | 图太小/模糊/旋转 | 手动看图 |
| **OCR 输出** | 字符误识 | 文字错误 | 对比 OCR raw text vs 原图 |
| **Parser 提取** | 规则不符 | 取错字段 | 复制 raw text，手动提取，看 Parser 为啥拿不到 |
| **去重** | 优先级错 | 覆盖了对的包 | 查 `_findExistingPackage()` 匹配结果 |
| **冲突检测** | 规则过严 | 拒绝了有效信号 | 查 `ConflictDetector.analyze()` 输出 |

---

## 错误文件组织

```
test/fixtures/
├── errors/                  ← 错误分类库
│   ├── ocr_char_typo/       例：极免→极兔, 圓通→圆通
│   ├── ocr_line_drift/      例：两行合并，分割错误
│   ├── ocr_blur_noise/      例：模糊导致识别不清
│   ├── parser_status/       例：派送中→待取件
│   ├── parser_pickup_code/  例：随机数字被当码
│   ├── parser_address/      例：转运中心污染
│   ├── parser_ui_noise/     例：(待取件2) 的角标
│   ├── dedupe_collision/    例：两包裹粘连
│   └── missing_field/       例：没有取件码
│
├── real_world/              ← 真实样本（按来源）
│   ├── sf/, yt/, jd/, ...
│   └── [每个样本标注错误类型和根因]
│
├── good/                    ← 保持不变
├── bad/                     ← 保持不变
└── edge/                    ← 保持不变
```

---

## 记录错误的标准格式

每个错误样本应包含：

```
文件名: [快递公司]_[错误类型]_[编号].txt

内容:
---
OCR_OUTPUT:
极免 SF123456 15-3-6007 ...

EXPECTED:
courier: 极兔
trackingNumber: SF123456
pickupCode: 15-3-6007

ACTUAL:
courier: 极免  ← 错了
trackingNumber: SF123456
pickupCode: 15-3-6007

ERROR_TYPE: ocr_char_typo
ROOT_CAUSE: OCR 层 - 识别错误
PRIORITY: High (courier 字段关键)
FIX_LOCATION: TextSanitizer.correctCommonTypos() 或 OCR 后处理

METADATA:
- Source: 真实 SMS
- Timestamp: 2026-05-10
- Device: Android 13
- Image Quality: Good
---
```

---

## 优先级排序（修复顺序）

### 🔴 高优先级（立即修复）
- Courier 字段识别错（会导致包裹完全走错）
- Tracking number 与 courier 不匹配（去重会失败）
- 重复包裹冲突（用户会看到重复）

### 🟡 中优先级（下个迭代）
- Pickup code 误提（取件时有问题）
- Status 误判（通知时机错误）
- Address 污染（信息不准确但不影响主流程）

### 🟢 低优先级（可以延后）
- UI 角标污染（视觉问题）
- 信息缺失（用户可补充）
- Edge case（发生频率低）

---

## 使用方式

### 1. 发现错误时

```
不要立即改代码！

而是：
1. 复制 OCR raw text 和期望结果
2. 确定是 OCR 错还是 Parser 错（用决策树）
3. 创建测试文件到 test/fixtures/errors/[类型]/
4. 标注优先级和根因
5. 汇总到错误追踪表
```

### 2. 修复时

```
1. 确认错误根因（OCR vs Parser）
2. 找到对应的修复地点
3. 修改对应的模块
4. 把样本移到 test/fixtures/good/
5. 添加回归测试
```

### 3. 预防

```
定期审查：
- 同一根因是否重复出现？
- 修复后是否引入新 bug？
- real_world 样本中是否有遗漏的模式？
```

---

## 决策参考

| 问题 | 答案 |
|------|------|
| 看到 bug 了，现在应该怎么做？ | 先诊断（OCR vs Parser），再创建测试文件，再改代码 |
| 修复什么优先？ | Courier > TrackingNumber > PickupCode > Status > Address |
| 改 TextSanitizer 还是改 Extractors？ | 如果 OCR raw text 就错了 → Sanitizer；如果 text 对但提取错 → Extractors |
| 多包裹粘连怎么办？ | 看是 Parser 分割失败还是冲突检测有问题 → 标注后统计 |
| 信息缺失怎么办？ | 这通常不是 bug，而是需要用户补充或降级流程 |

