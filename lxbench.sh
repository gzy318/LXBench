#!/usr/bin/env bash
#
# LXBench 2.0.1 - 全能VPS服务器测评脚本
#
# GitHub: https://github.com/gzy318/LXBench
# 服务器推荐: https://www.rainyun.com/xls_
# 个人博客: https://twbk.cn
#

set -euo pipefail
export LC_ALL=C LANG=C

# ============================================================
# 版本信息
# ============================================================
VERSION="2.0.1"
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
LOG_FILE="${REPORT_DIR}/lxbench_${TIMESTAMP}.log"
SERVER_LOCATION="unknown"
SERVER_COUNTRY=""
SERVER_CITY=""
SERVER_ISP=""
SCORE_TOTAL=0
TEST_MODE="full"

# ============================================================
# 工具函数
# ============================================================
print_banner() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║                                                               ║"
    echo "  ║   ██╗     ██╗  ██╗██████╗ ███████╗███╗   ██╗ ██████╗██╗  ██╗  ║"
    echo "  ║   ██║     ╚██╗██╔╝██╔══██╗██╔════╝████╗  ██║██╔════╝██║  ██║  ║"
    echo "  ║   ██║      ╚███╔╝ ██████╔╝█████╗  ██╔██╗ ██║██║     ███████║  ║"
    echo "  ║   ██║      ██╔██╗ ██╔══██╗██╔══╝  ██║╚██╗██║██║     ██╔══██║  ║"
    echo "  ║   ███████╗██╔╝ ██╗██████╔╝███████╗██║ ╚████║╚██████╗██║  ██║  ║"
    echo "  ║   ╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝  ║"
    echo "  ║                                                               ║"
    echo "  ║          全能VPS服务器测评脚本 v${VERSION}                    ║"
    echo "  ║     智能双模节点 · 基础分45+加分制 · 超卖检测                ║"
    echo "  ║     海外→国内回程 · 五网路由 · 15+流媒体                     ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${PLAIN}"
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
    echo "  1) 完整测试 (全部项目，很慢)"
    echo "  2) 快速测试 (跳过Geekbench/UnixBench)"
    echo "  3) 仅网络测试 (延迟+路由+测速)"
    echo "  4) 仅性能测试 (CPU+内存+磁盘)"
    echo "  5) 仅流媒体+IP质量"
    echo "  6) 直接运行 (默认完整测试)"
    echo ""
    read -p "请输入选项 [1-6，默认1]: " mode_choice
    case "${mode_choice:-1}" in
        1|"") TEST_MODE="full" ;;
        2) TEST_MODE="quick" ;;
        3) TEST_MODE="network" ;;
        4) TEST_MODE="performance" ;;
        5) TEST_MODE="streaming" ;;
        6) TEST_MODE="full" ;;
        *) TEST_MODE="full" ;;
    esac
    print_info "已选择: ${TEST_MODE} 模式"
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
    elif (( $(echo "$steal_avg < 2.0" | bc -l) )); then
        echo -e "${BOLD}超卖检测${PLAIN}        : ${YELLOW}⚠️ 轻度超卖 ★★★${PLAIN}"
    else
        echo -e "${BOLD}超卖检测${PLAIN}        : ${RED}❌ 严重超卖 ★${PLAIN}"
    fi
}

