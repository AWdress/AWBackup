#!/bin/bash
# ============================================
# AWBackup - 恢复脚本
# ============================================
# 用于从备份中恢复文件
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  备份恢复工具${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# 显示用法
show_usage() {
    echo "用法: $0 [选项] <备份文件> <恢复目标>"
    echo ""
    echo "选项:"
    echo "  -l, --list            只列出备份内容，不恢复"
    echo "  -v, --verify          验证备份完整性"
    echo "  -f, --force           强制覆盖已存在的文件"
    echo "  -e, --extract PATH    只恢复指定路径"
    echo "  -h, --help            显示此帮助"
    echo ""
    echo "示例:"
    echo "  $0 -l backup.tar.gz"
    echo "  $0 backup.tar.gz /mnt/user/restore"
    echo "  $0 -e 'documents/important' backup.tar.gz /mnt/user/restore"
    echo ""
}

# 列出备份内容
list_backup() {
    local backup_file=$1
    
    if [[ ! -f "${backup_file}" ]]; then
        echo -e "${RED}错误: 备份文件不存在: ${backup_file}${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}备份文件: ${backup_file}${NC}"
    echo ""
    
    # 显示文件信息
    local file_size=$(du -h "${backup_file}" | awk '{print $1}')
    local file_date=$(date -r "${backup_file}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知")
    
    echo -e "大小: ${file_size}"
    echo -e "日期: ${file_date}"
    echo ""
    echo -e "${BLUE}内容列表:${NC}"
    echo ""
    
    tar -tzf "${backup_file}" | head -50
    
    local total_files=$(tar -tzf "${backup_file}" | wc -l)
    echo ""
    echo -e "总文件数: ${total_files}"
    
    if [[ ${total_files} -gt 50 ]]; then
        echo -e "${YELLOW}(仅显示前50个文件)${NC}"
    fi
}

# 验证备份
verify_backup() {
    local backup_file=$1
    
    echo -e "${BLUE}验证备份完整性...${NC}"
    
    if [[ ! -f "${backup_file}" ]]; then
        echo -e "${RED}错误: 备份文件不存在: ${backup_file}${NC}"
        return 1
    fi
    
    if tar -tzf "${backup_file}" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 备份文件完整性验证通过${NC}"
        return 0
    else
        echo -e "${RED}✗ 备份文件已损坏${NC}"
        return 1
    fi
}

# 恢复备份
restore_backup() {
    local backup_file=$1
    local restore_path=$2
    local extract_path=${3:-}
    local force=${4:-false}
    
    echo -e "${BLUE}开始恢复...${NC}"
    echo ""
    
    # 检查备份文件
    if [[ ! -f "${backup_file}" ]]; then
        echo -e "${RED}错误: 备份文件不存在: ${backup_file}${NC}"
        exit 1
    fi
    
    # 验证备份
    if ! verify_backup "${backup_file}"; then
        exit 1
    fi
    
    # 创建恢复目标目录
    if [[ ! -d "${restore_path}" ]]; then
        echo -e "${YELLOW}创建目标目录: ${restore_path}${NC}"
        mkdir -p "${restore_path}"
    fi
    
    # 检查目标目录是否为空
    if [[ "${force}" != "true" ]] && [[ -n "$(ls -A "${restore_path}" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}警告: 目标目录不为空${NC}"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}已取消恢复${NC}"
            exit 0
        fi
    fi
    
    # 恢复文件
    echo -e "备份文件: ${backup_file}"
    echo -e "恢复目标: ${restore_path}"
    if [[ -n "${extract_path}" ]]; then
        echo -e "指定路径: ${extract_path}"
    fi
    echo ""
    
    read -p "确认开始恢复? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}已取消恢复${NC}"
        exit 0
    fi
    
    echo ""
    echo -e "${BLUE}正在恢复...${NC}"
    
    local start_time=$(date +%s)
    
    if [[ -n "${extract_path}" ]]; then
        # 恢复指定路径
        tar -xzf "${backup_file}" -C "${restore_path}" "${extract_path}" 2>&1
    else
        # 恢复全部
        tar -xzf "${backup_file}" -C "${restore_path}" 2>&1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo -e "${GREEN}✓ 恢复完成！${NC}"
    echo -e "耗时: ${duration} 秒"
    echo ""
    
    # 显示恢复的文件统计
    local restored_files=$(find "${restore_path}" -type f | wc -l)
    local restored_size=$(du -sh "${restore_path}" | awk '{print $1}')
    
    echo -e "恢复文件数: ${restored_files}"
    echo -e "恢复数据量: ${restored_size}"
}

# 交互式恢复
interactive_restore() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_file="${script_dir}/config.conf"
    
    if [[ ! -f "${config_file}" ]]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        exit 1
    fi
    
    source "${config_file}"
    
    echo -e "${BLUE}可用的备份任务:${NC}"
    echo ""
    
    local i=1
    local task_list=()
    
    for task in ${BACKUP_TASKS}; do
        local task_upper=$(echo "${task}" | tr '[:lower:]' '[:upper:]')
        local dest_var="${task_upper}_DESTINATION"
        local name_var="${task_upper}_NAME"
        local dest_dir="${!dest_var:-}"
        local task_name="${!name_var:-${task}}"
        
        if [[ -z "${dest_dir}" ]] || [[ ! -d "${dest_dir}" ]]; then
            continue
        fi
        
        task_list+=("${task}:${dest_dir}")
        echo -e "  ${i}) ${task_name} (${dest_dir})"
        ((i++))
    done
    
    echo ""
    read -p "选择任务 [1-$((i-1))]: " choice
    
    if [[ ${choice} -lt 1 ]] || [[ ${choice} -ge ${i} ]]; then
        echo -e "${RED}无效选择${NC}"
        exit 1
    fi
    
    local selected=${task_list[$((choice-1))]}
    local task_name=$(echo "${selected}" | cut -d: -f1)
    local backup_dir=$(echo "${selected}" | cut -d: -f2)
    
    echo ""
    echo -e "${BLUE}可用的备份文件:${NC}"
    echo ""
    
    local backups=($(find "${backup_dir}" -name "*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk '{print $2}'))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${YELLOW}未找到备份文件${NC}"
        exit 0
    fi
    
    for i in "${!backups[@]}"; do
        local file="${backups[$i]}"
        local file_name=$(basename "${file}")
        local file_size=$(du -h "${file}" | awk '{print $1}')
        local file_date=$(date -r "${file}" '+%Y-%m-%d %H:%M:%S')
        
        echo -e "  $((i+1))) ${file_name}"
        echo -e "      大小: ${file_size}, 日期: ${file_date}"
    done
    
    echo ""
    read -p "选择备份文件 [1-${#backups[@]}]: " backup_choice
    
    if [[ ${backup_choice} -lt 1 ]] || [[ ${backup_choice} -gt ${#backups[@]} ]]; then
        echo -e "${RED}无效选择${NC}"
        exit 1
    fi
    
    local selected_backup="${backups[$((backup_choice-1))]}"
    
    echo ""
    read -p "恢复目标路径: " restore_path
    
    if [[ -z "${restore_path}" ]]; then
        echo -e "${RED}错误: 必须指定恢复路径${NC}"
        exit 1
    fi
    
    echo ""
    restore_backup "${selected_backup}" "${restore_path}"
}

# ============================================
# 主函数
# ============================================

main() {
    local list_only=false
    local verify_only=false
    local force=false
    local extract_path=""
    local backup_file=""
    local restore_path=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--list)
                list_only=true
                shift
                ;;
            -v|--verify)
                verify_only=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -e|--extract)
                extract_path="$2"
                shift 2
                ;;
            -i|--interactive)
                interactive_restore
                exit 0
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo -e "${RED}未知选项: $1${NC}"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "${backup_file}" ]]; then
                    backup_file="$1"
                elif [[ -z "${restore_path}" ]]; then
                    restore_path="$1"
                fi
                shift
                ;;
        esac
    done
    
    # 如果没有参数，进入交互式模式
    if [[ -z "${backup_file}" ]]; then
        interactive_restore
        exit 0
    fi
    
    # 列出备份内容
    if [[ "${list_only}" == "true" ]]; then
        list_backup "${backup_file}"
        exit 0
    fi
    
    # 验证备份
    if [[ "${verify_only}" == "true" ]]; then
        verify_backup "${backup_file}"
        exit 0
    fi
    
    # 恢复备份
    if [[ -z "${restore_path}" ]]; then
        echo -e "${RED}错误: 必须指定恢复目标路径${NC}"
        show_usage
        exit 1
    fi
    
    restore_backup "${backup_file}" "${restore_path}" "${extract_path}" "${force}"
}

# 执行主函数
main "$@"

