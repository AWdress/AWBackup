#!/bin/bash
# ============================================
# AWBackup 完整功能测试脚本
# ============================================

set -e

echo "=========================================="
echo "AWBackup 完整功能测试"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 测试计数
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# 测试结果函数
test_pass() {
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
    echo -e "${GREEN}✓ PASS:${NC} $1"
}

test_fail() {
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
    echo -e "${RED}✗ FAIL:${NC} $1"
}

test_info() {
    echo -e "${YELLOW}ℹ INFO:${NC} $1"
}

# ============================================
# 测试 1: 环境检查
# ============================================
echo ""
echo "测试 1: 环境检查"
echo "----------------------------------------"

if [ -f /app/backup.sh ]; then
    test_pass "backup.sh 存在"
else
    test_fail "backup.sh 不存在"
fi

if [ -x /app/backup.sh ]; then
    test_pass "backup.sh 可执行"
else
    test_fail "backup.sh 不可执行"
fi

if command -v tar &> /dev/null; then
    test_pass "tar 命令可用"
else
    test_fail "tar 命令不可用"
fi

# ============================================
# 测试 2: 配置文件检查
# ============================================
echo ""
echo "测试 2: 配置文件检查"
echo "----------------------------------------"

if [ -f /tmp/config.conf.tmp ]; then
    CONFIG_FILE=/tmp/config.conf.tmp
    test_pass "找到配置文件: $CONFIG_FILE"
elif [ -f /app/config.conf ]; then
    CONFIG_FILE=/app/config.conf
    test_pass "找到配置文件: $CONFIG_FILE"
else
    test_fail "配置文件不存在"
    exit 1
fi

test_info "配置文件大小: $(wc -l < $CONFIG_FILE) 行"

# 尝试加载配置
if source "$CONFIG_FILE" 2>&1; then
    test_pass "配置文件加载成功"
else
    test_fail "配置文件加载失败"
    exit 1
fi

test_info "备份任务: ${BACKUP_TASKS}"
test_info "日志目录: ${LOG_DIR}"

# ============================================
# 测试 3: 创建测试数据
# ============================================
echo ""
echo "测试 3: 创建测试数据"
echo "----------------------------------------"

TEST_SOURCE="/tmp/test_backup_source"
TEST_DEST="/tmp/test_backup_dest"

# 清理旧测试数据
rm -rf "$TEST_SOURCE" "$TEST_DEST"

# 创建测试目录结构
mkdir -p "$TEST_SOURCE/dir1/subdir1"
mkdir -p "$TEST_SOURCE/dir2"
mkdir -p "$TEST_DEST"

# 创建测试文件
echo "测试文件 1" > "$TEST_SOURCE/file1.txt"
echo "测试文件 2" > "$TEST_SOURCE/dir1/file2.txt"
echo "测试文件 3" > "$TEST_SOURCE/dir1/subdir1/file3.txt"
echo "测试文件 4" > "$TEST_SOURCE/dir2/file4.txt"

# 创建一些二进制数据
dd if=/dev/urandom of="$TEST_SOURCE/binary1.dat" bs=1M count=1 2>/dev/null
dd if=/dev/urandom of="$TEST_SOURCE/dir2/binary2.dat" bs=1M count=2 2>/dev/null

if [ -d "$TEST_SOURCE" ]; then
    test_pass "测试源目录创建成功"
    test_info "源目录: $TEST_SOURCE"
    test_info "文件数量: $(find $TEST_SOURCE -type f | wc -l)"
    test_info "总大小: $(du -sh $TEST_SOURCE | awk '{print $1}')"
else
    test_fail "测试源目录创建失败"
    exit 1
fi

# ============================================
# 测试 4: 创建临时测试配置
# ============================================
echo ""
echo "测试 4: 创建测试配置"
echo "----------------------------------------"

TEST_CONFIG="/tmp/test_config.conf"

cat > "$TEST_CONFIG" << 'EOF'
# 测试配置
BACKUP_TASKS="testbackup"
LOG_DIR="/tmp/test_logs"
LOG_RETENTION_DAYS=7
ENABLE_NOTIFICATION=false
NOTIFY_ON_ERROR=true
NOTIFY_ON_SUCCESS=true
TEMP_DIR="/tmp/backup_temp"
DEFAULT_COMPRESS_LEVEL=1
VERIFY_BACKUP=true
PARALLEL_TASKS=1

# Telegram
ENABLE_TELEGRAM=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
TELEGRAM_NOTIFY_ON_SUCCESS=false
TELEGRAM_NOTIFY_ON_ERROR=false
TELEGRAM_NOTIFY_ON_START=false
TELEGRAM_BOT_CONTROL=false

# 测试任务
TESTBACKUP_NAME="测试备份"
TESTBACKUP_SOURCE="/tmp/test_backup_source"
TESTBACKUP_DESTINATION="/tmp/test_backup_dest"
TESTBACKUP_RETENTION_DAYS=7
TESTBACKUP_COMPRESS_LEVEL=1
TESTBACKUP_EXCLUDE=""
TESTBACKUP_PRE_BACKUP_CMD=""
TESTBACKUP_POST_BACKUP_CMD=""
TESTBACKUP_ENABLED=true

