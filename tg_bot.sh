#!/bin/bash
# ============================================
# AWBackup - Telegram Bot 控制脚本
# ============================================

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/config.conf}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "错误: 配置文件 $CONFIG_FILE 不存在"
    exit 1
fi

source "$CONFIG_FILE"

# 检查是否启用 Telegram
if [[ "${ENABLE_TELEGRAM:-false}" != "true" ]]; then
    echo "Telegram 未启用，退出 Bot 控制"
    exit 0
fi

# 检查必要的配置
if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
    echo "错误: Telegram Bot Token 或 Chat ID 未配置"
    exit 1
fi

# API 基础 URL
API_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
OFFSET_FILE="${SCRIPT_DIR}/logs/.tg_offset"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"
LOG_DIR="${LOG_DIR:-${SCRIPT_DIR}/logs}"

# 代理设置
CURL_PROXY=""
if [[ -n "${TELEGRAM_PROXY:-}" ]]; then
    CURL_PROXY="--proxy ${TELEGRAM_PROXY}"
fi

# ============================================
# 发送消息函数
# ============================================
send_message() {
    local chat_id="$1"
    local text="$2"
    local parse_mode="${3:-Markdown}"
    
    curl -s $CURL_PROXY -X POST "${API_URL}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${chat_id}\",
            \"text\": \"${text}\",
            \"parse_mode\": \"${parse_mode}\"
        }" > /dev/null
}

# ============================================
# 获取更新
# ============================================
get_updates() {
    local offset="${1:-0}"
    
    curl -s $CURL_PROXY -X POST "${API_URL}/getUpdates" \
        -H "Content-Type: application/json" \
        -d "{
            \"offset\": ${offset},
            \"timeout\": 30,
            \"allowed_updates\": [\"message\"]
        }"
}

