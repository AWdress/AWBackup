#!/bin/bash
# ============================================
# AWBackup - 主脚本
# ============================================
# 版本: 1.0.0
# 作者: AWBackup
# 描述: 自动压缩备份文件夹到指定目录
# ============================================

set -e  # 遇到错误时退出
set -u  # 使用未定义变量时报错

# ============================================
# 脚本初始化
# ============================================

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

# 颜色定义（用于终端输出）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# 函数定义
# ============================================

# 日志函数
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="${LOG_DIR}/backup_$(date +%Y%m%d).log"
    
    # 确保日志目录存在
    mkdir -p "${LOG_DIR}"
    
    # 写入日志文件
    echo "[${timestamp}] [${level}] ${message}" >> "${log_file}"
    
    # 终端输出（带颜色）
    case ${level} in
        INFO)
            echo -e "${BLUE}[INFO]${NC} ${message}"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} ${message}"
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} ${message}"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${message}"
            ;;
        *)
            echo "[${level}] ${message}"
            ;;
    esac
    
    # 调试模式
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[DEBUG] ${message}" >&2
    fi
}

# 发送 Unraid 通知
send_notification() {
    local title="$1"
    local message="$2"
    local importance="${3:-normal}"
    
    if [[ "${ENABLE_NOTIFICATION:-false}" != "true" ]]; then
        return 0
    fi
    
    # Unraid 通知命令
    if command -v /usr/local/emhttp/webGui/scripts/notify &> /dev/null; then
        /usr/local/emhttp/webGui/scripts/notify \
            -e "${NOTIFICATION_EVENT:-AWBackup}" \
            -s "${title}" \
            -d "${message}" \
            -i "${importance}"
    else
        log WARNING "Unraid 通知命令不可用"
    fi
}

# 发送 Telegram 通知
send_telegram() {
    local title="$1"
    local message="$2"
    local status="${3:-info}"  # success, error, info
    
    # 检查是否启用 Telegram 通知
    if [[ "${ENABLE_TELEGRAM:-false}" != "true" ]]; then
        return 0
    fi
    
    # 检查必需配置
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] || [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        log WARNING "Telegram 配置不完整，跳过通知"
        return 1
    fi
    
    # 根据状态添加图标
    local icon=""
    case ${status} in
        success)
            icon="✅"
            ;;
        error)
            icon="❌"
            ;;
        warning)
            icon="⚠️"
            ;;
        info)
            icon="ℹ️"
            ;;
        start)
            icon="🚀"
            ;;
    esac
    
    # 构建消息文本
    local text="${icon} *${title}*\n\n${message}\n\n_$(date '+%Y-%m-%d %H:%M:%S')_"
    
    # 构建 API URL
    local api_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    
    # 构建 curl 命令
    local curl_cmd="curl -s -X POST"
    
    # 添加代理（如果配置）
    if [[ -n "${TELEGRAM_PROXY:-}" ]]; then
        curl_cmd="${curl_cmd} --proxy ${TELEGRAM_PROXY}"
    fi
    
    # 发送消息
    local response=$(${curl_cmd} "${api_url}" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${text}" \
        -d "parse_mode=Markdown" \
        -d "disable_web_page_preview=true" 2>&1)
    
    # 检查结果
    if echo "${response}" | grep -q '"ok":true'; then
        log INFO "Telegram 通知发送成功"
        return 0
    else
        log WARNING "Telegram 通知发送失败: ${response}"
        return 1
    fi
}

# 检查命令是否存在
check_command() {
    local cmd=$1
    if ! command -v ${cmd} &> /dev/null; then
        log ERROR "命令 ${cmd} 未找到，请先安装"
        return 1
    fi
    return 0
}

# 检查目录是否存在
check_directory() {
    local dir=$1
    local type=$2
    
    if [[ ! -d "${dir}" ]]; then
        log ERROR "${type}目录不存在: ${dir}"
        return 1
    fi
    
    if [[ ! -r "${dir}" ]]; then
        log ERROR "${type}目录不可读: ${dir}"
        return 1
    fi
    
    return 0
}

# 检查磁盘空间
check_disk_space() {
    local source_dir=$1
    local dest_dir=$2
    local task_name=$3
    
    # 获取源目录大小（MB）
    local source_size=$(du -sm "${source_dir}" 2>/dev/null | awk '{print $1}')
    
    # 获取目标目录可用空间（MB）
    local dest_avail=$(df -m "${dest_dir}" 2>/dev/null | tail -1 | awk '{print $4}')
    
    # 预估压缩后大小（假设压缩率为70%）
    local estimated_size=$((source_size * 7 / 10))
    
    log INFO "任务 [${task_name}] 磁盘空间检查："
    log INFO "  源目录大小: ${source_size} MB"
    log INFO "  预估压缩后: ${estimated_size} MB"
    log INFO "  目标可用空间: ${dest_avail} MB"
    
    if [[ ${estimated_size} -gt ${dest_avail} ]]; then
        log ERROR "磁盘空间不足！需要约 ${estimated_size} MB，但只有 ${dest_avail} MB 可用"
        return 1
    fi
    
    # 如果可用空间小于需求的150%，发出警告
    local recommended_space=$((estimated_size * 15 / 10))
    if [[ ${dest_avail} -lt ${recommended_space} ]]; then
        log WARNING "可用空间较少，建议至少保留 ${recommended_space} MB"
    fi
    
    return 0
}

