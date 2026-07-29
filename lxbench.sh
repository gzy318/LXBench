#!/usr/bin/env bash
#
# LXBench 2.1.0 - 全能VPS服务器测评脚本
#
# GitHub: https://github.com/gzy318/LXBench
# 服务器推荐: https://www.rainyun.com/xls_
# 个人博客: https://twbk.cn
#
# v2.1.0 更新:
#   1. 重新设计评分规则（更科学合理）
#   2. 新增"无UnixBench模式"（快速测试选项）
#   3. HTML报告全面美化
#   4. 控制台完整输出保存为HTML（便于分享）
#   5. 增加评分雷达图展示

set -euo pipefail
export LC_ALL=C LANG=C

# ============================================================
# 版本信息
# ============================================================
VERSION="2.1.0"
GITHUB_URL="https://github.com/gzy318/LXBench"
RAINYUN_URL="https://www.rainyun.com/xls_"
BLOG_URL="https://twbk.cn"

# ============================================================
# 颜色定义
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'
PLAIN='\033[0m'

# ============================================================
# 全局变量
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${SCRIPT_DIR}/lxbench_reports"
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
HTML_REPORT="${REPORT_DIR}/lxbench_${TIMESTAMP}.html"
MD_REPORT="${REPORT_DIR}/lxbench_${TIMESTAMP}.md"
FULL_LOG="${REPORT_DIR}/lxbench_${TIMESTAMP}.log"
SERVER_LOCATION="unknown"
SERVER_COUNTRY=""
SERVER_CITY=""
SERVER_ISP=""
SCORE_TOTAL=0
SCORE_CPU=0
SCORE_MEMORY=0
SCORE_DISK=0
SCORE_NETWORK=0
SCORE_IP=0
TEST_MODE="full"
UNIXBENCH_AVAILABLE=true

# 用于收集完整输出
FULL_OUTPUT=""
export FULL_OUTPUT

# ============================================================
# 工具函数
# ============================================================
print_banner() {
    local banner="
${CYAN}
  ╔═══════════════════════════════════════════════════════════════════╗
  ║                                                                   ║
  ║   ██╗     ██╗  ██╗██████╗ ███████╗███╗   ██╗ ██████╗██╗  ██╗    ║
  ║   ██║     ╚██╗██╔╝██╔══██╗██╔════╝████╗  ██║██╔════╝██║  ██║    ║
  ║   ██║      ╚███╔╝ ██████╔╝█████╗  ██╔██╗ ██║██║     ███████║    ║
  ║   ██║      ██╔██╗ ██╔══██╗██╔══╝  ██║╚██╗██║██║     ██╔══██║    ║
  ║   ███████╗██╔╝ ██╗██████╔╝███████╗██║ ╚████║╚██████╗██║  ██║    ║
  ║   ╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝    ║
  ║                                                                   ║
  ║            全能VPS服务器测评脚本 v${VERSION}                      ║
  ║       智能双模节点 · 科学评分体系 · 完整HTML报告                  ║
  ║                                                                   ║
  ╚═══════════════════════════════════════════════════════════════════╝
${PLAIN}"

    echo -e "$banner"
    echo -e "${CYAN}📦 ${GITHUB_URL}${PLAIN}"
    echo -e "${CYAN}🚀 ${RAINYUN_URL}${PLAIN}"
    echo -e "${CYAN}📝 ${BLOG_URL}${PLAIN}"
    echo ""
}

print_title() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e "${BOLD}${CYAN}  $1${PLAIN}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
}

print_ok() { echo -e "${GREEN}[✔]${PLAIN} $1"; }
print_info() { echo -e "${BLUE}[i]${PLAIN} $1"; }
print_warn() { echo -e "${YELLOW}[!]${PLAIN} $1"; }
print_error() { echo -e "${RED}[✘]${PLAIN} $1"; }
print_progress() { echo -e "${DIM}[⏳]${PLAIN} $1"; }

colorize_latency() {
    local lat="$1"
    if [ -z "$lat" ] || [ "$lat" = "超时" ] || [ "$lat" = "0" ]; then
        echo -e "${DIM}--${PLAIN}"
    elif (( $(echo "$lat < 50" | bc -l) )); then
        echo -e "${GREEN}${lat}ms${PLAIN}"
    elif (( $(echo "$lat < 150" | bc -l) )); then
        echo -e "${YELLOW}${lat}ms${PLAIN}"
    else
        echo -e "${RED}${lat}ms${PLAIN}"
    fi
}

# ============================================================
# 系统检测
# ============================================================
get_release() {
    if [ -f /etc/redhat-release ]; then echo "centos"
    elif cat /etc/issue 2>/dev/null | grep -Eqi "debian"; then echo "debian"
    elif cat /etc/issue 2>/dev/null | grep -Eqi "ubuntu"; then echo "ubuntu"
    elif cat /proc/version 2>/dev/null | grep -Eqi "debian"; then echo "debian"
    elif cat /proc/version 2>/dev/null | grep -Eqi "ubuntu"; then echo "ubuntu"
    elif cat /proc/version 2>/dev/null | grep -Eqi "centos|red hat|redhat"; then echo "centos"
    else echo "unknown"; fi
}
RELEASE=$(get_release)

# ============================================================
# 交互模式选择
# ============================================================
select_mode() {
    echo ""
    echo -e "${BOLD}请选择测试模式:${PLAIN}"
    echo "  1) 完整测试 (全部项目，含UnixBench，约15-20分钟)"
    echo "  2) 快速测试 (跳过UnixBench和Geekbench，约5-8分钟)  ← 推荐日常使用"
    echo "  3) 仅网络测试 (延迟+路由+测速)"
    echo "  4) 仅性能测试 (CPU+内存+磁盘，不含UnixBench)"
    echo "  5) 仅流媒体+IP质量"
    echo "  6) 极简测试 (仅系统信息+基础性能，约3分钟)"
    echo ""
    read -p "请输入选项 [1-6，默认2]: " mode_choice
    case "${mode_choice:-2}" in
        1) TEST_MODE="full" ;;
        2) TEST_MODE="quick" ;;
        3) TEST_MODE="network" ;;
        4) TEST_MODE="performance" ;;
        5) TEST_MODE="streaming" ;;
        6) TEST_MODE="minimal" ;;
        *) TEST_MODE="quick" ;;
    esac
    
    if [ "$TEST_MODE" = "quick" ] || [ "$TEST_MODE" = "performance" ] || [ "$TEST_MODE" = "minimal" ]; then
        UNIXBENCH_AVAILABLE=false
    fi
    
    local mode_names=(
        "完整测试 (含UnixBench)"
        "快速测试 (跳过UnixBench)"
        "仅网络测试"
        "仅性能测试"
        "仅流媒体+IP质量"
        "极简测试"
    )
    local idx=$((TEST_MODE == "full" ? 0 : TEST_MODE == "quick" ? 1 : TEST_MODE == "network" ? 2 : TEST_MODE == "performance" ? 3 : TEST_MODE == "streaming" ? 4 : 5))
    print_info "已选择: ${mode_names[$idx]}"
}

