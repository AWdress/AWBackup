# AWBackup Docker Image
FROM alpine:3.19

# 设置标签
LABEL maintainer="AWBackup" \
      description="自动化备份工具 - Docker 版本" \
      version="1.1.0"

# 安装必需软件
RUN apk add --no-cache \
    bash \
    tar \
    gzip \
    pigz \
    coreutils \
    findutils \
    curl \
    ca-certificates \
    tzdata \
    jq \
    dos2unix \
    && rm -rf /var/cache/apk/*

# 设置时区
ENV TZ=Asia/Shanghai

# 创建工作目录
WORKDIR /app

# 复制项目文件
COPY backup.sh /app/
COPY cleanup.sh /app/
COPY restore.sh /app/
COPY tg_bot.sh /app/

# 设置执行权限
RUN chmod +x /app/*.sh

# 创建配置模板
RUN cat > /app/config.conf.template << 'EOF'
# AWBackup 配置文件
BACKUP_TASKS="mydata"
LOG_DIR="/app/logs"
LOG_RETENTION_DAYS=30
ENABLE_NOTIFICATION=false
ENABLE_TELEGRAM=false

# 示例备份任务
MYDATA_NAME="我的数据"
MYDATA_SOURCE="/data/mydata"
MYDATA_DESTINATION="/backups"
MYDATA_RETENTION_DAYS=7
MYDATA_COMPRESS_LEVEL=6
MYDATA_ENABLED=true
EOF

# 创建必要的目录
RUN mkdir -p /app/logs \
    && mkdir -p /backups \
    && mkdir -p /data

# 创建启动脚本
RUN echo '#!/bin/bash' > /app/entrypoint.sh && \
    echo 'set -e' >> /app/entrypoint.sh && \
    echo '' >> /app/entrypoint.sh && \
    echo '# 修复配置文件换行符（Windows CRLF -> Unix LF）' >> /app/entrypoint.sh && \
    echo 'if [ -f /app/config.conf ]; then' >> /app/entrypoint.sh && \
    echo '    echo "检查并修复配置文件格式..."' >> /app/entrypoint.sh && \
    echo '    dos2unix /app/config.conf 2>/dev/null || sed -i "s/\r$//" /app/config.conf' >> /app/entrypoint.sh && \
    echo 'fi' >> /app/entrypoint.sh && \
    echo '' >> /app/entrypoint.sh && \
    echo '# 如果配置文件不存在，从模板创建' >> /app/entrypoint.sh && \
    echo 'if [ ! -f /app/config.conf ]; then' >> /app/entrypoint.sh && \
    echo '    echo "初始化配置文件..."' >> /app/entrypoint.sh && \
    echo '    cp /app/config.conf.template /app/config.conf' >> /app/entrypoint.sh && \
    echo 'fi' >> /app/entrypoint.sh && \
    echo '' >> /app/entrypoint.sh && \
    echo '# 加载配置' >> /app/entrypoint.sh && \
    echo 'source /app/config.conf' >> /app/entrypoint.sh && \
    echo '' >> /app/entrypoint.sh && \
    echo '# 启动 Telegram Bot 控制（如果启用）' >> /app/entrypoint.sh && \
    echo 'if [ "${ENABLE_TELEGRAM:-false}" = "true" ] && [ "${TELEGRAM_BOT_CONTROL:-false}" = "true" ]; then' >> /app/entrypoint.sh && \
    echo '    echo "启动 Telegram Bot 控制..."' >> /app/entrypoint.sh && \
    echo '    /app/tg_bot.sh >> /app/logs/tg_bot.log 2>&1 &' >> /app/entrypoint.sh && \
    echo '    TG_BOT_PID=$!' >> /app/entrypoint.sh && \
    echo '    echo "Telegram Bot PID: $TG_BOT_PID"' >> /app/entrypoint.sh && \
    echo 'fi' >> /app/entrypoint.sh && \
    echo '' >> /app/entrypoint.sh && \
    echo '# 检查 Cron 表达式' >> /app/entrypoint.sh && \
    echo 'if [ -n "$CRON_SCHEDULE" ]; then' >> /app/entrypoint.sh && \
    echo '    echo "设置定时任务: $CRON_SCHEDULE"' >> /app/entrypoint.sh && \
    echo '    echo "$CRON_SCHEDULE /app/backup.sh >> /app/logs/cron.log 2>&1" > /etc/crontabs/root' >> /app/entrypoint.sh && \
    echo '    echo "启动 Cron 服务..."' >> /app/entrypoint.sh && \
    echo '    crond -f -l 2' >> /app/entrypoint.sh && \
    echo 'else' >> /app/entrypoint.sh && \
    echo '    echo "未设置定时任务，执行单次备份..."' >> /app/entrypoint.sh && \
    echo '    /app/backup.sh' >> /app/entrypoint.sh && \
    echo 'fi' >> /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

# 安装 crond
RUN apk add --no-cache dcron

# 暴露卷
VOLUME ["/app/logs", "/backups", "/data", "/app/config.conf"]

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]

# 健康检查
HEALTHCHECK --interval=1h --timeout=10s --start-period=10s --retries=3 \
    CMD [ -f /app/logs/backup_$(date +%Y%m%d).log ] || exit 1

