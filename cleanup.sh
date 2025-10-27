#!/bin/bash
# ============================================
# AWBackup - 清理脚本
# ============================================
# 用于手动清理旧备份和日志
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

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  备份清理工具${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# 显示用法
show_usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -b, --backups DAYS    清理超过指定天数的备份文件"
    echo "  -l, --logs DAYS       清理超过指定天数的日志文件"
    echo "  -a, --all DAYS        清理所有超过指定天数的文件"
    echo "  -d, --dry-run         模拟运行，不实际删除"
    echo "  -i, --interactive     交互式清理"
    echo "  -h, --help            显示此帮助"
    echo ""
    echo "示例:"
    echo "  $0 -b 7               # 清理7天前的备份"
    echo "  $0 -l 30              # 清理30天前的日志"
    echo "  $0 -a 14 -d           # 模拟清理14天前的所有文件"
    echo "  $0 -i                 # 交互式清理"
    echo ""
}

# 清理旧备份
cleanup_backups() {
    local days=$1
    local dry_run=${2:-false}
    
    echo -e "${BLUE}清理超过 ${days} 天的备份文件...${NC}"
    echo ""
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        return 1
    fi
    
    source "${CONFIG_FILE}"
    
    local total_deleted=0
    local total_size=0
    
    for task in ${BACKUP_TASKS}; do
        local task_upper=$(echo "${task}" | tr '[:lower:]' '[:upper:]')
        local dest_var="${task_upper}_DESTINATION"
        local dest_dir="${!dest_var:-}"
        
        if [[ -z "${dest_dir}" ]] || [[ ! -d "${dest_dir}" ]]; then
            continue
        fi
        
        echo -e "${YELLOW}任务: ${task}${NC}"
        echo -e "目录: ${dest_dir}"
        
        local count=0
        local size=0
        
        while IFS= read -r -d '' file; do
            local file_size=$(stat -f%z "${file}" 2>/dev/null || stat -c%s "${file}" 2>/dev/null || echo 0)
            local file_name=$(basename "${file}")
            local file_date=$(date -r "${file}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知")
            local file_size_human=$(du -h "${file}" | awk '{print $1}')
            
            echo -e "  ${RED}✗${NC} ${file_name} (${file_size_human}, ${file_date})"
            
            if [[ "${dry_run}" != "true" ]]; then
                rm -f "${file}"
            fi
            
            ((count++))
            ((size+=file_size))
        done < <(find "${dest_dir}" -name "*.tar.gz" -type f -mtime +${days} -print0 2>/dev/null)
        
        if [[ ${count} -eq 0 ]]; then
            echo -e "  ${GREEN}无需清理${NC}"
        else
            local size_mb=$((size / 1024 / 1024))
            echo -e "  ${GREEN}清理: ${count} 个文件, ${size_mb} MB${NC}"
            ((total_deleted+=count))
            ((total_size+=size))
        fi
        echo ""
    done
    
    local total_size_mb=$((total_size / 1024 / 1024))
    echo -e "${GREEN}总计清理: ${total_deleted} 个备份文件, ${total_size_mb} MB${NC}"
    
    if [[ "${dry_run}" == "true" ]]; then
        echo -e "${YELLOW}(模拟运行，未实际删除)${NC}"
    fi
}

# 清理旧日志
cleanup_logs() {
    local days=$1
    local dry_run=${2:-false}
    
    echo -e "${BLUE}清理超过 ${days} 天的日志文件...${NC}"
    echo ""
    
    local log_dir="${SCRIPT_DIR}/logs"
    
    if [[ ! -d "${log_dir}" ]]; then
        echo -e "${YELLOW}日志目录不存在${NC}"
        return 0
    fi
    
    local count=0
    local size=0
    
    while IFS= read -r -d '' file; do
        local file_size=$(stat -f%z "${file}" 2>/dev/null || stat -c%s "${file}" 2>/dev/null || echo 0)
        local file_name=$(basename "${file}")
        local file_date=$(date -r "${file}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知")
        
        echo -e "  ${RED}✗${NC} ${file_name} (${file_date})"
        
        if [[ "${dry_run}" != "true" ]]; then
            rm -f "${file}"
        fi
        
        ((count++))
        ((size+=file_size))
    done < <(find "${log_dir}" -name "*.log" -type f -mtime +${days} -print0 2>/dev/null)
    
    if [[ ${count} -eq 0 ]]; then
        echo -e "${GREEN}无需清理${NC}"
    else
        local size_mb=$((size / 1024 / 1024))
        echo -e "${GREEN}清理: ${count} 个日志文件, ${size_mb} MB${NC}"
    fi
    
    if [[ "${dry_run}" == "true" ]]; then
        echo -e "${YELLOW}(模拟运行，未实际删除)${NC}"
    fi
}