# 性能
USE_IONICE=false
USE_NICE=false
USE_PIGZ=false

# 调试
DEBUG=false
DRY_RUN=false

# 远程
ENABLE_REMOTE_BACKUP=false

# 命名
DATE_FORMAT="%Y%m%d_%H%M%S"
BACKUP_NAME_FORMAT="{TASK_NAME}_backup_{DATE}.tar.gz"
EOF

if [ -f "$TEST_CONFIG" ]; then
    test_pass "测试配置创建成功"
    test_info "配置文件: $TEST_CONFIG"
else
    test_fail "测试配置创建失败"
    exit 1
fi

# ============================================
# 测试 5: 执行备份
# ============================================
echo ""
echo "测试 5: 执行备份"
echo "----------------------------------------"

test_info "开始执行备份..."

# 执行备份并捕获输出
export CONFIG_FILE="$TEST_CONFIG"
BACKUP_OUTPUT=$(CONFIG_FILE="$TEST_CONFIG" /app/backup.sh 2>&1)
BACKUP_RESULT=$?

echo "$BACKUP_OUTPUT"

if [ $BACKUP_RESULT -eq 0 ]; then
    test_pass "备份执行成功 (退出代码: $BACKUP_RESULT)"
else
    test_fail "备份执行失败 (退出代码: $BACKUP_RESULT)"
    echo ""
    echo "备份输出:"
    echo "$BACKUP_OUTPUT"
fi

# ============================================
# 测试 6: 验证备份文件
# ============================================
echo ""
echo "测试 6: 验证备份文件"
echo "----------------------------------------"

# 查找备份文件
BACKUP_FILE=$(find "$TEST_DEST" -name "*.tar.gz" | head -1)

if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
    test_pass "备份文件已创建"
    test_info "备份文件: $BACKUP_FILE"
    test_info "文件大小: $(ls -lh "$BACKUP_FILE" | awk '{print $5}')"
else
    test_fail "备份文件不存在"
    test_info "目标目录内容:"
    ls -lh "$TEST_DEST"
    BACKUP_FILE=""
fi

# 验证备份完整性
if [ -n "$BACKUP_FILE" ]; then
    if tar -tzf "$BACKUP_FILE" > /dev/null 2>&1; then
        test_pass "备份文件完整性验证通过"
        
        # 列出备份内容
        test_info "备份内容:"
        tar -tzf "$BACKUP_FILE" | head -10
        
        FILE_COUNT=$(tar -tzf "$BACKUP_FILE" | wc -l)
        test_info "备份包含 $FILE_COUNT 个文件/目录"
    else
        test_fail "备份文件损坏"
    fi
fi

# ============================================
# 测试 7: 恢复测试
# ============================================
echo ""
echo "测试 7: 恢复测试"
echo "----------------------------------------"

if [ -n "$BACKUP_FILE" ]; then
    TEST_RESTORE="/tmp/test_restore"
    rm -rf "$TEST_RESTORE"
    mkdir -p "$TEST_RESTORE"
    
    if tar -xzf "$BACKUP_FILE" -C "$TEST_RESTORE" 2>&1; then
        test_pass "备份文件解压成功"
        
        # 验证文件
        RESTORE_FILE_COUNT=$(find "$TEST_RESTORE" -type f | wc -l)
        test_info "恢复了 $RESTORE_FILE_COUNT 个文件"
        
        # 检查特定文件
        if [ -f "$TEST_RESTORE/test_backup_source/file1.txt" ]; then
            test_pass "文件恢复验证成功"
        else
            test_fail "文件恢复验证失败"
        fi
    else
        test_fail "备份文件解压失败"
    fi
fi

# ============================================
# 测试 8: 清理测试数据
# ============================================
echo ""
echo "测试 8: 清理测试数据"
echo "----------------------------------------"

rm -rf "$TEST_SOURCE" "$TEST_DEST" "$TEST_CONFIG" "/tmp/test_logs" "/tmp/test_restore"

if [ ! -d "$TEST_SOURCE" ]; then
    test_pass "测试数据清理成功"
else
    test_fail "测试数据清理失败"
fi

# ============================================
# 测试总结
# ============================================
echo ""
echo "=========================================="
echo "测试总结"
echo "=========================================="
echo "总测试数: $TESTS_TOTAL"
echo -e "${GREEN}通过: $TESTS_PASSED${NC}"
echo -e "${RED}失败: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ 所有测试通过！${NC}"
    echo "AWBackup 功能正常，可以开始使用。"
    exit 0
else
    echo ""
    echo -e "${RED}✗ 有 $TESTS_FAILED 个测试失败！${NC}"
    echo "请检查上面的错误信息。"
    exit 1
fi