# 清理旧备份
cleanup_old_backups() {
    local backup_dir=$1
    local retention_days=$2
    local task_name=$3
    
    log INFO "任务 [${task_name}] 清理超过 ${retention_days} 天的旧备份..."
    
    if [[ ! -d "${backup_dir}" ]]; then
        log WARNING "备份目录不存在: ${backup_dir}"
        return 0
    fi
    
    # 查找并删除旧文件
    local deleted_count=0
    while IFS= read -r -d '' file; do
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log INFO "  [模拟] 将删除: ${file}"
        else
            rm -f "${file}"
            log INFO "  已删除: $(basename "${file}")"
        fi
        ((deleted_count++))
    done < <(find "${backup_dir}" -name "*.tar.gz" -type f -mtime +${retention_days} -print0 2>/dev/null)
    
    if [[ ${deleted_count} -eq 0 ]]; then
        log INFO "  没有需要清理的旧备份"
    else
        log SUCCESS "  已清理 ${deleted_count} 个旧备份文件"
    fi
}

# 清理旧日志
cleanup_old_logs() {
    local log_dir=$1
    local retention_days=$2
    
    if [[ ! -d "${log_dir}" ]]; then
        return 0
    fi
    
    log INFO "清理超过 ${retention_days} 天的旧日志..."
    
    local deleted_count=0
    while IFS= read -r -d '' file; do
        rm -f "${file}"
        ((deleted_count++))
    done < <(find "${log_dir}" -name "backup_*.log" -type f -mtime +${retention_days} -print0 2>/dev/null)
    
    if [[ ${deleted_count} -gt 0 ]]; then
        log INFO "已清理 ${deleted_count} 个旧日志文件"
    fi
}

# 验证备份完整性
verify_backup() {
    local backup_file=$1
    local task_name=$2
    
    if [[ "${VERIFY_BACKUP:-true}" != "true" ]]; then
        return 0
    fi
    
    log INFO "任务 [${task_name}] 验证备份完整性..."
    
    if ! tar -tzf "${backup_file}" > /dev/null 2>&1; then
        log ERROR "备份文件损坏: ${backup_file}"
        return 1
    fi
    
    log SUCCESS "备份文件完整性验证通过"
    return 0
}