# 交互式清理
interactive_cleanup() {
    echo -e "${BLUE}交互式清理模式${NC}"
    echo ""
    
    # 清理备份
    read -p "是否清理旧备份? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "保留最近多少天的备份? [7]: " backup_days
        backup_days=${backup_days:-7}
        echo ""
        cleanup_backups ${backup_days} false
    fi
    
    echo ""
    
    # 清理日志
    read -p "是否清理旧日志? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "保留最近多少天的日志? [30]: " log_days
        log_days=${log_days:-30}
        echo ""
        cleanup_logs ${log_days} false
    fi
}

# 显示统计信息
show_stats() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  存储空间统计${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        return 1
    fi
    
    source "${CONFIG_FILE}"
    
    echo -e "${YELLOW}备份目录:${NC}"
    for task in ${BACKUP_TASKS}; do
        local task_upper=$(echo "${task}" | tr '[:lower:]' '[:upper:]')
        local dest_var="${task_upper}_DESTINATION"
        local name_var="${task_upper}_NAME"
        local dest_dir="${!dest_var:-}"
        local task_name="${!name_var:-${task}}"
        
        if [[ -z "${dest_dir}" ]] || [[ ! -d "${dest_dir}" ]]; then
            continue
        fi
        
        local file_count=$(find "${dest_dir}" -name "*.tar.gz" -type f 2>/dev/null | wc -l)
        local total_size=$(du -sh "${dest_dir}" 2>/dev/null | awk '{print $1}')
        local oldest=$(find "${dest_dir}" -name "*.tar.gz" -type f -printf '%T+ %p\n' 2>/dev/null | sort | head -1 | awk '{print $1}')
        local newest=$(find "${dest_dir}" -name "*.tar.gz" -type f -printf '%T+ %p\n' 2>/dev/null | sort | tail -1 | awk '{print $1}')
        
        echo -e "  ${BLUE}${task_name}${NC}"
        echo -e "    路径: ${dest_dir}"
        echo -e "    文件数: ${file_count}"
        echo -e "    总大小: ${total_size}"
        if [[ -n "${oldest}" ]]; then
            echo -e "    最早: ${oldest}"
            echo -e "    最新: ${newest}"
        fi
        echo ""
    done
    
    echo -e "${YELLOW}日志目录:${NC}"
    local log_dir="${SCRIPT_DIR}/logs"
    if [[ -d "${log_dir}" ]]; then
        local log_count=$(find "${log_dir}" -name "*.log" -type f 2>/dev/null | wc -l)
        local log_size=$(du -sh "${log_dir}" 2>/dev/null | awk '{print $1}')
        echo -e "  路径: ${log_dir}"
        echo -e "  文件数: ${log_count}"
        echo -e "  总大小: ${log_size}"
    else
        echo -e "  ${YELLOW}日志目录不存在${NC}"
    fi
    echo ""
}

# ============================================
# 主函数
# ============================================

main() {
    local cleanup_type=""
    local days=0
    local dry_run=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--backups)
                cleanup_type="backups"
                days="$2"
                shift 2
                ;;
            -l|--logs)
                cleanup_type="logs"
                days="$2"
                shift 2
                ;;
            -a|--all)
                cleanup_type="all"
                days="$2"
                shift 2
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -i|--interactive)
                cleanup_type="interactive"
                shift
                ;;
            -s|--stats)
                show_stats
                exit 0
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 如果没有参数，显示统计和交互式选项
    if [[ -z "${cleanup_type}" ]]; then
        show_stats
        echo ""
        read -p "是否进入交互式清理? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            interactive_cleanup
        fi
        exit 0
    fi
    
    # 执行清理
    case ${cleanup_type} in
        backups)
            cleanup_backups ${days} ${dry_run}
            ;;
        logs)
            cleanup_logs ${days} ${dry_run}
            ;;
        all)
            cleanup_backups ${days} ${dry_run}
            echo ""
            cleanup_logs ${days} ${dry_run}
            ;;
        interactive)
            interactive_cleanup
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}清理完成！${NC}"
}

# 执行主函数
main "$@"

