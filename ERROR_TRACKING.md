# 错误追踪表

当前发现的已知错误及其分类。

| ID | 快递商 | 错误类型 | 示例 | 根因 | 优先级 | 状态 | 修复地点 |
|----|-------|--------|------|------|-------|------|---------|
| E001 | 顺丰 | ocr_char_typo | 极免→极兔 | OCR 字符误识 | 🔴 High | 未处理 | TextSanitizer |
| E002 | 圆通 | ocr_char_typo | 圓通→圆通 | OCR 字符误识 | 🔴 High | 未处理 | TextSanitizer |
| E003 | 通用 | parser_status | 派送中→待取件 | 状态提取逻辑不严 | 🟡 Medium | 未处理 | StatusExtractor |
| E004 | 通用 | parser_address | 转运中心被识别成地址 | 噪音过滤规则缺失 | 🟡 Medium | 未处理 | TextSanitizer.filterLines() |
| E005 | 通用 | parser_ui_noise | (待取件2) 的 "2" | 正则包含了角标 | 🟢 Low | 未处理 | PickupCodeExtractor |
| E006 | 通用 | dedupe_collision | 两个取件码在同一行 | 分割逻辑或冲突 | 🟡 Medium | 未处理 | TextParser.parseMulti() |
| E007 | 通用 | missing_field | 没有取件码 | 设计限制（需用户补充） | 🟢 Low | N/A | 产品设计 |

---

## 记录新错误的步骤

1. **创建测试文件** → `test/fixtures/errors/[类型]/[快递商]_[编号].txt`

2. **填写内容** 按照标准格式（见 ERROR_CLASSIFICATION.md）

3. **更新此表** 添加一行记录

4. **关联测试** 如果已有回归测试，关联 test file

---

## 错误热力图（近期高频）

```
ocr_char_typo:      ▓▓▓▓▓ (5 cases)
parser_status:      ▓▓▓   (3 cases)
parser_address:     ▓▓    (2 cases)
parser_ui_noise:    ▓     (1 case)
dedupe_collision:   ▓     (1 case)
missing_field:      ▓     (1 case)
```

---

## 按根因分组

### OCR 层（5 cases）
- E001, E002, E003?, ...

### Parser 层（6 cases）
- E003, E004, E005, E006, ...

### 设计/产品（1 case）
- E007

