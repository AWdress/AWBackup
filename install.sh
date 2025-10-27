#!/bin/bash
# ============================================
# AWBackup - 安装脚本
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
CONFIG_FILE="${SCRIPT_DIR}/config.conf"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  AWBackup - 安装程序${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# 检查是否在 Unraid 环境
if [[ ! -f /etc/unraid-version ]]; then
    echo -e "${YELLOW}警告: 未检测到 Unraid 系统${NC}"
    echo -e "${YELLOW}本工具专为 Unraid 设计，但也可在其他 Linux 系统使用${NC}"
    echo ""
fi

# 步骤1: 检查必需命令
echo -e "${BLUE}[1/6]${NC} 检查系统环境..."
required_commands=("tar" "bash" "cron" "du" "df")
missing_commands=()

for cmd in "${required_commands[@]}"; do
    if ! command -v ${cmd} &> /dev/null; then
        missing_commands+=("${cmd}")
    fi
done

if [[ ${#missing_commands[@]} -gt 0 ]]; then
    echo -e "${RED}错误: 以下必需命令未找到:${NC}"
    printf '  - %s\n' "${missing_commands[@]}"
    exit 1
fi
echo -e "${GREEN}✓ 系统环境检查通过${NC}"

# 步骤2: 创建配置文件
echo -e "${BLUE}[2/6]${NC} 配置文件设置..."
if [[ -f "${CONFIG_FILE}" ]]; then
    echo -e "${YELLOW}配置文件已存在: ${CONFIG_FILE}${NC}"
    read -p "是否要备份现有配置并创建新的? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        backup_config="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "${CONFIG_FILE}" "${backup_config}"
        echo -e "${GREEN}✓ 已备份到: ${backup_config}${NC}"
        cp "${SCRIPT_DIR}/examples/config.example.conf" "${CONFIG_FILE}"
        echo -e "${GREEN}✓ 已创建新配置文件${NC}"
    else
        echo -e "${BLUE}保留现有配置文件${NC}"
    fi
else
    if [[ -f "${SCRIPT_DIR}/examples/config.example.conf" ]]; then
        cp "${SCRIPT_DIR}/examples/config.example.conf" "${CONFIG_FILE}"
        echo -e "${GREEN}✓ 已从示例创建配置文件${NC}"
    else
        echo -e "${RED}错误: 找不到示例配置文件${NC}"
        exit 1
    fi
fi

# 步骤3: 设置执行权限
echo -e "${BLUE}[3/6]${NC} 设置文件权限..."
chmod +x "${BACKUP_SCRIPT}"
chmod +x "${SCRIPT_DIR}/uninstall.sh"
chmod 644 "${CONFIG_FILE}"
echo -e "${GREEN}✓ 文件权限设置完成${NC}"

# 步骤4: 创建日志目录
echo -e "${BLUE}[4/6]${NC} 创建日志目录..."
mkdir -p "${SCRIPT_DIR}/logs"
echo -e "${GREEN}✓ 日志目录已创建${NC}"

# 步骤5: 配置 cron 定时任务
echo -e "${BLUE}[5/6]${NC} 配置定时任务..."
echo ""
echo "请选择备份频率:"
echo "  1) 每天凌晨 2:00 (推荐)"
echo "  2) 每天凌晨 3:00"
echo "  3) 每 12 小时一次"
echo "  4) 每周日凌晨 2:00"
echo "  5) 自定义 cron 表达式"
echo "  6) 跳过（手动配置）"
echo ""
read -p "请选择 [1-6]: " choice

cron_expression=""
case ${choice} in
    1)
        cron_expression="0 2 * * *"
        ;;
    2)
        cron_expression="0 3 * * *"
        ;;
    3)
        cron_expression="0 */12 * * *"
        ;;
    4)
        cron_expression="0 2 * * 0"
        ;;
    5)
        echo ""
        echo "Cron 表达式格式: 分 时 日 月 周"
        echo "示例: 0 2 * * * (每天凌晨2点)"
        read -p "请输入 cron 表达式: " cron_expression
        ;;
    6)
        echo -e "${YELLOW}已跳过定时任务配置${NC}"
        cron_expression=""
        ;;
    *)
        echo -e "${YELLOW}无效选择，使用默认值（每天凌晨2点）${NC}"
        cron_expression="0 2 * * *"
        ;;
