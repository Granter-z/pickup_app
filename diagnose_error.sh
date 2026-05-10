#!/bin/bash

# 错误诊断脚本模板
# 使用方式: bash diagnose_error.sh "ocr_raw_text.txt"

OCR_FILE="${1:-}"

if [ -z "$OCR_FILE" ]; then
    echo "❌ 使用方式: bash diagnose_error.sh <ocr_raw_text_file>"
    echo ""
    echo "示例: bash diagnose_error.sh ocr_output.txt"
    exit 1
fi

if [ ! -f "$OCR_FILE" ]; then
    echo "❌ 文件不存在: $OCR_FILE"
    exit 1
fi

echo "=========================================="
echo "🔍 错误诊断流程"
echo "=========================================="
echo ""
echo "📄 OCR Raw Text:"
cat "$OCR_FILE"
echo ""
echo "=========================================="
echo ""

# 问题 1
echo "❓ 问题 1: OCR 输出的文本看起来对吗？"
echo "   比对原图，检查：字符是否正确、行是否分割正确、是否有乱码"
echo ""
read -p "   [y/n] 文本看起来对吗？ > " ocr_ok

if [ "$ocr_ok" != "y" ]; then
    echo ""
    echo "✅ 诊断结果: 📍 OCR 层错误"
    echo ""
    echo "错误类型可能是："
    echo "  • ocr_char_typo    - 字符误识（如 极免→极兔）"
    echo "  • ocr_line_drift   - 行分割错误"
    echo "  • ocr_blur_noise   - 模糊/噪音导致识别失败"
    echo ""
    echo "修复地点："
    echo "  1. lib/core/ocr/image_preprocessor.dart      - 图像预处理"
    echo "  2. lib/platform/ocr/mlkit_ocr_adapter.dart   - ML Kit 配置"
    echo "  3. lib/core/sanitizer/text_sanitizer.dart    - 后处理纠正"
    echo ""
    exit 0
fi

# 问题 2
echo ""
echo "❓ 问题 2: Parser 能从这行文本正确提取吗？"
echo "   手动提取：找出 courier, tracking_number, pickup_code, location, status"
echo ""
read -p "   [y/n] Parser 应该能提取吗？ > " parser_ok

if [ "$parser_ok" != "y" ]; then
    echo ""
    echo "✅ 诊断结果: 📍 Parser 层错误"
    echo ""
    echo "错误类型可能是："
    echo "  • parser_status        - 状态提取错误（派送中→待取件）"
    echo "  • parser_pickup_code   - 取件码误提（随机数字被当码）"
    echo "  • parser_address       - 地址污染（转运中心被识别成地址）"
    echo "  • parser_ui_noise      - UI 角标污染（(待取件2) 的 2）"
    echo "  • dedupe_collision     - 多包裹粘连（分割问题）"
    echo ""
    echo "修复地点："
    echo "  1. lib/core/parser/extractors.dart              - 各提取器的正则和规则"
    echo "  2. lib/core/sanitizer/text_sanitizer.dart      - 噪音过滤规则"
    echo "  3. lib/app/ocr_pipeline.dart                   - 冲突检测逻辑"
    echo "  4. lib/ui/providers/package_provider.dart      - 去重优先级"
    echo ""
    exit 0
fi

echo ""
echo "✅ 诊断结果: ✓ 不是错误"
echo ""
echo "可能的原因："
echo "  1. 冲突检测器拒绝了模糊信号（设计如此）"
echo "  2. 信息缺失，需要用户补充（产品流程）"
echo "  3. 这只是一条低优先级的信息（可以忽略）"
echo ""
