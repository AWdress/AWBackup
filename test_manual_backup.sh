#!/bin/bash
# 手动测试备份脚本 - 添加详细调试输出

echo "=========================================="
echo "手动测试备份"
echo "时间: $(date)"
echo "=========================================="

# 显示环境
echo ""
echo "1. 当前环境:"
echo "   PWD: $(pwd)"
echo "   USER: $(whoami)"
echo "   CONFIG_FILE: ${CONFIG_FILE:-未设置}"

# 检查配置文件
echo ""
echo "2. 配置文件检查:"
if [ -f /tmp/config.conf.tmp ]; then
    echo "   ✓ /tmp/config.conf.tmp 存在"
    CONFIG_TO_USE="/tmp/config.conf.tmp"
elif [ -f /app/config.conf ]; then
    echo "   ✓ /app/config.conf 存在"
    CONFIG_TO_USE="/app/config.conf"
else
    echo "   ✗ 配置文件不存在"
    exit 1
fi

echo "   使用配置: $CONFIG_TO_USE"
echo "   文件大小: $(wc -l < $CONFIG_TO_USE) 行"

# 尝试加载配置（不使用 set -u）
echo ""
echo "3. 加载配置（宽松模式）:"
if source "$CONFIG_TO_USE" 2>&1; then
    echo "   ✓ 配置加载成功"
else
    echo "   ✗ 配置加载失败"
    exit 1
fi

# 显示关键配置
echo ""
echo "4. 关键配置项:"
echo "   BACKUP_TASKS: ${BACKUP_TASKS:-未定义}"
echo "   LOG_DIR: ${LOG_DIR:-未定义}"
echo "   ENABLE_TELEGRAM: ${ENABLE_TELEGRAM:-未定义}"

# 检查任务配置
if [ -n "${BACKUP_TASKS:-}" ]; then
    for task in $BACKUP_TASKS; do
        task_upper=$(echo "$task" | tr '[:lower:]' '[:upper:]')
        echo ""
        echo "5. 任务配置 [$task]:"
        
        eval source_var="\${${task_upper}_SOURCE:-未定义}"
        eval dest_var="\${${task_upper}_DESTINATION:-未定义}"
        eval enabled_var="\${${task_upper}_ENABLED:-未定义}"
        
        echo "   源目录: $source_var"
        echo "   目标目录: $dest_var"
        echo "   启用: $enabled_var"
        
        # 检查目录
        if [ -d "$source_var" ]; then
            echo "   ✓ 源目录存在"
            echo "   源目录内容:"
            ls -lh "$source_var" | head -10
        else
            echo "   ✗ 源目录不存在: $source_var"
        fi
        
        if [ -d "$dest_var" ]; then
            echo "   ✓ 目标目录存在"
        else
            echo "   ✗ 目标目录不存在: $dest_var"
        fi
    done
fi

# 现在尝试用严格模式加载
echo ""
echo "6. 尝试严格模式加载（set -u）:"
(
    set -u
    source "$CONFIG_TO_USE" 2>&1
    echo "   ✓ 严格模式加载成功"
) || {
    echo "   ✗ 严格模式加载失败（有未定义的变量）"
    echo ""
    echo "   尝试找出未定义的变量..."
    set -u
    source "$CONFIG_TO_USE"
}

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="

