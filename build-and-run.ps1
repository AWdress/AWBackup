# AWBackup Docker 构建和运行脚本（Windows PowerShell）
# 使用方法: .\build-and-run.ps1

Write-Host "==================================" -ForegroundColor Blue
Write-Host "  AWBackup Docker 构建脚本" -ForegroundColor Blue
Write-Host "  版本: 1.1.0" -ForegroundColor Blue
Write-Host "==================================" -ForegroundColor Blue
Write-Host ""

# 检查 Docker
Write-Host "[1/4] 检查 Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "✓ Docker 版本: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ 错误: 未安装 Docker Desktop" -ForegroundColor Red
    Write-Host ""
    Write-Host "请按照以下步骤安装:" -ForegroundColor Yellow
    Write-Host "1. 访问: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    Write-Host "2. 下载并安装 Docker Desktop for Windows" -ForegroundColor Yellow
    Write-Host "3. 重启计算机" -ForegroundColor Yellow
    Write-Host "4. 启动 Docker Desktop" -ForegroundColor Yellow
    Write-Host "5. 再次运行此脚本" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "详细指南: 阅读 WINDOWS_DOCKER_GUIDE.md" -ForegroundColor Cyan
    pause
    exit 1
}

# 检查 Docker Compose
try {
    $composeVersion = docker-compose --version
    Write-Host "✓ Docker Compose: $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ 错误: Docker Compose 不可用" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 检查配置文件
Write-Host "[2/4] 检查配置文件..." -ForegroundColor Yellow
if (-not (Test-Path "config.conf")) {
    Write-Host "✗ 警告: config.conf 不存在" -ForegroundColor Yellow
    Write-Host ""
    $createConfig = Read-Host "是否创建最小配置文件? (Y/n)"
    if ($createConfig -ne 'n' -and $createConfig -ne 'N') {
        $configContent = @"
BACKUP_TASKS="mydata"
LOG_DIR="/app/logs"
MYDATA_NAME="我的备份"
MYDATA_SOURCE="/data/mydata"
MYDATA_DESTINATION="/backups"
MYDATA_RETENTION_DAYS=7
MYDATA_COMPRESS_LEVEL=6
MYDATA_ENABLED=true
ENABLE_NOTIFICATION=false
ENABLE_TELEGRAM=false
"@
        Set-Content -Path "config.conf" -Value $configContent
        Write-Host "✓ 已创建基础配置文件" -ForegroundColor Green
        Write-Host "请编辑 config.conf 后再运行此脚本" -ForegroundColor Yellow
        notepad config.conf
        pause
        exit 0
    } else {
        Write-Host "请先创建 config.conf 文件" -ForegroundColor Red
        exit 1
    }
}
Write-Host "✓ 配置文件存在" -ForegroundColor Green

Write-Host ""

# 构建镜像
Write-Host "[3/4] 构建 Docker 镜像..." -ForegroundColor Yellow
Write-Host "这可能需要几分钟时间..." -ForegroundColor Gray
Write-Host ""

docker-compose build

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ 镜像构建成功" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "✗ 镜像构建失败" -ForegroundColor Red
    Write-Host ""
    Write-Host "可能的原因:" -ForegroundColor Yellow
    Write-Host "1. 网络连接问题（无法下载基础镜像）" -ForegroundColor Gray
    Write-Host "2. Docker 服务未运行" -ForegroundColor Gray
    Write-Host "3. 磁盘空间不足" -ForegroundColor Gray
    Write-Host ""
    Write-Host "解决方案请查看: WINDOWS_DOCKER_GUIDE.md" -ForegroundColor Cyan
    pause
    exit 1
}

Write-Host ""

# 启动容器
Write-Host "[4/4] 启动容器..." -ForegroundColor Yellow

docker-compose up -d

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ 容器启动成功" -ForegroundColor Green
} else {
    Write-Host "✗ 容器启动失败" -ForegroundColor Red
    Write-Host ""
    Write-Host "请检查:" -ForegroundColor Yellow
    Write-Host "1. docker-compose.yml 配置是否正确" -ForegroundColor Gray
    Write-Host "2. 端口是否被占用" -ForegroundColor Gray
    Write-Host "3. 卷挂载路径是否存在" -ForegroundColor Gray
    pause
    exit 1
}

# 显示状态
Write-Host ""
Write-Host "==================================" -ForegroundColor Green
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
Write-Host ""

Write-Host "容器状态:" -ForegroundColor Blue
docker ps -a | Select-String "AWBackup"

Write-Host ""
Write-Host "常用命令:" -ForegroundColor Blue
Write-Host "  查看日志:   docker-compose logs -f" -ForegroundColor Yellow
Write-Host "  手动备份:   docker exec AWBackup /app/backup.sh" -ForegroundColor Yellow
Write-Host "  停止容器:   docker-compose down" -ForegroundColor Yellow
Write-Host "  重启容器:   docker-compose restart" -ForegroundColor Yellow
Write-Host "  进入容器:   docker exec -it AWBackup /bin/sh" -ForegroundColor Yellow
Write-Host ""

# 询问是否查看日志
$viewLogs = Read-Host "是否查看容器日志? (Y/n)"
if ($viewLogs -ne 'n' -and $viewLogs -ne 'N') {
    Write-Host ""
    Write-Host "显示日志（按 Ctrl+C 退出）..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
    docker-compose logs -f
}

Write-Host ""
Write-Host "祝使用愉快！" -ForegroundColor Green

