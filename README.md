# AWBackup

一个轻量级的自动化备份工具，支持定时备份、Docker 部署和 Telegram 通知。

## ✨ 功能特性

- 🗜️ 自动压缩备份（tar.gz 格式）
- ⏰ Cron 定时任务支持
- 📁 多任务并行备份
- 🗑️ 自动清理过期备份
- 📝 详细日志记录
- ✅ 备份完整性验证
- 📧 Telegram 机器人通知
- 🐳 Docker 容器化支持

## 🚀 快速开始

### Docker 部署（推荐）

```bash
# 1. 克隆项目
git clone https://github.com/yourusername/awbackup.git
cd awbackup

# 2. 编辑配置
cp config.conf config.conf.example
nano config.conf

# 3. 启动容器
docker-compose up -d
```

### 直接安装（Unraid/Linux）

```bash
# 1. 下载并安装
cd /mnt/user/appdata/awbackup
chmod +x install.sh
./install.sh

# 2. 配置
nano config.conf
```

## ⚙️ 配置示例

编辑 `config.conf`：

```bash
# 定义备份任务
BACKUP_TASKS="documents photos"

# 文档备份
DOCUMENTS_NAME="文档"
DOCUMENTS_SOURCE="/mnt/user/documents"
DOCUMENTS_DESTINATION="/mnt/user/backups/documents"
DOCUMENTS_RETENTION_DAYS=7
DOCUMENTS_COMPRESS_LEVEL=6
DOCUMENTS_ENABLED=true

# 照片备份
PHOTOS_NAME="照片"
PHOTOS_SOURCE="/mnt/user/photos"
PHOTOS_DESTINATION="/mnt/user/backups/photos"
PHOTOS_RETENTION_DAYS=14
PHOTOS_COMPRESS_LEVEL=3
PHOTOS_ENABLED=true
```

## 📱 Telegram 通知（可选）

```bash
# 1. 在 Telegram 找 @BotFather，创建 Bot
# 2. 在 Telegram 找 @userinfobot，获取 Chat ID
# 3. 编辑配置
ENABLE_TELEGRAM=true
TELEGRAM_BOT_TOKEN="your_bot_token"
TELEGRAM_CHAT_ID="your_chat_id"
```

## 🐳 Docker 配置

### docker-compose.yml

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
      - /mnt/user/backups:/backups
      - /mnt/user/documents:/data/documents:ro
    restart: unless-stopped
```

### 环境变量

- `CRON_SCHEDULE`: Cron 表达式，不设置则单次执行
- `TZ`: 时区设置

## 🔧 常用命令

```bash
# Docker
docker-compose logs -f                    # 查看日志
docker exec AWBackup /app/backup.sh       # 手动备份
docker-compose restart                    # 重启

# 直接安装
./backup.sh                               # 手动备份
./cleanup.sh -i                           # 清理旧备份
./restore.sh -i                           # 恢复备份
crontab -l                                # 查看定时任务
```

## 🛠️ 高级功能

### 排除文件

```bash
DOCUMENTS_EXCLUDE="*.tmp *.log cache/ temp/"
```

### 备份前后钩子

```bash
DOCKER_PRE_BACKUP_CMD="docker stop mycontainer"
DOCKER_POST_BACKUP_CMD="docker start mycontainer"
```

## 📝 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！
