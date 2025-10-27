#!/bin/bash
# 验证所有脚本的语法

echo "验证脚本语法..."
echo ""

ERRORS=0

for script in backup.sh cleanup.sh restore.sh tg_bot.sh test_full_backup.sh; do
    if [ -f "$script" ]; then
        echo -n "检查 $script ... "
        if bash -n "$script" 2>&1; then
            echo "✓ 语法正确"
        else
            echo "✗ 语法错误"
            ((ERRORS++))
        fi
    else
        echo "- $script 不存在"
    fi
done

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✓ 所有脚本语法检查通过"
    exit 0
else
    echo "✗ 发现 $ERRORS 个语法错误"
    exit 1
fi