# 执行单个备份任务
backup_task() {
    local task=$1
    local task_upper=$(echo "${task}" | tr '[:lower:]' '[:upper:]')
    
    # 读取任务配置
    local enabled_var="${task_upper}_ENABLED"
    local name_var="${task_upper}_NAME"
    local source_var="${task_upper}_SOURCE"
    local dest_var="${task_upper}_DESTINATION"
    local retention_var="${task_upper}_RETENTION_DAYS"
    local compress_var="${task_upper}_COMPRESS_LEVEL"
    local exclude_var="${task_upper}_EXCLUDE"
    local pre_cmd_var="${task_upper}_PRE_BACKUP_CMD"
    local post_cmd_var="${task_upper}_POST_BACKUP_CMD"
    
    # 检查任务是否启用
    local enabled="${!enabled_var:-true}"
    if [[ "${enabled}" != "true" ]]; then
        log INFO "任务 [${task}] 已禁用，跳过"
        return 0
    fi
    
    # 获取配置值
    local task_name="${!name_var:-${task}}"
    local source_dir="${!source_var:-}"
    local dest_dir="${!dest_var:-}"
    local retention_days="${!retention_var:-7}"
    local compress_level="${!compress_var:-${DEFAULT_COMPRESS_LEVEL:-6}}"
    local exclude_pattern="${!exclude_var:-}"
    local pre_backup_cmd="${!pre_cmd_var:-}"
    local post_backup_cmd="${!post_cmd_var:-}"
    
    # 验证必需配置
    if [[ -z "${source_dir}" ]] || [[ -z "${dest_dir}" ]]; then
        log ERROR "任务 [${task_name}] 配置不完整：缺少 SOURCE 或 DESTINATION"
        return 1
    fi
    
    log INFO "================================================"
    log INFO "开始备份任务: ${task_name}"
    log INFO "================================================"
    
    # 检查源目录
    if ! check_directory "${source_dir}" "源"; then
        return 1
    fi
    
    # 创建目标目录
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        mkdir -p "${dest_dir}"
    fi
    
    # 检查磁盘空间
    if ! check_disk_space "${source_dir}" "${dest_dir}" "${task_name}"; then
        return 1
    fi
    
    # 执行备份前命令
    if [[ -n "${pre_backup_cmd}" ]]; then
        log INFO "执行备份前命令: ${pre_backup_cmd}"
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            eval "${pre_backup_cmd}" || log WARNING "备份前命令执行失败"
        fi
    fi
    
    # 生成备份文件名
    local date_str=$(date +"${DATE_FORMAT:-%Y%m%d_%H%M%S}")
    local backup_filename="${task}_backup_${date_str}.tar.gz"
    local backup_path="${dest_dir}/${backup_filename}"
    
    log INFO "备份文件: ${backup_path}"
    
    # 构建 tar 命令
    local tar_cmd="tar"
    local tar_opts="-czf"
    
    # 使用 pigz 并行压缩（如果可用且启用）
    if [[ "${USE_PIGZ:-false}" == "true" ]] && command -v pigz &> /dev/null; then
        log INFO "使用 pigz 进行并行压缩"
        tar_opts="-I \"pigz -p${PIGZ_THREADS:-2} -${compress_level}\""
    else
        tar_opts="-cz${compress_level}f"
    fi
    
    # 添加排除规则
    local exclude_opts=""
    if [[ -n "${exclude_pattern}" ]]; then
        for pattern in ${exclude_pattern}; do
            exclude_opts="${exclude_opts} --exclude=${pattern}"
        done
    fi
    
    # 性能调优命令前缀
    local perf_prefix=""
    if [[ "${USE_IONICE:-true}" == "true" ]] && command -v ionice &> /dev/null; then
        perf_prefix="ionice -c${IONICE_CLASS:-2} -n${IONICE_PRIORITY:-7}"
    fi
    if [[ "${USE_NICE:-true}" == "true" ]]; then
        perf_prefix="${perf_prefix} nice -n${NICE_LEVEL:-19}"
    fi
    
    # 开始备份
    log INFO "开始压缩备份..."
    local start_time=$(date +%s)
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log INFO "[模拟] 将执行: ${perf_prefix} tar ${tar_opts} \"${backup_path}\" ${exclude_opts} -C \"$(dirname "${source_dir}")\" \"$(basename "${source_dir}")\""
        local backup_result=0
    else
        # 执行备份
        eval ${perf_prefix} tar ${tar_opts} \"${backup_path}\" ${exclude_opts} -C \"$(dirname "${source_dir}")\" \"$(basename "${source_dir}")\" 2>&1 | tee -a "${LOG_DIR}/backup_$(date +%Y%m%d).log"
        local backup_result=${PIPESTATUS[0]}
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_min=$((duration / 60))
    local duration_sec=$((duration % 60))
    
    if [[ ${backup_result} -eq 0 ]]; then
        log SUCCESS "备份完成！耗时: ${duration_min}分${duration_sec}秒"
        
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            # 获取备份文件大小
            local backup_size=$(du -h "${backup_path}" | awk '{print $1}')
            log INFO "备份文件大小: ${backup_size}"
            
            # 验证备份
            if ! verify_backup "${backup_path}" "${task_name}"; then
                log ERROR "备份验证失败，删除损坏的备份文件"
                rm -f "${backup_path}"
                return 1
            fi
        fi
        
        # 清理旧备份
        cleanup_old_backups "${dest_dir}" "${retention_days}" "${task_name}"
        
        # 发送成功通知
        if [[ "${NOTIFY_ON_SUCCESS:-false}" == "true" ]]; then
            send_notification "备份成功" "任务 ${task_name} 备份完成" "${NOTIFICATION_IMPORTANCE_SUCCESS:-normal}"
        fi
        
        # 发送 Telegram 成功通知
        if [[ "${TELEGRAM_NOTIFY_ON_SUCCESS:-true}" == "true" ]]; then
            local detail="📦 任务: ${task_name}\n📁 源: ${source_dir}\n💾 大小: ${backup_size}\n⏱ 耗时: ${duration_min}分${duration_sec}秒"
            send_telegram "备份成功" "${detail}" "success"
        fi
        
    else
        log ERROR "备份失败！错误代码: ${backup_result}"
        
        # 删除不完整的备份文件
        if [[ -f "${backup_path}" ]]; then
            rm -f "${backup_path}"
            log INFO "已删除不完整的备份文件"
        fi
        
        # 发送失败通知
        if [[ "${NOTIFY_ON_ERROR:-true}" == "true" ]]; then
            send_notification "备份失败" "任务 ${task_name} 备份失败，请检查日志" "${NOTIFICATION_IMPORTANCE_ERROR:-alert}"
        fi
        
        # 发送 Telegram 失败通知
        if [[ "${TELEGRAM_NOTIFY_ON_ERROR:-true}" == "true" ]]; then
            local detail="📦 任务: ${task_name}\n📁 源: ${source_dir}\n⚠️ 错误代码: ${backup_result}\n📝 日志: ${LOG_DIR}/backup_$(date +%Y%m%d).log"
            send_telegram "备份失败" "${detail}" "error"
        fi
        
        return 1
    fi
    
    # 执行备份后命令
    if [[ -n "${post_backup_cmd}" ]]; then
        log INFO "执行备份后命令: ${post_backup_cmd}"
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            eval "${post_backup_cmd}" || log WARNING "备份后命令执行失败"
        fi
    fi
    
    log INFO "================================================"
    return 0
}