esac

if [[ -n "${cron_expression}" ]]; then
    # 检查是否已存在相同的 cron 任务
    if crontab -l 2>/dev/null | grep -q "${BACKUP_SCRIPT}"; then
        echo -e "${YELLOW}检测到已存在的定时任务${NC}"
        read -p "是否要更新? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 删除旧任务
            crontab -l 2>/dev/null | grep -v "${BACKUP_SCRIPT}" | crontab -
            echo -e "${GREEN}✓ 已删除旧任务${NC}"
        else
            echo -e "${BLUE}保留现有定时任务${NC}"
            cron_expression=""
        fi
    fi
    
    if [[ -n "${cron_expression}" ]]; then
        # 添加新任务
        (crontab -l 2>/dev/null; echo "${cron_expression} ${BACKUP_SCRIPT} >> ${SCRIPT_DIR}/logs/cron.log 2>&1") | crontab -
        echo -e "${GREEN}✓ 定时任务已添加: ${cron_expression}${NC}"
        
        # 检查 cron 服务状态
        if [[ -f /etc/rc.d/rc.crond ]]; then
            if ! /etc/rc.d/rc.crond status &>/dev/null; then
                echo -e "${YELLOW}Cron 服务未运行，正在启动...${NC}"
                /etc/rc.d/rc.crond start
            fi
            echo -e "${GREEN}✓ Cron 服务运行正常${NC}"
        fi
    fi
else
    echo -e "${BLUE}请稍后手动配置 cron 任务:${NC}"
    echo -e "  crontab -e"
    echo -e "  添加: 0 2 * * * ${BACKUP_SCRIPT}"
fi

# 步骤6: 测试配置
echo ""
echo -e "${BLUE}[6/6]${NC} 验证安装..."

# 检查配置文件语法
if bash -n "${CONFIG_FILE}" 2>/dev/null; then
    echo -e "${GREEN}✓ 配置文件语法正确${NC}"
else
    echo -e "${RED}✗ 配置文件语法错误，请检查${NC}"
fi

# 检查备份脚本
if bash -n "${BACKUP_SCRIPT}" 2>/dev/null; then
    echo -e "${GREEN}✓ 备份脚本语法正确${NC}"
else
    echo -e "${RED}✗ 备份脚本语法错误${NC}"
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  安装完成！${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}下一步操作:${NC}"
echo ""
echo -e "1. 编辑配置文件:"
echo -e "   ${YELLOW}nano ${CONFIG_FILE}${NC}"
echo ""
echo -e "2. 配置你的备份任务:"
echo -e "   - 设置源目录 (SOURCE)"
echo -e "   - 设置目标目录 (DESTINATION)"
echo -e "   - 设置保留天数 (RETENTION_DAYS)"
echo ""
echo -e "3. 测试运行备份:"
echo -e "   ${YELLOW}${BACKUP_SCRIPT}${NC}"
echo ""
echo -e "4. 查看日志:"
echo -e "   ${YELLOW}tail -f ${SCRIPT_DIR}/logs/backup_\$(date +%Y%m%d).log${NC}"
echo ""
echo -e "5. 查看定时任务:"
echo -e "   ${YELLOW}crontab -l${NC}"
echo ""
echo -e "${BLUE}提示:${NC}"
echo -e "- 首次运行建议使用测试目录验证配置"
echo -e "- 确保目标磁盘有足够空间"
echo -e "- 定期检查日志确保备份正常"
echo ""
echo -e "${BLUE}文档: ${SCRIPT_DIR}/README.md${NC}"
echo ""

