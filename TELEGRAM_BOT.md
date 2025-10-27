# Telegram Bot 控制功能

AWBackup 支持通过 Telegram Bot 进行交互式控制，可以远程执行备份、查看状态、查看日志等操作。

## 📋 功能说明

### 1. 通知功能
- ✅ 备份成功通知
- ❌ 备份失败通知
- 🚀 备份开始通知（可选）
- 📊 详细的备份统计信息

### 2. 交互控制（Bot 菜单）
- 🎛️ 远程控制备份执行
- 📊 实时查看备份状态
- 📝 查看备份日志
- 📦 列出备份文件
- ℹ️ 查看系统信息

## 🚀 快速配置

### 第一步：创建 Telegram Bot

1. 在 Telegram 中搜索 **@BotFather**
2. 发送 `/newbot` 命令
3. 按提示设置机器人名称和用户名
4. 获取 Bot Token（类似：`123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ`）

### 第二步：获取 Chat ID

方法一：使用 @userinfobot
1. 在 Telegram 中搜索 **@userinfobot**
2. 发送任意消息
3. 获取你的 Chat ID（数字，类似：`123456789`）

方法二：使用 @getidsbot
1. 在 Telegram 中搜索 **@getidsbot**
2. 发送 `/start`
3. 获取你的 Chat ID

### 第三步：配置 AWBackup

编辑 `config.conf` 文件：

```bash
# ============================================
# Telegram 通知配置
# ============================================

# 启用 Telegram 通知
ENABLE_TELEGRAM=true

# Telegram Bot Token（从 @BotFather 获取）
TELEGRAM_BOT_TOKEN="123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ"

# Telegram Chat ID（从 @userinfobot 获取）
TELEGRAM_CHAT_ID="123456789"

# Telegram 通知设置
TELEGRAM_NOTIFY_ON_SUCCESS=true   # 成功时通知
TELEGRAM_NOTIFY_ON_ERROR=true     # 失败时通知
TELEGRAM_NOTIFY_ON_START=false    # 开始时通知

# Telegram Bot 控制（交互式命令）
TELEGRAM_BOT_CONTROL=true         # 启用 Bot 菜单控制功能

# 使用代理（可选）
# TELEGRAM_PROXY="socks5://127.0.0.1:1080"
```

### 第四步：启动容器

```bash
# 重启容器以应用配置
docker-compose restart

# 查看 Bot 日志
docker logs AWBackup | grep "Telegram Bot"
```

## 🎛️ Bot 命令列表

### 主要命令

| 命令 | 功能描述 | 使用场景 |
|------|---------|----------|
| `/start` 或 `/menu` | 显示主菜单 | 查看所有可用命令 |
| `/backup` | 立即执行备份 | 需要立即备份时 |
| `/status` | 查看备份状态 | 检查最近备份情况 |
| `/logs` | 查看今日日志 | 查看备份详细过程 |
| `/list` | 列出备份文件 | 查看已有备份 |
| `/info` | 系统信息 | 查看资源使用情况 |
| `/help` | 帮助信息 | 查看命令说明 |

### 命令详解

#### `/backup` - 立即执行备份
```
用途：手动触发一次完整备份
特点：
- 异步执行，不会阻塞 Bot
- 备份完成后自动发送结果通知
- 不影响定时任务
```

#### `/status` - 查看备份状态
```
显示信息：
- 最近备份时间
- 定时任务配置
- 备份目录空间使用
- 已配置的备份任务列表
```

#### `/logs` - 查看今日日志
```
显示信息：
- 今日备份日志最后 30 行
- 自动过滤 ANSI 颜色代码
- 显示总行数
```

#### `/list` - 列出备份文件
```
显示信息：
- 每个任务的最近 5 个备份文件
- 文件大小
- 文件名（包含时间戳）
```

#### `/info` - 系统信息
```
显示信息：
- 主机名
- 当前时间
- 系统负载
- 内存使用
- 备份目录总大小
```

## 🔒 安全说明

### Chat ID 验证
Bot 脚本会验证 Chat ID，只有配置的 Chat ID 才能执行命令：

```bash
# 安全检查：只允许配置的 Chat ID
if [[ "$chat_id" != "$TELEGRAM_CHAT_ID" ]]; then
    send_message "$chat_id" "❌ 未授权访问"
    return
fi
```

