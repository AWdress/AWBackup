#!/bin/bash
# ============================================
# AWBackup - 卸载脚本
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  AWBackup - 卸载程序${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

echo -e "${YELLOW}警告: 此操作将卸载备份工具${NC}"
echo ""
echo "将执行以下操作:"
echo "  - 删除 cron 定时任务"
echo "  - 保留备份文件"
echo "  - 保留日志文件"
echo "  - 保留配置文件"
echo ""
read -p "是否继续? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}已取消卸载${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}开始卸载...${NC}"
echo ""

# 删除 cron 任务
echo -e "${BLUE}[1/3]${NC} 删除定时任务..."
if crontab -l 2>/dev/null | grep -q "${BACKUP_SCRIPT}"; then
    crontab -l 2>/dev/null | grep -v "${BACKUP_SCRIPT}" | crontab -
    echo -e "${GREEN}✓ 已删除定时任务${NC}"
else
    echo -e "${YELLOW}未找到定时任务${NC}"
fi

# 询问是否删除日志
echo ""
echo -e "${BLUE}[2/3]${NC} 日志文件处理..."
if [[ -d "${SCRIPT_DIR}/logs" ]]; then
    log_size=$(du -sh "${SCRIPT_DIR}/logs" | awk '{print $1}')
    echo -e "日志目录: ${SCRIPT_DIR}/logs (${log_size})"
    read -p "是否删除日志文件? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "${SCRIPT_DIR}/logs"
        echo -e "${GREEN}✓ 已删除日志文件${NC}"
    else
        echo -e "${BLUE}保留日志文件${NC}"
    fi
else
    echo -e "${YELLOW}未找到日志目录${NC}"
fi

# 询问是否删除配置
echo ""
echo -e "${BLUE}[3/3]${NC} 配置文件处理..."
if [[ -f "${SCRIPT_DIR}/config.conf" ]]; then
    read -p "是否删除配置文件? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "${SCRIPT_DIR}/config.conf"
        echo -e "${GREEN}✓ 已删除配置文件${NC}"
    else
        echo -e "${BLUE}保留配置文件${NC}"
    fi
else
    echo -e "${YELLOW}未找到配置文件${NC}"
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  卸载完成！${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}备注:${NC}"
echo -e "- 备份文件已保留在原位置"
echo -e "- 如需删除备份文件，请手动删除"
echo -e "- 可以随时重新运行 install.sh 重新安装"
echo ""
echo -e "${YELLOW}如需完全删除项目:${NC}"
echo -e "  rm -rf ${SCRIPT_DIR}"
echo ""