# ============================================
# 主函数
# ============================================

main() {
    log INFO "============================================"
    log INFO "AWBackup v1.0.0"
    log INFO "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log INFO "============================================"
    
    # 检查配置文件
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log ERROR "配置文件不存在: ${CONFIG_FILE}"
        log ERROR "请从示例配置创建: cp examples/config.example.conf config.conf"
        exit 1
    fi
    
    # 加载配置文件
    log INFO "加载配置文件: ${CONFIG_FILE}"
    source "${CONFIG_FILE}"
    
    # 发送开始通知
    if [[ "${TELEGRAM_NOTIFY_ON_START:-false}" == "true" ]]; then
        send_telegram "备份开始" "AWBackup 开始执行备份任务\n任务数: ${BACKUP_TASKS}" "start"
    fi
    
    # 检查必需命令
    check_command tar || exit 1
    check_command du || exit 1
    check_command df || exit 1
    
    # 创建必要的目录
    mkdir -p "${LOG_DIR:-${SCRIPT_DIR}/logs}"
    
    if [[ -n "${TEMP_DIR:-}" ]]; then
        mkdir -p "${TEMP_DIR}"
    fi
    
    # 模拟运行提示
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log WARNING "==== 模拟运行模式 ===="
        log WARNING "不会实际执行备份操作"
        log WARNING "======================"
    fi
    
    # 执行所有备份任务
    local total_tasks=0
    local success_tasks=0
    local failed_tasks=0
    
    for task in ${BACKUP_TASKS}; do
        ((total_tasks++))
        
        if backup_task "${task}"; then
            ((success_tasks++))
        else
            ((failed_tasks++))
        fi
        
        # 任务间短暂延迟
        sleep 2
    done
    
    # 清理旧日志
    cleanup_old_logs "${LOG_DIR}" "${LOG_RETENTION_DAYS:-30}"
    
    # 输出统计信息
    log INFO "============================================"
    log INFO "备份任务完成统计："
    log INFO "  总任务数: ${total_tasks}"
    log INFO "  成功: ${success_tasks}"
    log INFO "  失败: ${failed_tasks}"
    log INFO "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log INFO "============================================"
    
    # 发送汇总通知
    if [[ ${failed_tasks} -gt 0 ]]; then
        if [[ "${NOTIFY_ON_ERROR:-true}" == "true" ]]; then
            send_notification "备份完成（有失败）" "${success_tasks}/${total_tasks} 任务成功，${failed_tasks} 任务失败" "warning"
        fi
        
        # Telegram 汇总通知（有失败）
        if [[ "${ENABLE_TELEGRAM:-false}" == "true" ]]; then
            local summary="📊 *备份汇总*\n\n✅ 成功: ${success_tasks}\n❌ 失败: ${failed_tasks}\n📋 总计: ${total_tasks}\n\n⚠️ 请检查日志了解详情"
            send_telegram "备份完成（部分失败）" "${summary}" "warning"
        fi
        exit 1
    else
        if [[ "${NOTIFY_ON_SUCCESS:-false}" == "true" ]]; then
            send_notification "备份完成" "所有 ${total_tasks} 个任务均成功完成" "normal"
        fi
        
        # Telegram 汇总通知（全部成功）
        if [[ "${ENABLE_TELEGRAM:-false}" == "true" ]] && [[ "${TELEGRAM_NOTIFY_ON_SUCCESS:-true}" == "true" ]]; then
            local summary="📊 *备份汇总*\n\n✅ 所有任务完成\n📋 总计: ${total_tasks} 个任务\n🎉 全部成功！"
            send_telegram "备份完成" "${summary}" "success"
        fi
        exit 0
    fi
}

# ============================================
# 脚本入口
# ============================================

# 捕获中断信号
trap 'log WARNING "备份被用户中断"; exit 130' INT TERM

# 执行主函数
main "$@"