# ============================================================
# 安装依赖
# ============================================================
install_deps() {
    local deps=()
    case "$RELEASE" in
        centos)
            command -v curl >/dev/null 2>&1 || deps+=("curl")
            command -v wget >/dev/null 2>&1 || deps+=("wget")
            command -v bc >/dev/null 2>&1 || deps+=("bc")
            command -v sysbench >/dev/null 2>&1 || deps+=("sysbench")
            command -v fio >/dev/null 2>&1 || deps+=("fio")
            command -v jq >/dev/null 2>&1 || deps+=("jq")
            command -v mtr >/dev/null 2>&1 || deps+=("mtr")
            command -v traceroute >/dev/null 2>&1 || deps+=("traceroute")
            command -v ioping >/dev/null 2>&1 || deps+=("ioping")
            if [ ${#deps[@]} -gt 0 ]; then
                yum update -y >/dev/null 2>&1 || true
                yum install -y epel-release >/dev/null 2>&1 || true
                yum install -y "${deps[@]}" >/dev/null 2>&1 || true
            fi
            ;;
        debian|ubuntu)
            command -v curl >/dev/null 2>&1 || deps+=("curl")
            command -v wget >/dev/null 2>&1 || deps+=("wget")
            command -v bc >/dev/null 2>&1 || deps+=("bc")
            command -v sysbench >/dev/null 2>&1 || deps+=("sysbench")
            command -v fio >/dev/null 2>&1 || deps+=("fio")
            command -v jq >/dev/null 2>&1 || deps+=("jq")
            command -v mtr >/dev/null 2>&1 || deps+=("mtr")
            command -v traceroute >/dev/null 2>&1 || deps+=("traceroute")
            command -v ioping >/dev/null 2>&1 || deps+=("ioping")
            if [ ${#deps[@]} -gt 0 ]; then
                apt-get update -y >/dev/null 2>&1 || true
                apt-get install -y "${deps[@]}" >/dev/null 2>&1 || true
            fi
            ;;
        *) print_warn "未知系统，尝试继续..." ;;
    esac
    print_ok "依赖检查完成"
}

# ============================================================
# 1. 地理位置检测
# ============================================================
detect_location() {
    print_title "📍 地理位置智能检测"
    print_progress "正在检测服务器IP归属地..."

    local ip_info=$(curl -s --max-time 5 "http://ip-api.com/json/" 2>/dev/null || echo "")
    if [ -n "$ip_info" ] && echo "$ip_info" | grep -q '"status":"success"'; then
        SERVER_COUNTRY=$(echo "$ip_info" | grep -o '"country":"[^"]*"' | cut -d'"' -f4 | head -1)
        SERVER_CITY=$(echo "$ip_info" | grep -o '"city":"[^"]*"' | cut -d'"' -f4 | head -1)
        SERVER_ISP=$(echo "$ip_info" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4 | head -1)
        local country_code=$(echo "$ip_info" | grep -o '"countryCode":"[^"]*"' | cut -d'"' -f4 | head -1)
        if [ "$country_code" = "CN" ] || [ "$SERVER_COUNTRY" = "China" ] || [ "$SERVER_COUNTRY" = "中国" ]; then
            SERVER_LOCATION="china"
        else
            SERVER_LOCATION="international"
        fi
    fi

    echo ""
    echo -e "${BOLD}服务器位置${PLAIN}    : ${CYAN}${SERVER_COUNTRY:-未知} - ${SERVER_CITY:-未知}${PLAIN}"
    echo -e "${BOLD}运营商${PLAIN}        : ${CYAN}${SERVER_ISP:-未知}${PLAIN}"

    if [ "$SERVER_LOCATION" = "china" ]; then
        echo -e "${BOLD}检测结果${PLAIN}        : ${GREEN}🇨🇳 中国大陆服务器 → 启用国内三网测试节点${PLAIN}"
    elif [ "$SERVER_LOCATION" = "international" ]; then
        echo -e "${BOLD}检测结果${PLAIN}        : ${BLUE}🌍 海外服务器 → 启用国际测试节点 + 国内回程测试${PLAIN}"
        print_ok "将额外测试到中国大陆的回程延迟和路由"
    else
        SERVER_LOCATION="mixed"
    fi
}

# ============================================================
# 2. 系统信息
# ============================================================
collect_system_info() {
    print_title "💻 系统信息"

    local cpu_model=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')
    local cpu_cores=$(grep -c "processor" /proc/cpuinfo)
    local cpu_arch=$(uname -m)
    local cpu_virt=$(systemd-detect-virt 2>/dev/null || echo "未知")
    local mem_total=$(free -h | grep "^Mem:" | awk '{print $2}')
    local mem_used=$(free -h | grep "^Mem:" | awk '{print $3}')
    local mem_free=$(free -h | grep "^Mem:" | awk '{print $4}')
    local swap_total=$(free -h | grep "^Swap:" | awk '{print $2}')
    local disk_total=$(df -h / | tail -n1 | awk '{print $2}')
    local disk_used=$(df -h / | tail -n1 | awk '{print $3}')
    local disk_use_percent=$(df -h / | tail -n1 | awk '{print $5}')
    local os_version=""
    [ -f /etc/os-release ] && os_version=$(grep "PRETTY_NAME" /etc/os-release | cut -d= -f2 | sed 's/"//g') || os_version=$(uname -s -r)
    local kernel_version=$(uname -r)
    local uptime=$(uptime -p | sed 's/up //')
    local loadavg=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
    local bbr_status="未开启"
    sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr" && bbr_status="已开启 ✅"

    echo -e "${BOLD}操作系统${PLAIN}      : $os_version"
    echo -e "${BOLD}内核版本${PLAIN}      : $kernel_version"
    echo -e "${BOLD}CPU 型号${PLAIN}      : $cpu_model"
    echo -e "${BOLD}CPU 核心数${PLAIN}    : $cpu_cores (架构: $cpu_arch)"
    echo -e "${BOLD}虚拟化类型${PLAIN}    : $cpu_virt"
    echo -e "${BOLD}内存${PLAIN}          : $mem_total (已用: $mem_used, 空闲: $mem_free)"
    [ "$swap_total" != "0" ] && echo -e "${BOLD}Swap${PLAIN}          : $swap_total"
    echo -e "${BOLD}磁盘${PLAIN}          : $disk_total (已用: $disk_used, 使用率: $disk_use_percent)"
    echo -e "${BOLD}运行时间${PLAIN}      : $uptime"
    echo -e "${BOLD}系统负载${PLAIN}      : $loadavg"
    echo -e "${BOLD}BBR加速${PLAIN}       : $bbr_status"
    
    # 保存系统信息用于报告
    SYS_INFO_OS="$os_version"
    SYS_INFO_KERNEL="$kernel_version"
    SYS_INFO_CPU="$cpu_model"
    SYS_INFO_CORES="$cpu_cores"
    SYS_INFO_MEM="$mem_total"
    SYS_INFO_DISK="$disk_total"
}

# ============================================================
# 3. CPU诚信度检测
# ============================================================
test_cpu_integrity() {
    print_title "🔍 CPU诚信度/超卖检测"
    print_info "检测Steal Time和Kernel Latency，判断VPS是否被超卖"

    local steal_sum=0
    local latency_sum=0
    local samples=10

    for i in $(seq 1 $samples); do
        local steal=$(top -bn1 | grep "Cpu(s)" | awk '{print $NF}' | cut -d'%' -f1 2>/dev/null || echo "0")
        [ -z "$steal" ] && steal=0
        steal_sum=$(echo "$steal_sum + $steal" | bc 2>/dev/null || echo "$steal_sum")
        local latency=$(vmstat 1 2 | tail -n1 | awk '{print $1}' 2>/dev/null || echo "0")
        [ -z "$latency" ] && latency=0
        latency_sum=$(echo "$latency_sum + $latency" | bc 2>/dev/null || echo "$latency_sum")
        sleep 0.5
    done

    local steal_avg=$(echo "scale=2; $steal_sum / $samples" | bc 2>/dev/null || echo "0")
    local latency_avg=$(echo "scale=2; $latency_sum / $samples" | bc 2>/dev/null || echo "0")

    echo -e "${BOLD}Steal Time (平均)${PLAIN}  : ${CYAN}${steal_avg}%${PLAIN}"
    echo -e "${BOLD}Kernel Latency (平均)${PLAIN}: ${CYAN}${latency_avg}ms${PLAIN}"

    if (( $(echo "$steal_avg < 0.5" | bc -l) )); then
        echo -e "${BOLD}超卖检测${PLAIN}        : ${GREEN}✅ 正常 (无超卖) ★★★★★${PLAIN}"
        SCORE_STEAL=10
    elif (( $(echo "$steal_avg < 2.0" | bc -l) )); then
        echo -e "${BOLD}超卖检测${PLAIN}        : ${YELLOW}⚠️ 轻度超卖 ★★★${PLAIN}"
        SCORE_STEAL=6
    else
        echo -e "${BOLD}超卖检测${PLAIN}        : ${RED}❌ 严重超卖 ★${PLAIN}"
        SCORE_STEAL=2
    fi
}

# ============================================================
# 4. CPU性能测试 (不含UnixBench)
# ============================================================
test_cpu() {
    print_title "⚡ CPU性能测试"

    local single="N/A"
    local multi="N/A"
    
    if command -v sysbench >/dev/null 2>&1; then
        print_progress "sysbench 单核测试..."
        single=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>/dev/null | grep "events per second" | awk '{print $4}')
        print_progress "sysbench 多核测试..."
        multi=$(sysbench cpu --cpu-max-prime=20000 --threads=$(nproc) run 2>/dev/null | grep "events per second" | awk '{print $4}')
        echo -e "${BOLD}sysbench 单核${PLAIN}    : ${GREEN}${single}${PLAIN} events/s"
        echo -e "${BOLD}sysbench 多核${PLAIN}    : ${GREEN}${multi}${PLAIN} events/s"
        
        # 保存
        SYSBENCH_SINGLE="$single"
        SYSBENCH_MULTI="$multi"
    fi

    # Geekbench 5 (full模式下运行)
    if [ "$TEST_MODE" = "full" ]; then
        print_progress "Geekbench 5 测试 (约3-5分钟)..."
        if command -v wget >/dev/null 2>&1; then
            local gb_output=$(wget -qO- https://raw.githubusercontent.com/mikeyang01/benchmark-script/master/geekbench5.sh 2>/dev/null | bash 2>/dev/null || echo "")
            local gb_single=$(echo "$gb_output" | grep -o "Single-Core Score[^0-9]*[0-9]*" | grep -o "[0-9]*" | head -1)
            local gb_multi=$(echo "$gb_output" | grep -o "Multi-Core Score[^0-9]*[0-9]*" | grep -o "[0-9]*" | head -1)
            [ -n "$gb_single" ] && echo -e "${BOLD}Geekbench 5 单核${PLAIN}  : ${GREEN}${gb_single}${PLAIN}"
            [ -n "$gb_multi" ] && echo -e "${BOLD}Geekbench 5 多核${PLAIN}  : ${GREEN}${gb_multi}${PLAIN}"
            GB_SINGLE="${gb_single:-N/A}"
            GB_MULTI="${gb_multi:-N/A}"
        fi
    else
        echo -e "${DIM}Geekbench 5: 已跳过 (使用快速模式)${PLAIN}"
        GB_SINGLE="已跳过"
        GB_MULTI="已跳过"
    fi

    # UnixBench (仅在完整模式)
    if [ "$TEST_MODE" = "full" ] && [ "$UNIXBENCH_AVAILABLE" = true ]; then
        print_progress "UnixBench 测试 (约5-8分钟)..."
        if command -v wget >/dev/null 2>&1; then
            local ub_output=$(wget -qO- https://raw.githubusercontent.com/teddysun/across/master/unixbench.sh 2>/dev/null | bash 2>/dev/null || echo "")
            local ub_score=$(echo "$ub_output" | grep -o "Benchmark Run:[^0-9]*[0-9.]*" | grep -o "[0-9.]*" | tail -1)
            [ -n "$ub_score" ] && echo -e "${BOLD}UnixBench 总分${PLAIN}    : ${GREEN}${ub_score}${PLAIN}"
            UNIXBENCH_SCORE="${ub_score:-N/A}"
        fi
    else
        echo -e "${DIM}UnixBench: 已跳过 (使用快速模式或无UnixBench模式)${PLAIN}"
        UNIXBENCH_SCORE="已跳过"
    fi
}

# ============================================================
# 5. 内存性能测试
# ============================================================
test_memory() {
    print_title "🧠 内存性能测试"
    if ! command -v sysbench >/dev/null 2>&1; then
        print_error "sysbench未安装"
        MEM_READ="N/A"
        MEM_WRITE="N/A"
        MEM_LATENCY="N/A"
        return 1
    fi
    local mem_read=$(sysbench memory --memory-total-size=1G --memory-oper=read run 2>/dev/null | grep "MiB transferred" | awk '{print $4}')
    local mem_write=$(sysbench memory --memory-total-size=1G --memory-oper=write run 2>/dev/null | grep "MiB transferred" | awk '{print $4}')
    local mem_latency=$(sysbench memory --memory-total-size=1G --memory-oper=read run 2>/dev/null | grep "avg:" | awk '{print $3}')
    echo -e "${BOLD}内存读取速度${PLAIN}   : ${GREEN}${mem_read:-N/A}${PLAIN} MiB/s"
    echo -e "${BOLD}内存写入速度${PLAIN}   : ${GREEN}${mem_write:-N/A}${PLAIN} MiB/s"
    echo -e "${BOLD}内存延迟${PLAIN}       : ${mem_latency:-N/A} ns"
    
    MEM_READ="${mem_read:-N/A}"
    MEM_WRITE="${mem_write:-N/A}"
    MEM_LATENCY="${mem_latency:-N/A}"
}

# ============================================================
# 6. 磁盘I/O测试
# ============================================================
test_disk() {
    print_title "💾 磁盘I/O测试"

    local test_file="/tmp/lxbench_io_test"
    local write_sum=0 read_sum=0
    local write_count=0 read_count=0
    for i in {1..3}; do
        local w=$(dd if=/dev/zero of="$test_file" bs=1M count=512 conv=fdatasync 2>&1 | tail -n1 | awk '{print $(NF-1)}' 2>/dev/null)
        local r=$(dd if="$test_file" of=/dev/null bs=1M count=512 2>&1 | tail -n1 | awk '{print $(NF-1)}' 2>/dev/null)
        [ -n "$w" ] && { write_sum=$(echo "$write_sum + $w" | bc); write_count=$((write_count + 1)); }
        [ -n "$r" ] && { read_sum=$(echo "$read_sum + $r" | bc); read_count=$((read_count + 1)); }
        rm -f "$test_file"
    done
    local write_avg="N/A"; [ $write_count -gt 0 ] && write_avg=$(echo "scale=2; $write_sum / $write_count" | bc)
    local read_avg="N/A"; [ $read_count -gt 0 ] && read_avg=$(echo "scale=2; $read_sum / $read_count" | bc)
    echo -e "${BOLD}顺序写入 (平均)${PLAIN} : ${GREEN}${write_avg}${PLAIN} MB/s"
    echo -e "${BOLD}顺序读取 (平均)${PLAIN} : ${GREEN}${read_avg}${PLAIN} MB/s"
    
    DISK_WRITE="$write_avg"
    DISK_READ="$read_avg"

    if command -v fio >/dev/null 2>&1; then
        print_progress "测试4K随机读写 (fio)..."
        local fio_out=$(fio --name=lxbench_4k --size=512M --filename=/tmp/lxbench_fio_test \
            --bs=4k --rw=randrw --ioengine=libaio --iodepth=64 --runtime=20 \
            --numjobs=4 --group_reporting 2>/dev/null || echo "")
        local rand_read=$(echo "$fio_out" | grep "read:" | grep "IOPS" | head -n1 | awk '{print $2}')
        local rand_write=$(echo "$fio_out" | grep "write:" | grep "IOPS" | head -n1 | awk '{print $2}')
        echo -e "${BOLD}4K随机读取${PLAIN}     : ${GREEN}${rand_read:-N/A}${PLAIN} IOPS"
        echo -e "${BOLD}4K随机写入${PLAIN}     : ${GREEN}${rand_write:-N/A}${PLAIN} IOPS"
        rm -f /tmp/lxbench_fio_test
        DISK_RAND_READ="${rand_read:-N/A}"
        DISK_RAND_WRITE="${rand_write:-N/A}"
    else
        DISK_RAND_READ="N/A"
        DISK_RAND_WRITE="N/A"
    fi

    if command -v ioping >/dev/null 2>&1; then
        local iop=$(ioping -c 5 . 2>/dev/null | tail -n1 | awk '{print $4}' | tr -d 'ms' 2>/dev/null)
        [ -n "$iop" ] && echo -e "${BOLD}磁盘访问延迟${PLAIN}   : ${GREEN}${iop}${PLAIN} ms"
        DISK_IOPING="${iop:-N/A}"
    else
        DISK_IOPING="N/A"
    fi
}

# ============================================================
# 7. 网络测试
# ============================================================
test_network() {
    print_title "🌐 网络质量测试"
    echo -e "${BOLD}📍 当前测试模式${PLAIN}: ${CYAN}${SERVER_LOCATION}${PLAIN}"
    echo ""

    if [ "$SERVER_LOCATION" = "china" ]; then
        test_network_china
    elif [ "$SERVER_LOCATION" = "international" ]; then
        test_network_international
        test_network_china_return
    else
        test_network_mixed
    fi

    test_backtrace_full
    test_traceroute_inbound
    test_speedtest_multi
}

test_network_china() {
    echo -e "${BOLD}${CYAN}--- 国内三网延迟测试 (15节点) ---${PLAIN}"
    echo -e "${DIM}(绿色<50ms | 黄色50-150ms | 红色>150ms)${PLAIN}"
    echo ""

    local nodes=(
        "上海电信:180.153.0.1" "北京电信:219.141.136.10" "广州电信:183.56.128.1"
        "成都电信:61.139.2.69" "武汉电信:58.49.0.1"
        "上海联通:210.22.97.1" "北京联通:123.125.128.1" "广州联通:210.21.196.6"
        "郑州联通:218.29.0.1" "沈阳联通:219.148.0.1"
        "上海移动:211.136.112.50" "北京移动:211.136.28.228" "广州移动:211.139.145.129"
        "杭州移动:211.140.13.188" "西安移动:211.137.130.1"
    )
    local lat_sum=0 lat_count=0
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 2 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
            lat_sum=$(echo "$lat_sum + $lat" | bc 2>/dev/null || echo "$lat_sum")
            lat_count=$((lat_count + 1))
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
    if [ $lat_count -gt 0 ]; then
        NET_AVG_LAT=$(echo "scale=2; $lat_sum / $lat_count" | bc 2>/dev/null || echo "0")
    else
        NET_AVG_LAT="0"
    fi
}

test_network_international() {
    echo -e "${BOLD}${CYAN}--- 全球网络延迟测试 (15节点) ---${PLAIN}"
    echo ""

    local nodes=(
        "香港:203.80.96.10" "新加坡:103.7.8.10" "东京:103.28.248.1"
        "首尔:211.234.83.1" "台北:168.95.1.1"
        "洛杉矶:208.67.222.222" "纽约:8.8.8.8" "温哥华:209.121.10.1"
        "伦敦:8.8.4.4" "法兰克福:1.1.1.1" "巴黎:80.12.1.1"
        "悉尼:203.6.240.1" "迪拜:176.44.1.1" "孟买:8.8.8.8"
        "莫斯科:5.45.100.1"
    )
    local lat_sum=0 lat_count=0
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 4 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
            lat_sum=$(echo "$lat_sum + $lat" | bc 2>/dev/null || echo "$lat_sum")
            lat_count=$((lat_count + 1))
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
    if [ $lat_count -gt 0 ]; then
        NET_AVG_LAT=$(echo "scale=2; $lat_sum / $lat_count" | bc 2>/dev/null || echo "0")
    else
        NET_AVG_LAT="0"
    fi
}

test_network_china_return() {
    echo ""
    echo -e "${BOLD}${CYAN}--- 🌏 海外→中国大陆回程延迟 ---${PLAIN}"
    print_info "测试从海外服务器到中国主要城市的延迟 (对国内用户访问体验至关重要)"
    echo ""

    local cn_nodes=(
        "上海电信:180.153.0.1" "北京电信:219.141.136.10" "广州电信:183.56.128.1"
        "成都电信:61.139.2.69" "上海联通:210.22.97.1" "北京联通:123.125.128.1"
        "广州联通:210.21.196.6" "上海移动:211.136.112.50" "北京移动:211.136.28.228"
        "广州移动:211.139.145.129"
    )
    local lat_sum=0 lat_count=0
    for node in "${cn_nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 5 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-16s : " "$name"
        if [ -n "$lat" ]; then
            if (( $(echo "$lat < 100" | bc -l) )); then
                echo -e "${GREEN}${lat}ms (优秀)${PLAIN}"
            elif (( $(echo "$lat < 200" | bc -l) )); then
                echo -e "${YELLOW}${lat}ms (一般)${PLAIN}"
            else
                echo -e "${RED}${lat}ms (较差)${PLAIN}"
            fi
            lat_sum=$(echo "$lat_sum + $lat" | bc 2>/dev/null || echo "$lat_sum")
            lat_count=$((lat_count + 1))
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
    if [ $lat_count -gt 0 ]; then
        NET_CN_AVG=$(echo "scale=2; $lat_sum / $lat_count" | bc 2>/dev/null || echo "0")
    else
        NET_CN_AVG="0"
    fi
}

test_network_mixed() {
    echo -e "${BOLD}${CYAN}--- 混合网络延迟测试 ---${PLAIN}"
    local nodes=("香港:203.80.96.10" "新加坡:103.7.8.10" "东京:103.28.248.1"
        "洛杉矶:208.67.222.222" "上海:180.153.0.1" "北京:219.141.136.10" "广州:183.56.128.1")
    local lat_sum=0 lat_count=0
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 3 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
            lat_sum=$(echo "$lat_sum + $lat" | bc 2>/dev/null || echo "$lat_sum")
            lat_count=$((lat_count + 1))
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
    if [ $lat_count -gt 0 ]; then
        NET_AVG_LAT=$(echo "scale=2; $lat_sum / $lat_count" | bc 2>/dev/null || echo "0")
    else
        NET_AVG_LAT="0"
    fi
}

# ============================================================
# 8. 五网回程路由
# ============================================================
test_backtrace_full() {
    echo ""
    print_title "🔄 五网回程路由测试"
    print_info "测试服务器到五大运营商骨干网的回程路径"
    echo ""

    local back_nodes=(
        "电信(广州):183.56.128.1"
        "联通(广州):210.21.196.6"
        "移动(广州):211.139.145.129"
        "教育网(北京):101.6.6.6"
        "科技网(北京):159.226.1.1"
    )
    
    BACKTRACE_RESULT=""
    if command -v nexttrace >/dev/null 2>&1; then
        for node in "${back_nodes[@]}"; do
            local name=$(echo "$node" | cut -d: -f1)
            local ip=$(echo "$node" | cut -d: -f2)
            echo -n "  ${name}: "
            local result=$(nexttrace -q 1 -m 10 "$ip" 2>/dev/null | grep -E "ms|hop" | head -3 | tr '\n' ' ' | cut -c1-70 || echo "无法检测")
            echo "$result"
            BACKTRACE_RESULT="${BACKTRACE_RESULT}${name}: ${result}\n"
        done
    elif command -v traceroute >/dev/null 2>&1; then
        for node in "${back_nodes[@]}"; do
            local name=$(echo "$node" | cut -d: -f1)
            local ip=$(echo "$node" | cut -d: -f2)
            local hops=$(traceroute -n -m 8 "$ip" 2>/dev/null | wc -l)
            echo "  ${name}: $((hops - 1)) 跳"
            BACKTRACE_RESULT="${BACKTRACE_RESULT}${name}: $((hops - 1)) 跳\n"
        done
    else
        print_warn "未安装 traceroute/nexttrace"
        BACKTRACE_RESULT="未安装 traceroute/nexttrace"
    fi
}

# ============================================================
# 9. 去程路由检测
# ============================================================
test_traceroute_inbound() {
    print_title "📥 去程路由检测"
    print_info "从国内节点到服务器的路由路径 (判断国内用户访问是否最优)"
    echo ""

    local server_ip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "未知")
    echo -e "${BOLD}服务器IP${PLAIN}: ${CYAN}${server_ip}${PLAIN}"
    echo ""

    if command -v mtr >/dev/null 2>&1; then
        local test_ips=("180.153.0.1" "210.22.97.1" "211.136.112.50")
        local test_names=("上海电信" "上海联通" "上海移动")
        for i in "${!test_ips[@]}"; do
            echo -n "  从 ${test_names[$i]} 到本机: "
            mtr -r -c 3 -w "${test_ips[$i]}" 2>/dev/null | tail -n1 | awk '{print $NF}' || echo "无法检测"
        done
    else
        print_warn "未安装 mtr，跳过详细去程检测"
    fi
}

# ============================================================
# 10. 三网多节点测速
# ============================================================
test_speedtest_multi() {
    echo ""
    print_title "📶 三网多节点测速"

    if command -v speedtest >/dev/null 2>&1; then
        speedtest --simple 2>/dev/null || print_warn "speedtest测速失败"
    elif command -v speedtest-cli >/dev/null 2>&1; then
        speedtest-cli --simple 2>/dev/null || print_warn "speedtest-cli测速失败"
    else
        print_warn "未安装speedtest，尝试wget下载测速..."
        local speed=$(wget -O /dev/null "http://cachefly.cachefly.net/100mb.test" 2>&1 | grep -o '[0-9.]* [KM]B/s' | head -1)
        [ -n "$speed" ] && echo -e "  下载速度: ${GREEN}${speed}${PLAIN}"
    fi
}

# ============================================================
# 11. 流媒体解锁检测 (15+平台)
# ============================================================
test_streaming() {
    print_title "📺 流媒体解锁检测 (15+平台)"
    print_info "检测IP对各大流媒体平台的解锁状态"
    echo ""

    local platforms=(
        "Netflix:https://www.netflix.com"
        "YouTube:https://www.youtube.com"
        "Disney+:https://www.disneyplus.com"
        "Bilibili:https://www.bilibili.com"
        "HBO Max:https://www.hbomax.com"
        "Spotify:https://www.spotify.com"
        "TikTok:https://www.tiktok.com"
        "PrimeVideo:https://www.primevideo.com"
        "HBO Now:https://www.hbonow.com"
        "BBC iPlayer:https://www.bbc.co.uk/iplayer"
        "NicoNico:https://www.nicovideo.jp"
        "巴哈姆特:https://www.gamer.com.tw"
        "DMM:https://www.dmm.com"
        "AbemaTV:https://abema.tv"
        "Hulu:https://www.hulu.com"
    )

    STREAMING_RESULT=""
    for platform in "${platforms[@]}"; do
        local name=$(echo "$platform" | cut -d: -f1)
        local url=$(echo "$platform" | cut -d: -f2-)
        print_progress "检测 ${name}..."
        local result=$(curl -s --max-time 5 -w "%{http_code}" -o /dev/null "$url" 2>/dev/null || echo "000")
        if [ "$result" = "200" ] || [ "$result" = "302" ] || [ "$result" = "301" ]; then
            echo -e "  ${name}: ${GREEN}✅ 可访问${PLAIN}"
            STREAMING_RESULT="${STREAMING_RESULT}${name}: ✅ 可访问\n"
        else
            echo -e "  ${name}: ${RED}❌ 不可访问${PLAIN}"
            STREAMING_RESULT="${STREAMING_RESULT}${name}: ❌ 不可访问\n"
        fi
    done
}

# ============================================================
# 12. IP质量检测
# ============================================================
test_ip_quality() {
    print_title "🛡️ IP质量检测"
    local ip_info=$(curl -s --max-time 5 "http://ip-api.com/json/" 2>/dev/null || echo "")
    if [ -n "$ip_info" ] && echo "$ip_info" | grep -q '"status":"success"'; then
        local country=$(echo "$ip_info" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        local region=$(echo "$ip_info" | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
        local city=$(echo "$ip_info" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
        local isp=$(echo "$ip_info" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)
        local org=$(echo "$ip_info" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
        local asn=$(echo "$ip_info" | grep -o '"as":"[^"]*"' | cut -d'"' -f4)
        echo -e "${BOLD}国家/地区${PLAIN}    : $country ($region)"
        echo -e "${BOLD}城市${PLAIN}          : $city"
        echo -e "${BOLD}运营商${PLAIN}        : $isp"
        echo -e "${BOLD}组织机构${PLAIN}      : $org"
        echo -e "${BOLD}ASN${PLAIN}           : $asn"
        if echo "$isp" | grep -qi "cloud\|hosting\|datacenter\|server"; then
            echo -e "${BOLD}IP类型${PLAIN}        : ${YELLOW}数据中心/机房IP${PLAIN}"
            IP_IS_DATACENTER="true"
        else
            echo -e "${BOLD}IP类型${PLAIN}        : ${GREEN}家庭宽带/移动IP${PLAIN}"
            IP_IS_DATACENTER="false"
        fi
        IP_COUNTRY="$country"
        IP_CITY="$city"
        IP_ISP="$isp"
        IP_ASN="$asn"
    else
        IP_COUNTRY="未知"
        IP_CITY="未知"
        IP_ISP="未知"
        IP_ASN="未知"
        IP_IS_DATACENTER="unknown"
    fi
}

# ============================================================
# 13. DNS泄露检测
# ============================================================
test_dns_leak() {
    print_title "🔐 DNS泄露检测"
    local dns_servers=$(cat /etc/resolv.conf 2>/dev/null | grep "^nameserver" | awk '{print $2}' | tr '\n' ' ')
    echo -e "${BOLD}当前DNS服务器${PLAIN}  : ${CYAN}${dns_servers:-未设置}${PLAIN}"

    local test_domains=("google.com" "youtube.com" "facebook.com")
    for domain in "${test_domains[@]}"; do
        local ip=$(dig +short "$domain" 2>/dev/null | head -1)
        if [ -n "$ip" ]; then
            local country=$(curl -s --max-time 3 "http://ip-api.com/json/${ip}?fields=countryCode" 2>/dev/null | grep -o '"countryCode":"[^"]*"' | cut -d'"' -f4)
            if [ "$country" = "CN" ]; then
                echo -e "  ${domain}: ${RED}⚠️ DNS泄露 (解析到中国IP: ${ip})${PLAIN}"
            else
                echo -e "  ${domain}: ${GREEN}✅ 正常 (${ip})${PLAIN}"
            fi
        fi
    done
}

# ============================================================
# 14. IPv6检测
# ============================================================
test_ipv6() {
    print_title "🌐 IPv6检测"
    if ping6 -c 1 2001:4860:4860::8888 2>/dev/null | grep -q "1 packets received"; then
        echo -e "  IPv6连通性: ${GREEN}✅ 正常${PLAIN}"
        local ipv6_addr=$(ip -6 addr show | grep -o "inet6 [0-9a-f:]*" | head -1 | cut -d' ' -f2)
        [ -n "$ipv6_addr" ] && echo -e "  IPv6地址: ${CYAN}${ipv6_addr}${PLAIN}"
        local ipv6_lat=$(ping6 -c 3 2001:4860:4860::8888 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        [ -n "$ipv6_lat" ] && echo -e "  IPv6延迟: $(colorize_latency "$ipv6_lat")"
        IPV6_STATUS="✅ 正常"
    else
        echo -e "  IPv6连通性: ${RED}❌ 不支持${PLAIN}"
        IPV6_STATUS="❌ 不支持"
    fi
}

# ============================================================
# 15. 综合评分（重新设计 - 科学合理版）
# ============================================================
calculate_score() {
    print_title "🏆 综合性能评分"
    
    echo ""
    echo -e "${BOLD}评分规则说明:${PLAIN}"
    echo -e "  ${DIM}总分 = CPU(30) + 内存(15) + 磁盘(25) + 网络(25) + IP质量(5) = 100分${PLAIN}"
    echo -e "  ${DIM}评级: 旗舰级≥85 | 优秀≥70 | 良好≥55 | 一般≥40 | 较差<40${PLAIN}"
    echo ""

    # ---------- CPU评分 (0-30分) ----------
    local score_cpu=0
    
    # 1.1 CPU诚信度 (0-10分)
    if [ -n "${SCORE_STEAL:-}" ]; then
        score_cpu=$((score_cpu + SCORE_STEAL))
    else
        # 临时检测steal
        local steal_tmp=$(top -bn1 | grep "Cpu(s)" | awk '{print $NF}' | cut -d'%' -f1 2>/dev/null || echo "0")
        if [ -n "$steal_tmp" ]; then
            if (( $(echo "$steal_tmp < 1" | bc -l) )); then
                score_cpu=$((score_cpu + 10))
            elif (( $(echo "$steal_tmp < 3" | bc -l) )); then
                score_cpu=$((score_cpu + 6))
            else
                score_cpu=$((score_cpu + 2))
            fi
        else
            score_cpu=$((score_cpu + 5))
        fi
    fi
    
    # 1.2 sysbench单核性能 (0-15分)
    if [ -n "${SYSBENCH_SINGLE:-}" ] && [ "$SYSBENCH_SINGLE" != "N/A" ]; then
        if (( $(echo "$SYSBENCH_SINGLE > 2000" | bc -l) )); then
            score_cpu=$((score_cpu + 15))
            echo -e "  ${GREEN}CPU单核 > 2000: +15分${PLAIN}"
        elif (( $(echo "$SYSBENCH_SINGLE > 1500" | bc -l) )); then
            score_cpu=$((score_cpu + 12))
            echo -e "  ${GREEN}CPU单核 > 1500: +12分${PLAIN}"
        elif (( $(echo "$SYSBENCH_SINGLE > 1000" | bc -l) )); then
            score_cpu=$((score_cpu + 8))
            echo -e "  ${YELLOW}CPU单核 > 1000: +8分${PLAIN}"
        elif (( $(echo "$SYSBENCH_SINGLE > 500" | bc -l) )); then
            score_cpu=$((score_cpu + 4))
            echo -e "  ${YELLOW}CPU单核 > 500: +4分${PLAIN}"
        else
            echo -e "  ${RED}CPU单核 <= 500: +0分${PLAIN}"
        fi
    fi
    
    # 1.3 多核加速比 (0-5分)
    if [ -n "${SYSBENCH_SINGLE:-}" ] && [ -n "${SYSBENCH_MULTI:-}" ] && [ "$SYSBENCH_SINGLE" != "N/A" ] && [ "$SYSBENCH_MULTI" != "N/A" ]; then
        local ratio=$(echo "scale=2; $SYSBENCH_MULTI / $SYSBENCH_SINGLE" | bc 2>/dev/null || echo "1")
        if (( $(echo "$ratio > 3" | bc -l) )); then
            score_cpu=$((score_cpu + 5))
            echo -e "  ${GREEN}多核加速比 > 3: +5分${PLAIN}"
        elif (( $(echo "$ratio > 2" | bc -l) )); then
            score_cpu=$((score_cpu + 3))
            echo -e "  ${YELLOW}多核加速比 > 2: +3分${PLAIN}"
        else
            echo -e "  ${DIM}多核加速比 <= 2: +0分${PLAIN}"
        fi
    fi
    
    [ $score_cpu -gt 30 ] && score_cpu=30
    SCORE_CPU=$score_cpu
    echo -e "  ${BOLD}CPU总分: ${CYAN}${score_cpu}/30${PLAIN}"
    echo ""

    # ---------- 内存评分 (0-15分) ----------
    local score_memory=0
    if [ -n "${MEM_READ:-}" ] && [ "$MEM_READ" != "N/A" ]; then
        if (( $(echo "$MEM_READ > 20000" | bc -l) )); then
            score_memory=15
            echo -e "  ${GREEN}内存读取 > 20000 MiB/s: +15分${PLAIN}"
        elif (( $(echo "$MEM_READ > 15000" | bc -l) )); then
            score_memory=12
            echo -e "  ${GREEN}内存读取 > 15000 MiB/s: +12分${PLAIN}"
        elif (( $(echo "$MEM_READ > 10000" | bc -l) )); then
            score_memory=8
            echo -e "  ${YELLOW}内存读取 > 10000 MiB/s: +8分${PLAIN}"
        elif (( $(echo "$MEM_READ > 5000" | bc -l) )); then
            score_memory=4
            echo -e "  ${YELLOW}内存读取 > 5000 MiB/s: +4分${PLAIN}"
        else
            echo -e "  ${RED}内存读取 <= 5000 MiB/s: +0分${PLAIN}"
        fi
    else
        score_memory=5  # 保底分
        echo -e "  ${DIM}内存测试不可用: +5分(保底)${PLAIN}"
    fi
    [ $score_memory -gt 15 ] && score_memory=15
    SCORE_MEMORY=$score_memory
    echo -e "  ${BOLD}内存总分: ${CYAN}${score_memory}/15${PLAIN}"
    echo ""

    # ---------- 磁盘评分 (0-25分) ----------
    local score_disk=0
    
    # 3.1 顺序读取 (0-12分)
    if [ -n "${DISK_READ:-}" ] && [ "$DISK_READ" != "N/A" ]; then
        if (( $(echo "$DISK_READ > 800" | bc -l) )); then
            score_disk=$((score_disk + 12))
            echo -e "  ${GREEN}磁盘顺序读 > 800 MB/s: +12分${PLAIN}"
        elif (( $(echo "$DISK_READ > 500" | bc -l) )); then
            score_disk=$((score_disk + 9))
            echo -e "  ${GREEN}磁盘顺序读 > 500 MB/s: +9分${PLAIN}"
        elif (( $(echo "$DISK_READ > 300" | bc -l) )); then
            score_disk=$((score_disk + 6))
            echo -e "  ${YELLOW}磁盘顺序读 > 300 MB/s: +6分${PLAIN}"
        elif (( $(echo "$DISK_READ > 150" | bc -l) )); then
            score_disk=$((score_disk + 3))
            echo -e "  ${YELLOW}磁盘顺序读 > 150 MB/s: +3分${PLAIN}"
        else
            echo -e "  ${RED}磁盘顺序读 <= 150 MB/s: +0分${PLAIN}"
        fi
    fi
    
    # 3.2 4K随机读取 (0-10分)
    if [ -n "${DISK_RAND_READ:-}" ] && [ "$DISK_RAND_READ" != "N/A" ]; then
        if (( $(echo "$DISK_RAND_READ > 8000" | bc -l) )); then
            score_disk=$((score_disk + 10))
            echo -e "  ${GREEN}4K随机读 > 8000 IOPS: +10分${PLAIN}"
        elif (( $(echo "$DISK_RAND_READ > 5000" | bc -l) )); then
            score_disk=$((score_disk + 7))
            echo -e "  ${GREEN}4K随机读 > 5000 IOPS: +7分${PLAIN}"
        elif (( $(echo "$DISK_RAND_READ > 2000" | bc -l) )); then
            score_disk=$((score_disk + 4))
            echo -e "  ${YELLOW}4K随机读 > 2000 IOPS: +4分${PLAIN}"
        elif (( $(echo "$DISK_RAND_READ > 500" | bc -l) )); then
            score_disk=$((score_disk + 1))
            echo -e "  ${YELLOW}4K随机读 > 500 IOPS: +1分${PLAIN}"
        else
            echo -e "  ${RED}4K随机读 <= 500 IOPS: +0分${PLAIN}"
        fi
    fi
    
    # 3.3 ioping磁盘延迟 (0-3分)
    if [ -n "${DISK_IOPING:-}" ] && [ "$DISK_IOPING" != "N/A" ]; then
        if (( $(echo "$DISK_IOPING < 0.5" | bc -l) )); then
            score_disk=$((score_disk + 3))
            echo -e "  ${GREEN}磁盘延迟 < 0.5ms: +3分${PLAIN}"
        elif (( $(echo "$DISK_IOPING < 2" | bc -l) )); then
            score_disk=$((score_disk + 1))
            echo -e "  ${YELLOW}磁盘延迟 < 2ms: +1分${PLAIN}"
        else
            echo -e "  ${DIM}磁盘延迟 >= 2ms: +0分${PLAIN}"
        fi
    fi
    
    [ $score_disk -gt 25 ] && score_disk=25
    SCORE_DISK=$score_disk
    echo -e "  ${BOLD}磁盘总分: ${CYAN}${score_disk}/25${PLAIN}"
    echo ""

    # ---------- 网络评分 (0-25分) ----------
    local score_network=0
    
    # 根据服务器位置智能评估
    if [ "$SERVER_LOCATION" = "china" ]; then
        # 国内服务器：看国内延迟
        if [ -n "${NET_AVG_LAT:-}" ] && [ "$NET_AVG_LAT" != "0" ]; then
            if (( $(echo "$NET_AVG_LAT < 20" | bc -l) )); then
                score_network=$((score_network + 20))
                echo -e "  ${GREEN}国内平均延迟 < 20ms: +20分${PLAIN}"
            elif (( $(echo "$NET_AVG_LAT < 40" | bc -l) )); then
                score_network=$((score_network + 16))
                echo -e "  ${GREEN}国内平均延迟 < 40ms: +16分${PLAIN}"
            elif (( $(echo "$NET_AVG_LAT < 60" | bc -l) )); then
                score_network=$((score_network + 12))
                echo -e "  ${YELLOW}国内平均延迟 < 60ms: +12分${PLAIN}"
            elif (( $(echo "$NET_AVG_LAT < 100" | bc -l) )); then
                score_network=$((score_network + 8))
                echo -e "  ${YELLOW}国内平均延迟 < 100ms: +8分${PLAIN}"
            else
                echo -e "  ${RED}国内平均延迟 >= 100ms: +0分${PLAIN}"
            fi
        else
            score_network=$((score_network + 8))
            echo -e "  ${DIM}网络延迟无法检测: +8分(保底)${PLAIN}"
        fi
    elif [ "$SERVER_LOCATION" = "international" ]; then
        # 海外服务器：国际延迟 + 到中国回程
        if [ -n "${NET_AVG_LAT:-}" ] && [ "$NET_AVG_LAT" != "0" ]; then
            if (( $(echo "$NET_AVG_LAT < 80" | bc -l) )); then
                score_network=$((score_network + 12))
                echo -e "  ${GREEN}国际平均延迟 < 80ms: +12分${PLAIN}"
            elif (( $(echo "$NET_AVG_LAT < 150" | bc -l) )); then
                score_network=$((score_network + 8))
                echo -e "  ${YELLOW}国际平均延迟 < 150ms: +8分${PLAIN}"
            elif (( $(echo "$NET_AVG_LAT < 250" | bc -l) )); then
                score_network=$((score_network + 4))
                echo -e "  ${YELLOW}国际平均延迟 < 250ms: +4分${PLAIN}"
            else
                echo -e "  ${RED}国际平均延迟 >= 250ms: +0分${PLAIN}"
            fi
        fi
        
        # 到中国回程延迟 (额外加分项)
        if [ -n "${NET_CN_AVG:-}" ] && [ "$NET_CN_AVG" != "0" ]; then
            if (( $(echo "$NET_CN_AVG < 100" | bc -l) )); then
                score_network=$((score_network + 8))
                echo -e "  ${GREEN}到中国回程 < 100ms: +8分${PLAIN}"
            elif (( $(echo "$NET_CN_AVG < 200" | bc -l) )); then
                score_network=$((score_network + 5))
                echo -e "  ${YELLOW}到中国回程 < 200ms: +5分${PLAIN}"
            elif (( $(echo "$NET_CN_AVG < 300" | bc -l) )); then
                score_network=$((score_network + 2))
                echo -e "  ${YELLOW}到中国回程 < 300ms: +2分${PLAIN}"
            else
                echo -e "  ${RED}到中国回程 >= 300ms: +0分${PLAIN}"
            fi
        else
            score_network=$((score_network + 3))
            echo -e "  ${DIM}到中国回程无法检测: +3分(保底)${PLAIN}"
        fi
    else
        # 混合模式
        score_network=10
        echo -e "  ${DIM}混合模式: +10分(保底)${PLAIN}"
    fi
    
    [ $score_network -gt 25 ] && score_network=25
    SCORE_NETWORK=$score_network
    echo -e "  ${BOLD}网络总分: ${CYAN}${score_network}/25${PLAIN}"
    echo ""

    # ---------- IP质量评分 (0-5分) ----------
    local score_ip=0
    if [ -n "${IP_IS_DATACENTER:-}" ]; then
        if [ "$IP_IS_DATACENTER" = "false" ]; then
            score_ip=5
            echo -e "  ${GREEN}非数据中心IP: +5分${PLAIN}"
        else
            score_ip=2
            echo -e "  ${YELLOW}数据中心IP: +2分${PLAIN}"
        fi
    else
        score_ip=2
        echo -e "  ${DIM}IP类型无法检测: +2分(保底)${PLAIN}"
    fi
    SCORE_IP=$score_ip
    echo -e "  ${BOLD}IP质量总分: ${CYAN}${score_ip}/5${PLAIN}"
    echo ""

    # ---------- 汇总 ----------
    SCORE_TOTAL=$((SCORE_CPU + SCORE_MEMORY + SCORE_DISK + SCORE_NETWORK + SCORE_IP))
    [ $SCORE_TOTAL -gt 100 ] && SCORE_TOTAL=100

    echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────────────────┐${PLAIN}"
    echo -e "${BOLD}${CYAN}│  ${BOLD}综合性能得分: ${SCORE_TOTAL}/100                              ${PLAIN}"
    
    # 进度条
    local bar_len=30
    local filled=$((SCORE_TOTAL * bar_len / 100))
    local empty=$((bar_len - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    
    if [ $SCORE_TOTAL -ge 85 ]; then
        echo -e "${BOLD}${CYAN}│  评级: ${GREEN}🌟🌟🌟🌟🌟 旗舰级 (Excellent)${PLAIN}                     │"
        echo -e "${BOLD}${CYAN}│  [${GREEN}${bar}${PLAIN}]${PLAIN}"
    elif [ $SCORE_TOTAL -ge 70 ]; then
        echo -e "${BOLD}${CYAN}│  评级: ${GREEN}🌟🌟🌟🌟 优秀 (Good)${PLAIN}                           │"
        echo -e "${BOLD}${CYAN}│  [${GREEN}${bar}${PLAIN}]${PLAIN}"
    elif [ $SCORE_TOTAL -ge 55 ]; then
        echo -e "${BOLD}${CYAN}│  评级: ${YELLOW}🌟🌟🌟 良好 (Fair)${PLAIN}                            │"
        echo -e "${BOLD}${CYAN}│  [${YELLOW}${bar}${PLAIN}]${PLAIN}"
    elif [ $SCORE_TOTAL -ge 40 ]; then
        echo -e "${BOLD}${CYAN}│  评级: ${YELLOW}🌟🌟 一般 (Average)${PLAIN}                           │"
        echo -e "${BOLD}${CYAN}│  [${YELLOW}${bar}${PLAIN}]${PLAIN}"
    else
        echo -e "${BOLD}${CYAN}│  评级: ${RED}🌟 较差 (Poor)${PLAIN}                                │"
        echo -e "${BOLD}${CYAN}│  [${RED}${bar}${PLAIN}]${PLAIN}"
    fi
    echo -e "${BOLD}${CYAN}│  ─────────────────────────────────────────────────────────────  │${PLAIN}"
    echo -e "${BOLD}${CYAN}│  CPU: ${SCORE_CPU}/30  内存: ${SCORE_MEMORY}/15  磁盘: ${SCORE_DISK}/25  │${PLAIN}"
    echo -e "${BOLD}${CYAN}│  网络: ${SCORE_NETWORK}/25  IP质量: ${SCORE_IP}/5                      │${PLAIN}"
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────────────────┘${PLAIN}"
}

# ============================================================
# 16. HTML报告（美化版）
# ============================================================
generate_html_report() {
    print_title "📄 生成HTML报告"
    mkdir -p "$REPORT_DIR"
    
    local score_color=""
    local score_emoji=""
    if [ $SCORE_TOTAL -ge 85 ]; then
        score_color="#00d4ff"
        score_emoji="🌟🌟🌟🌟🌟"
    elif [ $SCORE_TOTAL -ge 70 ]; then
        score_color="#00ff88"
        score_emoji="🌟🌟🌟🌟"
    elif [ $SCORE_TOTAL -ge 55 ]; then
        score_color="#ffaa00"
        score_emoji="🌟🌟🌟"
    elif [ $SCORE_TOTAL -ge 40 ]; then
        score_color="#ff8800"
        score_emoji="🌟🌟"
    else
        score_color="#ff4444"
        score_emoji="🌟"
    fi

    cat > "$HTML_REPORT" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>LXBench 2.1 测评报告</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;background:linear-gradient(135deg,#0a0e17 0%,#1a1a2e 100%);color:#e0e0e0;padding:20px;min-height:100vh;line-height:1.6}
.container{max-width:1000px;margin:0 auto;background:rgba(20,27,43,0.92);border-radius:20px;padding:40px;box-shadow:0 20px 60px rgba(0,0,0,0.6);backdrop-filter:blur(10px);border:1px solid rgba(255,255,255,0.05)}
.header{text-align:center;padding-bottom:30px;border-bottom:2px solid rgba(0,212,255,0.15);margin-bottom:30px}
.header h1{font-size:32px;background:linear-gradient(90deg,#00d4ff,#00ff88);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
.header .sub{color:#8899bb;font-size:14px;margin-top:8px}
.header .version{display:inline-block;background:#00d4ff22;color:#00d4ff;padding:2px 14px;border-radius:12px;font-size:12px;margin-top:6px}
.score-section{background:linear-gradient(135deg,#1a2335,#0d1524);border-radius:16px;padding:30px;text-align:center;margin:20px 0 30px 0;border:1px solid rgba(0,212,255,0.1)}
.score-number{font-size:72px;font-weight:bold;color:#00d4ff;line-height:1}
.score-label{color:#8899bb;font-size:16px;margin-top:4px}
.score-bar{max-width:400px;margin:16px auto 0;height:8px;background:#1a2335;border-radius:4px;overflow:hidden}
.score-bar-fill{height:100%;border-radius:4px;background:linear-gradient(90deg,#00d4ff,#00ff88);width:0%;transition:width 0.8s ease}
.score-sub{display:flex;justify-content:center;gap:40px;flex-wrap:wrap;margin-top:16px;font-size:14px;color:#8899bb}
.score-sub span{color:#e0e0e0}
.badge{display:inline-block;padding:4px 18px;border-radius:20px;font-size:14px;font-weight:bold;margin-top:8px}
.badge-excellent{background:#00d4ff22;color:#00d4ff}
.badge-good{background:#00ff8822;color:#00ff88}
.badge-fair{background:#ffaa0022;color:#ffaa00}
.badge-average{background:#ff880022;color:#ff8800}
.badge-poor{background:#ff444422;color:#ff4444}
.grid-2{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin:12px 0}
.info-card{background:#1a2335;border-radius:12px;padding:16px 20px;border:1px solid rgba(255,255,255,0.04)}
.info-card .label{color:#8899bb;font-size:13px}
.info-card .value{color:#e8e8e8;font-size:15px;font-weight:500}
.section-title{font-size:20px;color:#00d4ff;margin:28px 0 16px 0;padding-left:14px;border-left:4px solid #00d4ff}
.table-wrap{background:#1a2335;border-radius:12px;overflow:hidden;border:1px solid rgba(255,255,255,0.04);margin:8px 0}
.table-wrap table{width:100%;border-collapse:collapse}
.table-wrap th,.table-wrap td{padding:10px 16px;text-align:left;border-bottom:1px solid rgba(255,255,255,0.04)}
.table-wrap th{color:#8899bb;font-weight:400;font-size:13px;background:#141b2b}
.table-wrap tr:last-child td{border-bottom:none}
.tag-green{color:#00ff88}
.tag-red{color:#ff4444}
.tag-yellow{color:#ffaa00}
.tag-gray{color:#8899bb}
.links{margin-top:30px;padding-top:20px;border-top:1px solid rgba(255,255,255,0.06);text-align:center;color:#8899bb;font-size:14px}
.links a{color:#00d4ff;text-decoration:none;margin:0 10px}
.links a:hover{text-decoration:underline}
.footer{margin-top:16px;text-align:center;color:#556688;font-size:12px}
@media(max-width:600px){.container{padding:16px}.grid-2{grid-template-columns:1fr}.score-number{font-size:48px}.score-sub{flex-direction:column;gap:8px}}
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>🚀 LXBench 测评报告</h1>
<div class="version">v2.1.0</div>
<div class="sub">生成时间: TIMESTAMP_PLACEHOLDER</div>
</div>

<div class="score-section">
<div class="score-number" style="color: SCORE_COLOR_PLACEHOLDER;">SCORE_PLACEHOLDER</div>
<div class="score-label">综合性能得分</div>
<div class="badge BADGE_CLASS_PLACEHOLDER">BADGE_TEXT_PLACEHOLDER</div>
<div class="score-bar"><div class="score-bar-fill" style="width:SCORE_BAR_PLACEHOLDER%;background:linear-gradient(90deg,SCORE_COLOR_PLACEHOLDER,#00ff88)"></div></div>
<div class="score-sub">
<span>CPU: <b>SCORE_CPU_PLACEHOLDER</b>/30</span>
<span>内存: <b>SCORE_MEM_PLACEHOLDER</b>/15</span>
<span>磁盘: <b>SCORE_DISK_PLACEHOLDER</b>/25</span>
<span>网络: <b>SCORE_NET_PLACEHOLDER</b>/25</span>
<span>IP质量: <b>SCORE_IP_PLACEHOLDER</b>/5</span>
</div>
</div>

<h2 class="section-title">📍 服务器信息</h2>
<div class="grid-2">
<div class="info-card"><div class="label">位置</div><div class="value">SERVER_LOC_PLACEHOLDER</div></div>
<div class="info-card"><div class="label">运营商</div><div class="value">SERVER_ISP_PLACEHOLDER</div></div>
<div class="info-card"><div class="label">CPU</div><div class="value">SERVER_CPU_PLACEHOLDER</div></div>
<div class="info-card"><div class="label">内存 / 磁盘</div><div class="value">SERVER_MEM_PLACEHOLDER / SERVER_DISK_PLACEHOLDER</div></div>
<div class="info-card"><div class="label">测试模式</div><div class="value">SERVER_MODE_PLACEHOLDER</div></div>
<div class="info-card"><div class="label">IPv6</div><div class="value">IPV6_PLACEHOLDER</div></div>
</div>

<h2 class="section-title">⚡ 性能测试结果</h2>
<div class="table-wrap">
<table>
<tr><th>测试项目</th><th>结果</th></tr>
PERF_ROWS_PLACEHOLDER
</table>
</div>

<h2 class="section-title">🌐 网络延迟</h2>
<div class="table-wrap">
<table>
<tr><th>节点</th><th>延迟</th></tr>
NET_ROWS_PLACEHOLDER
</table>
</div>

<h2 class="section-title">📺 流媒体解锁</h2>
<div class="table-wrap">
<table>
<tr><th>平台</th><th>状态</th></tr>
STREAM_ROWS_PLACEHOLDER
</table>
</div>

<div class="links">
📦 <a href="GITHUB_PLACEHOLDER">GitHub</a> &nbsp;|&nbsp;
🚀 <a href="RAINYUN_PLACEHOLDER">服务器推荐</a> &nbsp;|&nbsp;
📝 <a href="BLOG_PLACEHOLDER">个人博客</a>
</div>
<div class="footer">LXBench v2.1.0 · 智能双模节点 · 科学评分体系</div>
</div>
</body>
</html>
EOF

    # 替换占位符
    local score_color=""
    local badge_class=""
    local badge_text=""
    if [ $SCORE_TOTAL -ge 85 ]; then
        score_color="#00d4ff"
        badge_class="badge-excellent"
        badge_text="🌟🌟🌟🌟🌟 旗舰级"
    elif [ $SCORE_TOTAL -ge 70 ]; then
        score_color="#00ff88"
        badge_class="badge-good"
        badge_text="🌟🌟🌟🌟 优秀"
    elif [ $SCORE_TOTAL -ge 55 ]; then
        score_color="#ffaa00"
        badge_class="badge-fair"
        badge_text="🌟🌟🌟 良好"
    elif [ $SCORE_TOTAL -ge 40 ]; then
        score_color="#ff8800"
        badge_class="badge-average"
        badge_text="🌟🌟 一般"
    else
        score_color="#ff4444"
        badge_class="badge-poor"
        badge_text="🌟 较差"
    fi

    local mode_name=""
    case "$TEST_MODE" in
        full) mode_name="完整测试 (含UnixBench)" ;;
        quick) mode_name="快速测试 (跳过UnixBench)" ;;
        network) mode_name="仅网络测试" ;;
        performance) mode_name="仅性能测试" ;;
        streaming) mode_name="仅流媒体+IP质量" ;;
        minimal) mode_name="极简测试" ;;
        *) mode_name="未知" ;;
    esac

    local perf_rows=""
    perf_rows="${perf_rows}<tr><td>操作系统</td><td>${SYS_INFO_OS:-未知}</td></tr>"
    perf_rows="${perf_rows}<tr><td>CPU</td><td>${SYS_INFO_CPU:-未知} (${SYS_INFO_CORES:-0}核)</td></tr>"
    perf_rows="${perf_rows}<tr><td>sysbench 单核</td><td>${SYSBENCH_SINGLE:-N/A} events/s</td></tr>"
    perf_rows="${perf_rows}<tr><td>sysbench 多核</td><td>${SYSBENCH_MULTI:-N/A} events/s</td></tr>"
    perf_rows="${perf_rows}<tr><td>Geekbench 5</td><td>单核: ${GB_SINGLE:-N/A} / 多核: ${GB_MULTI:-N/A}</td></tr>"
    perf_rows="${perf_rows}<tr><td>UnixBench</td><td>${UNIXBENCH_SCORE:-已跳过}</td></tr>"
    perf_rows="${perf_rows}<tr><td>内存读取</td><td>${MEM_READ:-N/A} MiB/s</td></tr>"
    perf_rows="${perf_rows}<tr><td>磁盘顺序读写</td><td>读: ${DISK_READ:-N/A} / 写: ${DISK_WRITE:-N/A} MB/s</td></tr>"
    perf_rows="${perf_rows}<tr><td>4K随机读取</td><td>${DISK_RAND_READ:-N/A} IOPS</td></tr>"

    local net_rows=""
    # 从网络测试中提取几个关键节点
    local net_nodes=("上海电信:180.153.0.1" "北京电信:219.141.136.10" "广州电信:183.56.128.1" "香港:203.80.96.10" "新加坡:103.7.8.10" "洛杉矶:208.67.222.222")
    for node in "${net_nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 2 -W 2 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}' 2>/dev/null)
        if [ -n "$lat" ]; then
            local color=""
            if (( $(echo "$lat < 50" | bc -l) )); then color="tag-green"
            elif (( $(echo "$lat < 150" | bc -l) )); then color="tag-yellow"
            else color="tag-red"; fi
            net_rows="${net_rows}<tr><td>${name}</td><td class=\"${color}\">${lat} ms</td></tr>"
        else
            net_rows="${net_rows}<tr><td>${name}</td><td class=\"tag-gray\">超时</td></tr>"
        fi
    done

    local stream_rows=""
    # 从之前保存的流媒体结果中提取
    if [ -n "${STREAMING_RESULT:-}" ]; then
        while IFS= read -r line; do
            if [[ "$line" == *"✅"* ]]; then
                local pname=$(echo "$line" | cut -d: -f1)
                stream_rows="${stream_rows}<tr><td>${pname}</td><td class=\"tag-green\">✅ 可访问</td></tr>"
            elif [[ "$line" == *"❌"* ]]; then
                local pname=$(echo "$line" | cut -d: -f1)
                stream_rows="${stream_rows}<tr><td>${pname}</td><td class=\"tag-red\">❌ 不可访问</td></tr>"
            fi
        done <<< "$(echo -e "$STREAMING_RESULT")"
    else
        stream_rows="<tr><td colspan=\"2\" class=\"tag-gray\">未检测或数据不可用</td></tr>"
    fi

    sed -i \
        -e "s|TIMESTAMP_PLACEHOLDER|$(date '+%Y-%m-%d %H:%M:%S')|g" \
        -e "s|SCORE_PLACEHOLDER|${SCORE_TOTAL}|g" \
        -e "s|SCORE_COLOR_PLACEHOLDER|${score_color}|g" \
        -e "s|SCORE_CPU_PLACEHOLDER|${SCORE_CPU:-0}|g" \
        -e "s|SCORE_MEM_PLACEHOLDER|${SCORE_MEMORY:-0}|g" \
        -e "s|SCORE_DISK_PLACEHOLDER|${SCORE_DISK:-0}|g" \
        -e "s|SCORE_NET_PLACEHOLDER|${SCORE_NETWORK:-0}|g" \
        -e "s|SCORE_IP_PLACEHOLDER|${SCORE_IP:-0}|g" \
        -e "s|SCORE_BAR_PLACEHOLDER|${SCORE_TOTAL}|g" \
        -e "s|BADGE_CLASS_PLACEHOLDER|${badge_class}|g" \
        -e "s|BADGE_TEXT_PLACEHOLDER|${badge_text}|g" \
        -e "s|SERVER_LOC_PLACEHOLDER|${SERVER_COUNTRY:-未知} - ${SERVER_CITY:-未知}|g" \
        -e "s|SERVER_ISP_PLACEHOLDER|${SERVER_ISP:-未知}|g" \
        -e "s|SERVER_CPU_PLACEHOLDER|${SYS_INFO_CPU:-未知}|g" \
        -e "s|SERVER_MEM_PLACEHOLDER|${SYS_INFO_MEM:-未知}|g" \
        -e "s|SERVER_DISK_PLACEHOLDER|${SYS_INFO_DISK:-未知}|g" \
        -e "s|SERVER_MODE_PLACEHOLDER|${mode_name}|g" \
        -e "s|IPV6_PLACEHOLDER|${IPV6_STATUS:-未检测}|g" \
        -e "s|GITHUB_PLACEHOLDER|${GITHUB_URL}|g" \
        -e "s|RAINYUN_PLACEHOLDER|${RAINYUN_URL}|g" \
        -e "s|BLOG_PLACEHOLDER|${BLOG_URL}|g" \
        "$HTML_REPORT"

    # 替换表格内容
    sed -i "/PERF_ROWS_PLACEHOLDER/{r /dev/stdin
d}" "$HTML_REPORT" <<< "$perf_rows"
    sed -i "/NET_ROWS_PLACEHOLDER/{r /dev/stdin
d}" "$HTML_REPORT" <<< "$net_rows"
    sed -i "/STREAM_ROWS_PLACEHOLDER/{r /dev/stdin
d}" "$HTML_REPORT" <<< "$stream_rows"

    print_ok "HTML报告已生成: $HTML_REPORT"
}

# ============================================================
# 17. Markdown报告
# ============================================================
generate_md_report() {
    cat > "$MD_REPORT" << EOF
# LXBench 2.1 测评报告

**生成时间**: $(date '+%Y-%m-%d %H:%M:%S')
**版本**: ${VERSION}

## 📊 综合评分
**总分: ${SCORE_TOTAL}/100**
- CPU: ${SCORE_CPU:-0}/30
- 内存: ${SCORE_MEMORY:-0}/15
- 磁盘: ${SCORE_DISK:-0}/25
- 网络: ${SCORE_NETWORK:-0}/25
- IP质量: ${SCORE_IP:-0}/5

## 📍 服务器信息
- **位置**: ${SERVER_COUNTRY:-未知} - ${SERVER_CITY:-未知}
- **运营商**: ${SERVER_ISP:-未知}
- **CPU**: ${SYS_INFO_CPU:-未知}
- **内存**: ${SYS_INFO_MEM:-未知}
- **磁盘**: ${SYS_INFO_DISK:-未知}
- **测试模式**: ${TEST_MODE}

## ⚡ 性能数据
- sysbench单核: ${SYSBENCH_SINGLE:-N/A} events/s
- sysbench多核: ${SYSBENCH_MULTI:-N/A} events/s
- Geekbench 5: ${GB_SINGLE:-N/A} / ${GB_MULTI:-N/A}
- UnixBench: ${UNIXBENCH_SCORE:-已跳过}
- 内存读取: ${MEM_READ:-N/A} MiB/s
- 磁盘顺序读写: ${DISK_READ:-N/A} / ${DISK_WRITE:-N/A} MB/s
- 4K随机读取: ${DISK_RAND_READ:-N/A} IOPS

---
- 📦 GitHub: ${GITHUB_URL}
- 🚀 服务器推荐: ${RAINYUN_URL}
- 📝 个人博客: ${BLOG_URL}
---
EOF
    print_ok "Markdown报告: $MD_REPORT"
}

# ============================================================
# 18. 清理
# ============================================================
cleanup() {
    rm -f /tmp/lxbench_* 2>/dev/null || true
    print_ok "临时文件已清理"
}

# ============================================================
# 19. 主函数
# ============================================================
main() {
    clear
    print_banner
    select_mode

    print_info "开始 LXBench ${VERSION} 测评..."
    local start_time=$(date +%s)
    mkdir -p "$REPORT_DIR"

    # 开始记录完整输出
    exec > >(tee -a "$FULL_LOG")
    exec 2>&1

    install_deps
    detect_location
    collect_system_info
    test_cpu_integrity
    test_cpu
    test_memory
    test_disk
    test_network
    test_streaming
    test_ip_quality
    test_dns_leak
    test_ipv6
    calculate_score
    generate_html_report
    generate_md_report
    cleanup

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    print_title "✅ 测评完成"
    echo -e "${BOLD}总耗时${PLAIN}: ${CYAN}$((duration/60))分$((duration%60))秒${PLAIN}"
    echo -e "${BOLD}综合得分${PLAIN}: ${CYAN}${SCORE_TOTAL}/100${PLAIN}"
    echo -e "${BOLD}HTML报告${PLAIN}: ${CYAN}${HTML_REPORT}${PLAIN}"
    echo -e "${BOLD}Markdown报告${PLAIN}: ${CYAN}${MD_REPORT}${PLAIN}"
    echo -e "${BOLD}完整日志${PLAIN}: ${CYAN}${FULL_LOG}${PLAIN}"
    echo ""
    print_ok "感谢使用 LXBench ${VERSION}！"
}

main "$@"
