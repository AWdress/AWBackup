#!/bin/bash
# 临时测试脚本 - 用于调试备份问题

echo "=== AWBackup 诊断脚本 ==="
echo ""
echo "1. 检查配置文件:"
if [ -f /app/config.conf ]; then
    echo "   ✓ /app/config.conf 存在"
    echo "   文件大小: $(wc -l < /app/config.conf) 行"
else
    echo "   ✗ /app/config.conf 不存在"
fi

if [ -f /tmp/config.conf.tmp ]; then
    echo "   ✓ /tmp/config.conf.tmp 存在"
    echo "   文件大小: $(wc -l < /tmp/config.conf.tmp) 行"
else
    echo "   ✗ /tmp/config.conf.tmp 不存在"
fi

echo ""
echo "2. 环境变量:"
echo "   CONFIG_FILE=${CONFIG_FILE:-未设置}"

echo ""
echo "3. 尝试加载配置:"
if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
    echo "   ✓ 使用: ${CONFIG_FILE}"
    source "${CONFIG_FILE}" 2>&1 | head -5
    echo "   BACKUP_TASKS=${BACKUP_TASKS:-未定义}"
else
    echo "   ✗ CONFIG_FILE 未设置或文件不存在"
fi

echo ""
echo "4. 检查备份任务配置:"
echo "   BACKUP_TASKS=${BACKUP_TASKS:-未定义}"

if [ -n "${BACKUP_TASKS}" ]; then
    for task in $BACKUP_TASKS; do
        task_upper=$(echo "$task" | tr '[:lower:]' '[:upper:]')
        source_var="${task_upper}_SOURCE"
        dest_var="${task_upper}_DESTINATION"
        enabled_var="${task_upper}_ENABLED"
        
        echo ""
        echo "   任务: $task"
        echo "     源目录: ${!source_var:-未定义}"
        echo "     目标目录: ${!dest_var:-未定义}"
        echo "     启用状态: ${!enabled_var:-未定义}"
        
        if [ -d "${!source_var}" ]; then
            echo "     ✓ 源目录存在"
        else
            echo "     ✗ 源目录不存在: ${!source_var}"
        fi
        
        if [ -d "${!dest_var}" ]; then
            echo "     ✓ 目标目录存在"
        else
            echo "     ✗ 目标目录不存在: ${!dest_var}"
        fi
    done
fi

echo ""
echo "5. 磁盘空间:"
df -h | grep -E "(Filesystem|/backups|/data)"

echo ""
echo "6. 目录权限:"
ls -ld /app /backups /data 2>/dev/null || echo "   某些目录不存在"

echo ""
echo "=== 诊断完成 ==="

