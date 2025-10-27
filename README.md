# AWBackup

🐳 **Docker 化的自动备份工具** - 专为 Linux 服务器设计

## ✨ 特性

- 🗜️ **自动压缩备份** - tar.gz 格式
- ⏰ **定时任务** - Cron 调度
- 📱 **Telegram Bot** - 远程控制 + 通知
- 🐳 **Docker 部署** - 开箱即用
- 🔄 **自动清理** - 删除过期备份

## 🚀 快速开始

### 1. 创建配置文件

```bash
mkdir -p /opt/awbackup
cd /opt/awbackup

cat > config.conf << 'EOF'
# 备份任务列表
BACKUP_TASKS="mydata"

# 任务配置
MYDATA_SOURCE="/path/to/source"
MYDATA_DESTINATION="/path/to/backup"
MYDATA_RETENTION_DAYS=7

# Telegram (可选)
ENABLE_TELEGRAM=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
TELEGRAM_BOT_CONTROL=false
EOF
```

### 2. 创建 docker-compose.yml

```yaml
version: '3.8'
services:
  awbackup:
    image: awdress/awbackup:latest
    container_name: AWBackup
    environment:
      - CRON_SCHEDULE=0 2 * * *  # 每天凌晨2点
      - TZ=Asia/Shanghai
    volumes:
      - ./config.conf:/app/config.conf:ro
      - ./logs:/app/logs
      - /path/to/source:/data:ro
      - /path/to/backup:/backups
    restart: unless-stopped
```

### 3. 启动

```bash
docker-compose up -d
```

## 📱 Telegram Bot 控制

### 配置

```bash
# 1. 找 @BotFather 创建 Bot，获取 Token
# 2. 找 @userinfobot 获取你的 Chat ID
# 3. 在 config.conf 中配置：

ENABLE_TELEGRAM=true
TELEGRAM_BOT_TOKEN="你的Token"
TELEGRAM_CHAT_ID="你的ChatID"
TELEGRAM_BOT_CONTROL=true
```

### 命令

- `/backup` - 立即执行备份
- `/status` - 查看状态
- `/logs` - 查看日志
- `/list` - 列出备份文件

## ⚙️ 配置说明

```bash
# 全局配置
BACKUP_TASKS="task1 task2"  # 任务列表，空格分隔
LOG_DIR="/app/logs"         # 日志目录
ENABLE_TELEGRAM=false       # 是否启用 Telegram

# 任务配置 (大写任务名)
TASK1_SOURCE="/source/path"         # 源目录
TASK1_DESTINATION="/backup/path"    # 目标目录
TASK1_RETENTION_DAYS=7              # 保留天数
TASK1_COMPRESS_LEVEL=6              # 压缩级别 1-9
TASK1_EXCLUDE=""                    # 排除规则
TASK1_ENABLED=true                  # 是否启用
```

## 🔧 常用命令

```bash
# 查看日志
docker logs AWBackup

# 手动执行备份
docker exec AWBackup /app/backup.sh

# 进入容器
docker exec -it AWBackup /bin/bash

# 重启容器
docker-compose restart
```

## 📝 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `CRON_SCHEDULE` | Cron 表达式 | 不设置则单次执行 |
| `TZ` | 时区 | `Asia/Shanghai` |

## 💡 使用示例

### 备份多个目录

```bash
BACKUP_TASKS="docker configs photos"

DOCKER_SOURCE="/var/lib/docker"
DOCKER_DESTINATION="/backups/docker"
DOCKER_RETENTION_DAYS=3
DOCKER_ENABLED=true

CONFIGS_SOURCE="/etc"
CONFIGS_DESTINATION="/backups/configs"
CONFIGS_RETENTION_DAYS=7
CONFIGS_ENABLED=true

PHOTOS_SOURCE="/home/photos"
PHOTOS_DESTINATION="/backups/photos"
PHOTOS_RETENTION_DAYS=30
PHOTOS_ENABLED=true
```

### 排除特定文件

```bash
DOCKER_EXCLUDE="*.tmp *.log cache/ temp/"
```

## 📄 License

MIT

## 🔗 Links

- GitHub: https://github.com/AWdress/AWBackup
- Docker Hub: https://hub.docker.com/r/awdress/awbackup
