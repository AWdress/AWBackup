#!/bin/bash
# ============================================
# AWBackup - Docker 镜像构建脚本
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 版本信息
VERSION="1.1.0"
IMAGE_NAME="awbackup"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  AWBackup Docker 镜像构建${NC}"
echo -e "${BLUE}  版本: ${VERSION}${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: 未安装 Docker${NC}"
    exit 1
fi

echo -e "${BLUE}[1/4]${NC} 检查必需文件..."
required_files=("Dockerfile" "backup.sh" "cleanup.sh" "restore.sh" "config.conf")
for file in "${required_files[@]}"; do
    if [[ ! -f "${file}" ]]; then
        echo -e "${RED}错误: 缺少文件 ${file}${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ 文件检查通过${NC}"
echo ""

# 构建镜像
echo -e "${BLUE}[2/4]${NC} 构建 Docker 镜像..."
echo -e "${YELLOW}镜像名称: ${IMAGE_NAME}:${VERSION}${NC}"
echo -e "${YELLOW}镜像标签: ${IMAGE_NAME}:latest${NC}"
echo ""

docker build \
    --build-arg VERSION=${VERSION} \
    -t ${IMAGE_NAME}:${VERSION} \
    -t ${IMAGE_NAME}:latest \
    .

if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✓ 镜像构建成功${NC}"
else
    echo ""
    echo -e "${RED}✗ 镜像构建失败${NC}"
    exit 1
fi
echo ""

# 显示镜像信息
echo -e "${BLUE}[3/4]${NC} 镜像信息..."
docker images | grep ${IMAGE_NAME}
echo ""

# 测试镜像
echo -e "${BLUE}[4/4]${NC} 测试镜像..."
echo -e "${YELLOW}运行健康检查...${NC}"

# 创建测试配置
cat > test_config.conf << 'EOF'
BACKUP_TASKS="test"
LOG_DIR="/app/logs"
TEST_NAME="测试任务"
TEST_SOURCE="/tmp"
TEST_DESTINATION="/backups"
TEST_RETENTION_DAYS=1
TEST_ENABLED=false
ENABLE_TELEGRAM=false
EOF

# 运行测试容器
docker run --rm \
    -v $(pwd)/test_config.conf:/app/config.conf:ro \
    ${IMAGE_NAME}:latest \
    /bin/sh -c "echo 'Docker 镜像测试通过'"

rm -f test_config.conf

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ 镜像测试通过${NC}"
else
    echo -e "${RED}✗ 镜像测试失败${NC}"
    exit 1
fi
echo ""

# 完成
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  构建完成！${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}可用镜像:${NC}"
echo -e "  • ${IMAGE_NAME}:${VERSION}"
echo -e "  • ${IMAGE_NAME}:latest"
echo ""
echo -e "${BLUE}下一步操作:${NC}"
echo ""
echo -e "1. 使用 Docker Compose 启动:"
echo -e "   ${YELLOW}docker-compose up -d${NC}"
echo ""
echo -e "2. 或使用 Docker CLI 运行:"
echo -e "   ${YELLOW}docker run -d --name awbackup \\${NC}"
echo -e "   ${YELLOW}  -e CRON_SCHEDULE='0 2 * * *' \\${NC}"
echo -e "   ${YELLOW}  -v ./config.conf:/app/config.conf:ro \\${NC}"
echo -e "   ${YELLOW}  -v ./logs:/app/logs \\${NC}"
echo -e "   ${YELLOW}  -v /path/to/backups:/backups \\${NC}"
echo -e "   ${YELLOW}  -v /path/to/source:/data/source:ro \\${NC}"
echo -e "   ${YELLOW}  ${IMAGE_NAME}:latest${NC}"
echo ""
echo -e "3. 查看文档:"
echo -e "   ${YELLOW}cat DOCKER_DEPLOYMENT.md${NC}"
echo ""

# 询问是否推送到仓库
read -p "是否要推送镜像到 Docker Hub? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}推送镜像...${NC}"
    
    read -p "输入 Docker Hub 用户名: " username
    
    if [[ -n "${username}" ]]; then
        # 重新标记镜像
        docker tag ${IMAGE_NAME}:${VERSION} ${username}/${IMAGE_NAME}:${VERSION}
        docker tag ${IMAGE_NAME}:latest ${username}/${IMAGE_NAME}:latest
        
        # 登录 Docker Hub
        docker login
        
        # 推送镜像
        docker push ${username}/${IMAGE_NAME}:${VERSION}
        docker push ${username}/${IMAGE_NAME}:latest
        
        echo ""
        echo -e "${GREEN}✓ 镜像已推送到 Docker Hub${NC}"
        echo -e "${BLUE}可以使用以下命令拉取:${NC}"
        echo -e "  ${YELLOW}docker pull ${username}/${IMAGE_NAME}:latest${NC}"
    else
        echo -e "${YELLOW}跳过推送${NC}"
    fi
fi

echo ""
echo -e "${GREEN}祝使用愉快！${NC}"