# ============================================
# 处理命令
# ============================================
handle_command() {
    local chat_id="$1"
    local command="$2"
    local from_user="$3"
    
    # 安全检查：只允许配置的 Chat ID
    if [[ "$chat_id" != "$TELEGRAM_CHAT_ID" ]]; then
        send_message "$chat_id" "❌ 未授权访问"
        echo "警告: 未授权的访问尝试 - Chat ID: $chat_id, User: $from_user"
        return
    fi
    
    case "$command" in
        /start|/menu)
            local menu_text="🎛️ *AWBackup 控制面板*\n\n"
            menu_text+="📝 *可用命令:*\n"
            menu_text+="\`/backup\` - 立即执行备份\n"
            menu_text+="\`/status\` - 查看备份状态\n"
            menu_text+="\`/logs\` - 查看今日日志\n"
            menu_text+="\`/list\` - 列出备份文件\n"
            menu_text+="\`/info\` - 系统信息\n"
            menu_text+="\`/help\` - 帮助信息\n"
            menu_text+="\`/menu\` - 显示此菜单\n\n"
            menu_text+="💡 提示: 点击命令即可执行"
            send_message "$chat_id" "$menu_text"
            ;;
            
        /backup)
            send_message "$chat_id" "🚀 开始执行备份任务...\n\n请稍候，备份完成后会通知您。"
            
            # 在后台执行备份
            (
                if [[ -x "$BACKUP_SCRIPT" ]]; then
                    output=$("$BACKUP_SCRIPT" 2>&1)
                    result=$?
                    
                    if [[ $result -eq 0 ]]; then
                        send_message "$chat_id" "✅ 备份任务执行完成！\n\n详细结果请查看通知消息。"
                    else
                        send_message "$chat_id" "❌ 备份任务执行失败！\n\n错误信息:\n\`\`\`\n${output: -500}\n\`\`\`"
                    fi
                else
                    send_message "$chat_id" "❌ 备份脚本不存在或无执行权限"
                fi
            ) &
            ;;
            
        /status)
            local status_text="📊 *备份状态*\n\n"
            
            # 检查最近的备份日志
            local today_log="${LOG_DIR}/backup_$(date +%Y%m%d).log"
            if [[ -f "$today_log" ]]; then
                local last_backup=$(tail -20 "$today_log" | grep "备份完成" | tail -1)
                if [[ -n "$last_backup" ]]; then
                    status_text+="✅ 最近备份: 今天\n"
                else
                    status_text+="⏳ 今日备份: 进行中或未开始\n"
                fi
            else
                status_text+="ℹ️ 今日暂无备份记录\n"
            fi
            
            # 检查定时任务
            if [[ -n "${CRON_SCHEDULE:-}" ]]; then
                status_text+="\n⏰ 定时任务: \`${CRON_SCHEDULE}\`\n"
            fi
            
            # 磁盘空间
            local disk_info=$(df -h /backups 2>/dev/null | tail -1 | awk '{print "已用: "$3" / "$2" ("$5")"}')
            if [[ -n "$disk_info" ]]; then
                status_text+="\n💾 备份目录空间:\n\`${disk_info}\`\n"
            fi
            
            # 配置的任务
            status_text+="\n📋 备份任务: \`${BACKUP_TASKS}\`\n"
            
            send_message "$chat_id" "$status_text"
            ;;
            
        /logs)
            local today_log="${LOG_DIR}/backup_$(date +%Y%m%d).log"
            
            if [[ -f "$today_log" ]]; then
                local log_content=$(tail -30 "$today_log" | sed 's/\x1b\[[0-9;]*m//g')
                local log_size=$(wc -l < "$today_log")
                
                local log_text="📝 *今日备份日志* (共 ${log_size} 行)\n\n"
                log_text+="最近 30 行:\n"
                log_text+="\`\`\`\n${log_content}\n\`\`\`"
                
                send_message "$chat_id" "$log_text"
            else
                send_message "$chat_id" "ℹ️ 今日暂无日志文件"
            fi
            ;;
            
        /list)
            local list_text="📦 *备份文件列表*\n\n"
            
            # 遍历每个任务的备份目录
            for task in $BACKUP_TASKS; do
                local task_upper=$(echo "$task" | tr '[:lower:]' '[:upper:]')
                local dest_var="${task_upper}_DESTINATION"
                local dest="${!dest_var}"
                local name_var="${task_upper}_NAME"
                local name="${!name_var:-$task}"
                
                if [[ -d "$dest" ]]; then
                    list_text+="*${name}:*\n"
                    
                    local files=$(ls -lh "$dest"/*.tar.gz 2>/dev/null | tail -5 | awk '{print $9" ("$5")"}' | xargs -I {} basename {})
                    
                    if [[ -n "$files" ]]; then
                        while IFS= read -r file; do
                            list_text+="  • \`${file}\`\n"
                        done <<< "$files"
                        
                        local total=$(ls -1 "$dest"/*.tar.gz 2>/dev/null | wc -l)
                        if [[ $total -gt 5 ]]; then
                            list_text+="  _(还有 $((total - 5)) 个文件...)_\n"
                        fi
                    else
                        list_text+="  _暂无备份文件_\n"
                    fi
                    list_text+="\n"
                fi
            done
            
            send_message "$chat_id" "$list_text"
            ;;
            
        /info)
            local info_text="ℹ️ *系统信息*\n\n"
            info_text+="*主机名:* \`$(hostname)\`\n"
            info_text+="*时间:* \`$(date '+%Y-%m-%d %H:%M:%S')\`\n"
            info_text+="*时区:* \`${TZ:-未设置}\`\n"
            info_text+="*负载:* \`$(uptime | awk -F'load average:' '{print $2}')\`\n"
            
            # 内存信息
            if command -v free &> /dev/null; then
                local mem_info=$(free -h | grep Mem | awk '{print $3" / "$2}')
                info_text+="*内存:* \`${mem_info}\`\n"
            fi
            
            # 备份目录大小
            if [[ -d "/backups" ]]; then
                local backup_size=$(du -sh /backups 2>/dev/null | awk '{print $1}')
                info_text+="*备份总大小:* \`${backup_size}\`\n"
            fi
            
            send_message "$chat_id" "$info_text"
            ;;
            
        /help)
            local help_text="📖 *AWBackup 帮助*\n\n"
            help_text+="*命令说明:*\n\n"
            help_text+="• \`/backup\` - 立即执行一次完整备份\n"
            help_text+="• \`/status\` - 查看备份状态和配置信息\n"
            help_text+="• \`/logs\` - 查看今日备份日志最后30行\n"
            help_text+="• \`/list\` - 列出所有任务的备份文件\n"
            help_text+="• \`/info\` - 显示系统和资源信息\n"
            help_text+="• \`/menu\` - 显示主菜单\n\n"
            help_text+="💡 *提示:*\n"
            help_text+="- 所有命令都需要在授权的 Chat ID 中执行\n"
            help_text+="- 手动执行的备份不会影响定时任务\n"
            help_text+="- 备份过程可能需要几分钟，请耐心等待\n\n"
            help_text+="📦 *AWBackup v1.1.0*"
            
            send_message "$chat_id" "$help_text"
            ;;
            
        *)
            send_message "$chat_id" "❓ 未知命令: \`${command}\`\n\n输入 /menu 查看可用命令"
            ;;
    esac
}

# ============================================
# 主循环
# ============================================
echo "AWBackup Telegram Bot 已启动"
echo "监听 Chat ID: $TELEGRAM_CHAT_ID"

# 读取上次的 offset
if [[ -f "$OFFSET_FILE" ]]; then
    OFFSET=$(cat "$OFFSET_FILE")
else
    OFFSET=0
fi

# 发送启动消息
send_message "$TELEGRAM_CHAT_ID" "🤖 *AWBackup Bot 已启动*\n\n输入 /menu 查看可用命令"

# 主循环
while true; do
    # 获取更新
    response=$(get_updates "$OFFSET")
    
    # 检查是否有错误
    if ! echo "$response" | jq -e '.ok' > /dev/null 2>&1; then
        echo "API 错误: $response"
        sleep 10
        continue
    fi
    
    # 处理每个更新
    echo "$response" | jq -c '.result[]' 2>/dev/null | while read -r update; do
        # 获取 update_id
        update_id=$(echo "$update" | jq -r '.update_id')
        
        # 更新 offset
        NEW_OFFSET=$((update_id + 1))
        echo "$NEW_OFFSET" > "$OFFSET_FILE"
        
        # 获取消息信息
        chat_id=$(echo "$update" | jq -r '.message.chat.id // empty')
        text=$(echo "$update" | jq -r '.message.text // empty')
        from_user=$(echo "$update" | jq -r '.message.from.username // .message.from.first_name // "Unknown"')
        
        # 如果是命令消息
        if [[ -n "$text" ]] && [[ "$text" == /* ]]; then
            echo "收到命令: $text (来自 $from_user, Chat ID: $chat_id)"
            handle_command "$chat_id" "$text" "$from_user"
        fi
    done
    
    # 更新 offset
    if [[ -f "$OFFSET_FILE" ]]; then
        OFFSET=$(cat "$OFFSET_FILE")
    fi
    
    # 短暂休眠
    sleep 1
done