### 建议
1. **不要泄露 Bot Token** - 任何人获得 Token 都可以控制你的机器人
2. **不要在公开群组使用** - 建议在私聊中使用
3. **定期更换 Token** - 如果怀疑 Token 泄露，立即通过 @BotFather 重新生成

## 🌐 代理配置

如果你的服务器无法直接访问 Telegram API，可以配置代理：

### SOCKS5 代理
```bash
TELEGRAM_PROXY="socks5://127.0.0.1:1080"
```

### HTTP 代理
```bash
TELEGRAM_PROXY="http://127.0.0.1:8080"
```

### 带认证的代理
```bash
TELEGRAM_PROXY="socks5://username:password@127.0.0.1:1080"
```

## 🔧 故障排除

### Bot 不响应

1. **检查 Bot 是否启动**
```bash
docker logs AWBackup | grep "Telegram Bot"
```

应该看到：
```
AWBackup Telegram Bot 已启动
监听 Chat ID: 123456789
```

2. **检查配置**
```bash
docker exec AWBackup cat /app/config.conf | grep TELEGRAM
```

确认：
- `ENABLE_TELEGRAM=true`
- `TELEGRAM_BOT_CONTROL=true`
- Token 和 Chat ID 正确

3. **检查网络连接**
```bash
docker exec AWBackup curl -s https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getMe
```

应该返回 Bot 信息的 JSON。

### 命令返回 "未授权访问"

- 检查你的 Chat ID 是否与配置文件中的一致
- 确保没有多余的空格或特殊字符

### Bot 日志

查看 Bot 详细日志：
```bash
docker exec AWBackup tail -f /app/logs/tg_bot.log
```

## 📱 使用示例

### 1. 立即备份
```
你: /backup
Bot: 🚀 开始执行备份任务...
     请稍候，备份完成后会通知您。

（几分钟后）

Bot: ✅ 备份任务执行完成！
     详细结果请查看通知消息。
```

### 2. 查看状态
```
你: /status
Bot: 📊 备份状态

     ✅ 最近备份: 今天
     
     ⏰ 定时任务: `0 2 * * *`
     
     💾 备份目录空间:
     `已用: 45G / 500G (9%)`
     
     📋 备份任务: `cache`
```

### 3. 查看日志
```
你: /logs
Bot: 📝 今日备份日志 (共 156 行)
     
     最近 30 行:
     ```
     [2025-01-15 02:00:01] 开始备份任务...
     [2025-01-15 02:00:02] 压缩 /data/cache
     [2025-01-15 02:15:33] 备份完成
     [2025-01-15 02:15:34] 验证备份文件...
     [2025-01-15 02:15:35] ✅ 所有任务完成
     ```
```

## 🎨 自定义消息格式

如果你想自定义消息格式，可以编辑 `tg_bot.sh` 中的相应函数：

```bash
# 例如修改菜单文本
handle_command() {
    case "$command" in
        /start|/menu)
            local menu_text="🎛️ *我的备份控制面板*\n\n"
            menu_text+="选择一个操作:\n"
            menu_text+="..."
            send_message "$chat_id" "$menu_text"
            ;;
    esac
}
```

## 💡 高级功能

### 多用户支持

如果需要允许多个用户控制，可以修改 `tg_bot.sh`：

```bash
# 允许的 Chat ID 列表（用空格分隔）
ALLOWED_CHAT_IDS="123456789 987654321"

# 安全检查
if ! echo "$ALLOWED_CHAT_IDS" | grep -q "$chat_id"; then
    send_message "$chat_id" "❌ 未授权访问"
    return
fi
```

### 群组通知

要在群组中接收通知：

1. 将 Bot 添加到群组
2. 获取群组 Chat ID（通常为负数，如 `-123456789`）
3. 在配置文件中设置群组 Chat ID

```bash
TELEGRAM_CHAT_ID="-123456789"
```

## 📚 更多资源

- [Telegram Bot API 文档](https://core.telegram.org/bots/api)
- [BotFather 使用指南](https://core.telegram.org/bots#6-botfather)
- [AWBackup GitHub 仓库](https://github.com/yourusername/awbackup)

---

**享受你的自动化备份之旅！** 🚀