# ============================================================
# 4. CPU性能测试
# ============================================================
test_cpu() {
    print_title "⚡ CPU性能测试"

    if command -v sysbench >/dev/null 2>&1; then
        print_progress "sysbench 单核测试..."
        local single=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>/dev/null | grep "events per second" | awk '{print $4}')
        print_progress "sysbench 多核测试..."
        local multi=$(sysbench cpu --cpu-max-prime=20000 --threads=$(nproc) run 2>/dev/null | grep "events per second" | awk '{print $4}')
        echo -e "${BOLD}sysbench 单核${PLAIN}    : ${GREEN}${single:-N/A}${PLAIN} events/s"
        echo -e "${BOLD}sysbench 多核${PLAIN}    : ${GREEN}${multi:-N/A}${PLAIN} events/s"
    fi

    if [ "$TEST_MODE" = "full" ]; then
        print_progress "Geekbench 5 测试 (约3-5分钟)..."
        if command -v wget >/dev/null 2>&1; then
            local gb_output=$(wget -qO- https://raw.githubusercontent.com/mikeyang01/benchmark-script/master/geekbench5.sh 2>/dev/null | bash 2>/dev/null || echo "")
            local gb_single=$(echo "$gb_output" | grep -o "Single-Core Score[^0-9]*[0-9]*" | grep -o "[0-9]*" | head -1)
            local gb_multi=$(echo "$gb_output" | grep -o "Multi-Core Score[^0-9]*[0-9]*" | grep -o "[0-9]*" | head -1)
            [ -n "$gb_single" ] && echo -e "${BOLD}Geekbench 5 单核${PLAIN}  : ${GREEN}${gb_single}${PLAIN}"
            [ -n "$gb_multi" ] && echo -e "${BOLD}Geekbench 5 多核${PLAIN}  : ${GREEN}${gb_multi}${PLAIN}"
        fi
    fi

    if [ "$TEST_MODE" = "full" ]; then
        print_progress "UnixBench 测试 (十分的久，请耐心)..."
        if command -v wget >/dev/null 2>&1; then
            local ub_output=$(wget -qO- https://raw.githubusercontent.com/teddysun/across/master/unixbench.sh 2>/dev/null | bash 2>/dev/null || echo "")
            local ub_score=$(echo "$ub_output" | grep -o "Benchmark Run:[^0-9]*[0-9.]*" | grep -o "[0-9.]*" | tail -1)
            [ -n "$ub_score" ] && echo -e "${BOLD}UnixBench 总分${PLAIN}    : ${GREEN}${ub_score}${PLAIN}"
        fi
    fi
}

# ============================================================
# 5. 内存性能测试
# ============================================================
test_memory() {
    print_title "🧠 内存性能测试"
    if ! command -v sysbench >/dev/null 2>&1; then
        print_error "sysbench未安装"
        return 1
    fi
    local mem_read=$(sysbench memory --memory-total-size=1G --memory-oper=read run 2>/dev/null | grep "MiB transferred" | awk '{print $4}')
    local mem_write=$(sysbench memory --memory-total-size=1G --memory-oper=write run 2>/dev/null | grep "MiB transferred" | awk '{print $4}')
    local mem_latency=$(sysbench memory --memory-total-size=1G --memory-oper=read run 2>/dev/null | grep "avg:" | awk '{print $3}')
    echo -e "${BOLD}内存读取速度${PLAIN}   : ${GREEN}${mem_read:-N/A}${PLAIN} MiB/s"
    echo -e "${BOLD}内存写入速度${PLAIN}   : ${GREEN}${mem_write:-N/A}${PLAIN} MiB/s"
    echo -e "${BOLD}内存延迟${PLAIN}       : ${mem_latency:-N/A} ns"
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

    if command -v fio >/dev/null 2>&1; then
        local fio_out=$(fio --name=lxbench_4k --size=512M --filename=/tmp/lxbench_fio_test \
            --bs=4k --rw=randrw --ioengine=libaio --iodepth=64 --runtime=20 \
            --numjobs=4 --group_reporting 2>/dev/null || echo "")
        local rand_read=$(echo "$fio_out" | grep "read:" | grep "IOPS" | head -n1 | awk '{print $2}')
        local rand_write=$(echo "$fio_out" | grep "write:" | grep "IOPS" | head -n1 | awk '{print $2}')
        echo -e "${BOLD}4K随机读取${PLAIN}     : ${GREEN}${rand_read:-N/A}${PLAIN} IOPS"
        echo -e "${BOLD}4K随机写入${PLAIN}     : ${GREEN}${rand_write:-N/A}${PLAIN} IOPS"
        rm -f /tmp/lxbench_fio_test
    fi

    if command -v ioping >/dev/null 2>&1; then
        local iop=$(ioping -c 5 . 2>/dev/null | tail -n1 | awk '{print $4}' | tr -d 'ms' 2>/dev/null)
        [ -n "$iop" ] && echo -e "${BOLD}磁盘访问延迟${PLAIN}   : ${GREEN}${iop}${PLAIN} ms"
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
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 2 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        [ -n "$lat" ] && colorize_latency "$lat" || echo -e "${DIM}超时${PLAIN}"
    done
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
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 4 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        [ -n "$lat" ] && colorize_latency "$lat" || echo -e "${DIM}超时${PLAIN}"
    done
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
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
}

test_network_mixed() {
    echo -e "${BOLD}${CYAN}--- 混合网络延迟测试 ---${PLAIN}"
    local nodes=("香港:203.80.96.10" "新加坡:103.7.8.10" "东京:103.28.248.1"
        "洛杉矶:208.67.222.222" "上海:180.153.0.1" "北京:219.141.136.10" "广州:183.56.128.1")
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 3 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        [ -n "$lat" ] && colorize_latency "$lat" || echo -e "${DIM}超时${PLAIN}"
    done
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

    if command -v nexttrace >/dev/null 2>&1; then
        for node in "${back_nodes[@]}"; do
            local name=$(echo "$node" | cut -d: -f1)
            local ip=$(echo "$node" | cut -d: -f2)
            echo -n "  ${name}: "
            nexttrace -q 1 -m 10 "$ip" 2>/dev/null | grep -E "ms|hop" | head -3 | tr '\n' ' ' | cut -c1-70 || echo "无法检测"
        done
    elif command -v traceroute >/dev/null 2>&1; then
        for node in "${back_nodes[@]}"; do
            local name=$(echo "$node" | cut -d: -f1)
            local ip=$(echo "$node" | cut -d: -f2)
            local hops=$(traceroute -n -m 8 "$ip" 2>/dev/null | wc -l)
            echo "  ${name}: $((hops - 1)) 跳"
        done
    else
        print_warn "未安装 traceroute/nexttrace"
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

    for platform in "${platforms[@]}"; do
        local name=$(echo "$platform" | cut -d: -f1)
        local url=$(echo "$platform" | cut -d: -f2-)
        print_progress "检测 ${name}..."
        local result=$(curl -s --max-time 5 -w "%{http_code}" -o /dev/null "$url" 2>/dev/null || echo "000")
        if [ "$result" = "200" ] || [ "$result" = "302" ] || [ "$result" = "301" ]; then
            echo -e "  ${name}: ${GREEN}✅ 可访问${PLAIN}"
        else
            echo -e "  ${name}: ${RED}❌ 不可访问${PLAIN}"
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
        else
            echo -e "${BOLD}IP类型${PLAIN}        : ${GREEN}家庭宽带/移动IP${PLAIN}"
        fi
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
    else
        echo -e "  IPv6连通性: ${RED}❌ 不支持${PLAIN}"
    fi
}

# ============================================================
# 15. 综合评分（重写版 - 基础分+加分制）
# ============================================================
calculate_score() {
    print_title "🏆 综合性能评分"

    # 初始化各项分数（基础分合计45分）
    local score_cpu_integrity=5
    local score_cpu_perf=10
    local score_memory=8
    local score_disk_seq=7
    local score_disk_rand=0
    local score_network=10
    local score_ip=5

    echo ""
    echo -e "${BOLD}评分规则: 基础分45分 + 各维度加分 = 总分 (最高100分)${PLAIN}"
    echo -e "${DIM}评级门槛: 旗舰级≥85 | 优秀≥70 | 良好≥55 | 一般≥40 | 较差<40${PLAIN}"
    echo ""

    # 1. CPU诚信度 (Steal Time)
    print_progress "评估 CPU 诚信度..."
    local steal=$(top -bn1 | grep "Cpu(s)" | awk '{print $NF}' | cut -d'%' -f1 2>/dev/null || echo "0")
    if [ -n "$steal" ]; then
        if (( $(echo "$steal < 1" | bc -l) )); then
            score_cpu_integrity=10
            echo -e "  CPU诚信度: ${GREEN}+5 (Steal < 1%, 优秀)${PLAIN}"
        elif (( $(echo "$steal < 3" | bc -l) )); then
            score_cpu_integrity=8
            echo -e "  CPU诚信度: ${GREEN}+3 (Steal < 3%, 良好)${PLAIN}"
        else
            echo -e "  CPU诚信度: ${YELLOW}+0 (Steal >= 3%, 可能超卖)${PLAIN}"
        fi
    fi

    # 2. CPU性能 (sysbench单核)
    print_progress "评估 CPU 性能..."
    if command -v sysbench >/dev/null 2>&1; then
        local single=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>/dev/null | grep "events per second" | awk '{print $4}')
        if [ -n "$single" ]; then
            if (( $(echo "$single > 1500" | bc -l) )); then
                score_cpu_perf=20
                echo -e "  CPU性能: ${GREEN}+10 (单核 > 1500, 优秀)${PLAIN}"
            elif (( $(echo "$single > 1000" | bc -l) )); then
                score_cpu_perf=15
                echo -e "  CPU性能: ${GREEN}+5 (单核 > 1000, 良好)${PLAIN}"
            else
                echo -e "  CPU性能: ${YELLOW}+0 (单核 <= 1000, 一般)${PLAIN}"
            fi
        fi
    fi

    # 3. 内存性能
    print_progress "评估 内存性能..."
    if command -v sysbench >/dev/null 2>&1; then
        local mem_read=$(sysbench memory --memory-total-size=1G --memory-oper=read run 2>/dev/null | grep "MiB transferred" | awk '{print $4}')
        if [ -n "$mem_read" ]; then
            if (( $(echo "$mem_read > 15000" | bc -l) )); then
                score_memory=15
                echo -e "  内存性能: ${GREEN}+7 (读取 > 15000 MiB/s, 优秀)${PLAIN}"
            elif (( $(echo "$mem_read > 10000" | bc -l) )); then
                score_memory=12
                echo -e "  内存性能: ${GREEN}+4 (读取 > 10000 MiB/s, 良好)${PLAIN}"
            else
                echo -e "  内存性能: ${YELLOW}+0 (读取 <= 10000 MiB/s, 一般)${PLAIN}"
            fi
        fi
    fi

    # 4. 磁盘顺序读写
    print_progress "评估 磁盘顺序读写..."
    local disk_test_file="/tmp/lxbench_disk_score_test"
    local dd_read=$(dd if=/dev/zero of="$disk_test_file" bs=1M count=256 conv=fdatasync 2>&1 | tail -n1 | awk '{print $(NF-1)}' 2>/dev/null)
    rm -f "$disk_test_file"
    if [ -n "$dd_read" ]; then
        if (( $(echo "$dd_read > 500" | bc -l) )); then
            score_disk_seq=15
            echo -e "  磁盘顺序: ${GREEN}+8 (读写 > 500 MB/s, 优秀)${PLAIN}"
        elif (( $(echo "$dd_read > 300" | bc -l) )); then
            score_disk_seq=11
            echo -e "  磁盘顺序: ${GREEN}+4 (读写 > 300 MB/s, 良好)${PLAIN}"
        else
            echo -e "  磁盘顺序: ${YELLOW}+0 (读写 <= 300 MB/s, 一般)${PLAIN}"
        fi
    fi

    # 5. 磁盘4K随机
    if command -v fio >/dev/null 2>&1; then
        print_progress "评估 磁盘4K随机..."
        local fio_out=$(fio --name=lxbench_score --size=256M --filename=/tmp/lxbench_score_test \
            --bs=4k --rw=randread --ioengine=libaio --iodepth=64 --runtime=10 \
            --numjobs=4 --group_reporting 2>/dev/null || echo "")
        local rand_iops=$(echo "$fio_out" | grep "read:" | grep "IOPS" | head -n1 | awk '{print $2}')
        rm -f /tmp/lxbench_score_test
        if [ -n "$rand_iops" ]; then
            if (( $(echo "$rand_iops > 5000" | bc -l) )); then
                score_disk_rand=10
                echo -e "  磁盘4K: ${GREEN}+10 (IOPS > 5000, 优秀)${PLAIN}"
            elif (( $(echo "$rand_iops > 2000" | bc -l) )); then
                score_disk_rand=5
                echo -e "  磁盘4K: ${GREEN}+5 (IOPS > 2000, 良好)${PLAIN}"
            else
                echo -e "  磁盘4K: ${YELLOW}+0 (IOPS <= 2000, 一般)${PLAIN}"
            fi
        fi
    else
        score_disk_rand=2
        echo -e "  磁盘4K: ${DIM}未测试 (fio未安装, 给保底分2分)${PLAIN}"
    fi

    # 6. 网络延迟
    print_progress "评估 网络延迟..."
    local lat_sum=0 lat_count=0
    local test_ips=("180.153.0.1" "210.22.97.1" "211.136.112.50")
    for ip in "${test_ips[@]}"; do
        local lat=$(ping -c 2 -W 2 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        if [ -n "$lat" ]; then
            lat_sum=$(echo "$lat_sum + $lat" | bc)
            lat_count=$((lat_count + 1))
        fi
    done
    if [ $lat_count -gt 0 ]; then
        local lat_avg=$(echo "scale=2; $lat_sum / $lat_count" | bc)
        if (( $(echo "$lat_avg < 30" | bc -l) )); then
            score_network=20
            echo -e "  网络延迟: ${GREEN}+10 (平均 < 30ms, 优秀)${PLAIN}"
        elif (( $(echo "$lat_avg < 60" | bc -l) )); then
            score_network=15
            echo -e "  网络延迟: ${GREEN}+5 (平均 < 60ms, 良好)${PLAIN}"
        else
            echo -e "  网络延迟: ${YELLOW}+0 (平均 >= 60ms, 一般)${PLAIN}"
        fi
    else
        echo -e "  网络延迟: ${DIM}无法检测, 保留基础分${PLAIN}"
    fi

    # 7. IP质量
    print_progress "评估 IP质量..."
    local ip_info=$(curl -s --max-time 3 "http://ip-api.com/json/" 2>/dev/null || echo "")
    if echo "$ip_info" | grep -q '"isp"'; then
        local isp=$(echo "$ip_info" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)
        if echo "$isp" | grep -qi "cloud\|hosting\|datacenter\|server"; then
            echo -e "  IP质量: ${YELLOW}+0 (数据中心IP)${PLAIN}"
        else
            score_ip=10
            echo -e "  IP质量: ${GREEN}+5 (非数据中心IP, 加分)${PLAIN}"
        fi
    else
        echo -e "  IP质量: ${DIM}无法检测, 保留基础分${PLAIN}"
    fi

    # 计算总分
    SCORE_TOTAL=$((score_cpu_integrity + score_cpu_perf + score_memory + score_disk_seq + score_disk_rand + score_network + score_ip))
    [ $SCORE_TOTAL -gt 100 ] && SCORE_TOTAL=100

    # 显示明细
    echo ""
    echo -e "${BOLD}评分明细:${PLAIN}"
    echo -e "  CPU诚信度: ${score_cpu_integrity}/10"
    echo -e "  CPU性能:   ${score_cpu_perf}/20"
    echo -e "  内存性能:  ${score_memory}/15"
    echo -e "  磁盘顺序:  ${score_disk_seq}/15"
    echo -e "  磁盘4K:    ${score_disk_rand}/10"
    echo -e "  网络延迟:  ${score_network}/20"
    echo -e "  IP质量:    ${score_ip}/10"
    echo -e "  ────────────────────"
    echo -e "  ${BOLD}总分:      ${CYAN}${SCORE_TOTAL}/100${PLAIN}"

    # 评级
    echo ""
    echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────┐${PLAIN}"
    echo -e "${BOLD}${CYAN}│  综合性能得分: ${SCORE_TOTAL}/100                      │${PLAIN}"
    if [ $SCORE_TOTAL -ge 85 ]; then
        echo -e "${BOLD}${CYAN}│  评级: ${GREEN}🌟🌟🌟🌟🌟 旗舰级 (Excellent)${PLAIN}         │"
    elif [ $SCORE_TOTAL -ge 70 ]; then
        echo -e "${BOLD}${CYAN}│  评级: ${GREEN}🌟🌟🌟🌟 优秀 (Good)${PLAIN}               │"
    elif [ $SCORE_TOTAL -ge 55 ]; then
        echo -e "${BOLD}${CYAN}│  评级: ${YELLOW}🌟🌟🌟 良好 (Fair)${PLAIN}                │"
    elif [ $SCORE_TOTAL -ge 40 ]; then
        echo -e "${BOLD}${CYAN}│  评级: ${YELLOW}🌟🌟 一般 (Average)${PLAIN}               │"
    else
        echo -e "${BOLD}${CYAN}│  评级: ${RED}🌟 较差 (Poor)${PLAIN}                    │"
    fi
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────┘${PLAIN}"
}

# ============================================================
# 16. HTML报告
# ============================================================
generate_html_report() {
    mkdir -p "$REPORT_DIR"
    cat > "$HTML_REPORT" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>LXBench 2.0 - VPS测评报告</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;background:#0a0e17;color:#e0e0e0;padding:20px;line-height:1.6}
.container{max-width:960px;margin:0 auto;background:#141b2b;border-radius:16px;padding:40px;box-shadow:0 8px 32px rgba(0,0,0,0.5)}
h1{color:#00d4ff;font-size:28px;border-bottom:2px solid #00d4ff33;padding-bottom:16px;margin-bottom:24px}
h2{color:#00d4ff;font-size:20px;margin:28px 0 16px 0;padding-left:12px;border-left:4px solid #00d4ff}
.info-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px 24px;background:#1a2335;padding:16px 20px;border-radius:10px}
.info-grid .label{color:#8899bb}.info-grid .value{color:#e8e8e8}
.score-box{background:linear-gradient(135deg,#1a2335,#0d1524);border:1px solid #00d4ff33;border-radius:12px;padding:24px;text-align:center;margin:16px 0}
.score-number{font-size:52px;font-weight:bold;color:#00d4ff}
.badge{display:inline-block;padding:4px 14px;border-radius:20px;font-size:13px;font-weight:bold}
.badge-excellent{background:#00d4ff22;color:#00d4ff}
.badge-good{background:#00ff8822;color:#00ff88}
.badge-fair{background:#ffaa0022;color:#ffaa00}
.badge-poor{background:#ff444422;color:#ff4444}
.footer{margin-top:32px;padding-top:16px;border-top:1px solid #1a2335;text-align:center;color:#556688;font-size:13px}
.links{color:#8899bb;font-size:14px;margin-top:16px}
.links a{color:#00d4ff;text-decoration:none}
</style>
</head>
<body>
<div class="container">
    <h1>🚀 LXBench 2.0 测评报告</h1>
    <p style="color:#8899bb;margin-bottom:20px;">生成时间: $(date '+%Y-%m-%d %H:%M:%S') | 版本: ${VERSION}</p>
    <h2>📍 服务器信息</h2>
    <div class="info-grid">
        <span class="label">位置</span><span class="value">${SERVER_COUNTRY:-未知} - ${SERVER_CITY:-未知}</span>
        <span class="label">运营商</span><span class="value">${SERVER_ISP:-未知}</span>
        <span class="label">测试模式</span><span class="value">${SERVER_LOCATION}</span>
        <span class="label">综合得分</span><span class="value">${SCORE_TOTAL}/100</span>
    </div>
    <h2>🏆 性能评级</h2>
    <div class="score-box">
        <div class="score-number">${SCORE_TOTAL}</div>
        <div class="score-label">综合性能得分</div>
        <div style="margin-top:12px;">
EOF
    if [ $SCORE_TOTAL -ge 85 ]; then
        echo '<span class="badge badge-excellent">🌟🌟🌟🌟🌟 旗舰级</span>' >> "$HTML_REPORT"
    elif [ $SCORE_TOTAL -ge 70 ]; then
        echo '<span class="badge badge-good">🌟🌟🌟🌟 优秀</span>' >> "$HTML_REPORT"
    elif [ $SCORE_TOTAL -ge 55 ]; then
        echo '<span class="badge badge-fair">🌟🌟🌟 良好</span>' >> "$HTML_REPORT"
    else
        echo '<span class="badge badge-poor">🌟🌟 一般</span>' >> "$HTML_REPORT"
    fi
    cat >> "$HTML_REPORT" << EOF
        </div>
    </div>
    <div class="links">
        <p>📦 GitHub: <a href="${GITHUB_URL}">${GITHUB_URL}</a></p>
        <p>🚀 服务器推荐: <a href="${RAINYUN_URL}">${RAINYUN_URL}</a></p>
        <p>📝 个人博客: <a href="${BLOG_URL}">${BLOG_URL}</a></p>
    </div>
    <div class="footer">LXBench v${VERSION} · 智能双模节点 · 基础分45+加分制 · 超卖检测</div>
</div>
</body>
</html>
EOF
    print_ok "HTML报告: $HTML_REPORT"
}

# ============================================================
# 17. Markdown报告
# ============================================================
generate_md_report() {
    cat > "$MD_REPORT" << EOF
# LXBench 2.0 测评报告

**生成时间**: $(date '+%Y-%m-%d %H:%M:%S')
**版本**: ${VERSION}

## 服务器信息
- **位置**: ${SERVER_COUNTRY:-未知} - ${SERVER_CITY:-未知}
- **运营商**: ${SERVER_ISP:-未知}
- **测试模式**: ${SERVER_LOCATION}
- **综合得分**: ${SCORE_TOTAL}/100

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
    print_ok "感谢使用 LXBench ${VERSION}！"
}

main "$@"
