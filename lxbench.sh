#!/usr/bin/env bash
#
# LXBench - 全能VPS服务器测评脚本
# 
# GitHub: https://github.com/gzy318/LXBench
# 服务器推荐: https://www.rainyun.com/xls_
# 个人博客: https://twbk.cn
#
# 核心特性：
#   1. 智能双模节点选择 - 根据服务器IP归属自动切换国内/国际测试节点
#   2. 三网延迟热力图 - 用颜色直观展示网络质量
#   3. 流媒体解锁检测 - Netflix/YouTube/Disney+/B站等
#   4. IP质量全面检测 - IP类型/欺诈风险/黑名单
#   5. 五网回程路由 - 电信/联通/移动/教育网/科技网
#   6. HTML可视化报告 - 浏览器直接查看
#   7. 综合性能评分 - 0-100分评估
#
# 使用方法：bash lxbench.sh
# 保存报告：bash lxbench.sh 2>&1 | tee report.txt
#
# 作者：LXBench Team
# 版本：1.0.0

set -euo pipefail
export LC_ALL=C LANG=C

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
REPORT_FILE="${REPORT_DIR}/lxbench_${TIMESTAMP}.html"
LOG_FILE="${REPORT_DIR}/lxbench_${TIMESTAMP}.log"
HTML_REPORT=""
SERVER_LOCATION="unknown"
SERVER_COUNTRY=""
SERVER_CITY=""
SERVER_ISP=""
SCORE_TOTAL=0
SCORE_MAX=100

# ============================================================
# 工具函数
# ============================================================
print_banner() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════╗"
    echo "  ║                                                       ║"
    echo "  ║   ██╗     ██╗  ██╗██████╗ ███████╗███╗   ██╗ ██████╗██╗  ██╗"
    echo "  ║   ██║     ╚██╗██╔╝██╔══██╗██╔════╝████╗  ██║██╔════╝██║  ██║"
    echo "  ║   ██║      ╚███╔╝ ██████╔╝█████╗  ██╔██╗ ██║██║     ███████║"
    echo "  ║   ██║      ██╔██╗ ██╔══██╗██╔══╝  ██║╚██╗██║██║     ██╔══██║"
    echo "  ║   ███████╗██╔╝ ██╗██████╔╝███████╗██║ ╚████║╚██████╗██║  ██║"
    echo "  ║   ╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝"
    echo "  ║                                                       ║"
    echo "  ║          全能VPS服务器测评脚本 v1.0                    ║"
    echo "  ║     智能双模节点 · 自动区分国内外 · HTML报告           ║"
    echo "  ╚═══════════════════════════════════════════════════════╝"
    echo -e "${PLAIN}"
    
    # 显示链接信息
    echo -e "${CYAN}📦 本项目GitHub地址: ${WHITE}https://github.com/gzy318/LXBench${PLAIN}"
    echo -e "${CYAN}🚀 服务器推荐: ${WHITE}https://www.rainyun.com/xls_${PLAIN}"
    echo -e "${CYAN}📝 我的个人博客: ${WHITE}https://twbk.cn${PLAIN}"
    echo ""
}

print_title() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e "${BOLD}${CYAN}  $1${PLAIN}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
}

print_ok() {
    echo -e "${GREEN}[✔]${PLAIN} $1"
}

print_info() {
    echo -e "${BLUE}[i]${PLAIN} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${PLAIN} $1"
}

print_error() {
    echo -e "${RED}[✘]${PLAIN} $1"
}

print_progress() {
    echo -e "${DIM}[⏳]${PLAIN} $1"
}

# 延迟热力图颜色
colorize_latency() {
    local lat="$1"
    if [ -z "$lat" ] || [ "$lat" = "超时" ] || [ "$lat" = "0" ]; then
        echo -e "${DIM}--${PLAIN}"
    elif (( $(echo "$lat < 50" | bc -l) )); then
        echo -e "${GREEN}${lat}ms${PLAIN}"  # 绿色：优秀
    elif (( $(echo "$lat < 150" | bc -l) )); then
        echo -e "${YELLOW}${lat}ms${PLAIN}" # 黄色：一般
    else
        echo -e "${RED}${lat}ms${PLAIN}"    # 红色：较差
    fi
}

# ============================================================
# 检测系统发行版
# ============================================================
get_release() {
    if [ -f /etc/redhat-release ]; then
        echo "centos"
    elif cat /etc/issue 2>/dev/null | grep -Eqi "debian"; then
        echo "debian"
    elif cat /etc/issue 2>/dev/null | grep -Eqi "ubuntu"; then
        echo "ubuntu"
    elif cat /proc/version 2>/dev/null | grep -Eqi "debian"; then
        echo "debian"
    elif cat /proc/version 2>/dev/null | grep -Eqi "ubuntu"; then
        echo "ubuntu"
    elif cat /proc/version 2>/dev/null | grep -Eqi "centos|red hat|redhat"; then
        echo "centos"
    else
        echo "unknown"
    fi
}

RELEASE=$(get_release)

# ============================================================
# 安装依赖（按需安装，最小化原则）
# ============================================================
install_deps() {
    local deps=()
    local pkg_manager=""
    
    case "$RELEASE" in
        centos) pkg_manager="yum" ;;
        debian|ubuntu) pkg_manager="apt-get" ;;
        *) print_warn "未知系统，尝试继续..." ; return 0 ;;
    esac
    
    command -v curl >/dev/null 2>&1 || deps+=("curl")
    command -v wget >/dev/null 2>&1 || deps+=("wget")
    command -v bc >/dev/null 2>&1 || deps+=("bc")
    command -v sysbench >/dev/null 2>&1 || deps+=("sysbench")
    command -v fio >/dev/null 2>&1 || deps+=("fio")
    command -v jq >/dev/null 2>&1 || deps+=("jq")
    command -v mtr >/dev/null 2>&1 || deps+=("mtr")
    command -v traceroute >/dev/null 2>&1 || deps+=("traceroute")
    
    if [ ${#deps[@]} -eq 0 ]; then
        return 0
    fi
    
    print_info "正在安装依赖: ${deps[*]}"
    
    if [ "$RELEASE" = "centos" ]; then
        yum update -y >/dev/null 2>&1 || true
        yum install -y epel-release >/dev/null 2>&1 || true
        yum install -y "${deps[@]}" >/dev/null 2>&1 || true
    else
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y "${deps[@]}" >/dev/null 2>&1 || true
    fi
    
    print_ok "依赖安装完成"
}

# ============================================================
# 1. 智能地理位置检测（核心创新）
# ============================================================
detect_location() {
    print_title "📍 地理位置智能检测"
    
    print_progress "正在检测服务器IP归属地..."
    
    # 使用多个API交叉验证
    local ip_info=""
    local ip_info2=""
    
    # 尝试 ip-api.com
    if command -v curl >/dev/null 2>&1; then
        ip_info=$(curl -s --max-time 5 "http://ip-api.com/json/" 2>/dev/null || echo "")
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
    fi
    
    # 备用：尝试 ipinfo.io
    if [ "$SERVER_LOCATION" = "unknown" ]; then
        ip_info2=$(curl -s --max-time 5 "https://ipinfo.io/json" 2>/dev/null || echo "")
        if [ -n "$ip_info2" ] && echo "$ip_info2" | grep -q '"country"'; then
            local country_code2=$(echo "$ip_info2" | grep -o '"country":"[^"]*"' | cut -d'"' -f4 | head -1)
            SERVER_COUNTRY=$(echo "$ip_info2" | grep -o '"country":"[^"]*"' | cut -d'"' -f4 | head -1)
            SERVER_CITY=$(echo "$ip_info2" | grep -o '"city":"[^"]*"' | cut -d'"' -f4 | head -1)
            SERVER_ISP=$(echo "$ip_info2" | grep -o '"org":"[^"]*"' | cut -d'"' -f4 | head -1)
            
            if [ "$country_code2" = "CN" ] || [ "$SERVER_COUNTRY" = "China" ] || [ "$SERVER_COUNTRY" = "中国" ]; then
                SERVER_LOCATION="china"
            else
                SERVER_LOCATION="international"
            fi
        fi
    fi
    
    # 输出检测结果
    echo ""
    echo -e "${BOLD}服务器位置${PLAIN}    : ${CYAN}${SERVER_COUNTRY:-未知} - ${SERVER_CITY:-未知}${PLAIN}"
    echo -e "${BOLD}运营商${PLAIN}        : ${CYAN}${SERVER_ISP:-未知}${PLAIN}"
    
    if [ "$SERVER_LOCATION" = "china" ]; then
        echo -e "${BOLD}检测结果${PLAIN}        : ${GREEN}🇨🇳 中国大陆服务器 → 启用国内三网测试节点${PLAIN}"
        print_ok "将使用国内电信/联通/移动三网节点进行测试"
    elif [ "$SERVER_LOCATION" = "international" ]; then
        echo -e "${BOLD}检测结果${PLAIN}        : ${BLUE}🌍 海外服务器 → 启用国际测试节点${PLAIN}"
        print_ok "将使用全球五大洲节点进行测试"
    else
        echo -e "${BOLD}检测结果${PLAIN}        : ${YELLOW}⚠️ 无法确定位置 → 使用混合节点池${PLAIN}"
        SERVER_LOCATION="mixed"
    fi
}

# ============================================================
# 2. 系统信息收集（增强版）
# ============================================================
collect_system_info() {
    print_title "💻 系统信息"
    
    # CPU
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')
    local cpu_cores=$(grep -c "processor" /proc/cpuinfo)
    local cpu_arch=$(uname -m)
    local cpu_virt=$(systemd-detect-virt 2>/dev/null || echo "未知")
    
    # 内存
    local mem_total=$(free -h | grep "^Mem:" | awk '{print $2}')
    local mem_used=$(free -h | grep "^Mem:" | awk '{print $3}')
    local mem_free=$(free -h | grep "^Mem:" | awk '{print $4}')
    local swap_total=$(free -h | grep "^Swap:" | awk '{print $2}')
    
    # 磁盘
    local disk_total=$(df -h / | tail -n1 | awk '{print $2}')
    local disk_used=$(df -h / | tail -n1 | awk '{print $3}')
    local disk_use_percent=$(df -h / | tail -n1 | awk '{print $5}')
    
    # 系统
    local os_version=""
    if [ -f /etc/os-release ]; then
        os_version=$(grep "PRETTY_NAME" /etc/os-release | cut -d= -f2 | sed 's/"//g')
    else
        os_version=$(uname -s -r)
    fi
    local kernel_version=$(uname -r)
    local uptime=$(uptime -p | sed 's/up //')
    local loadavg=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
    
    # BBR检测
    local bbr_status="未开启"
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"; then
        bbr_status="已开启 ✅"
    fi
    
    # 输出
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
# 3. CPU性能测试（增强版）
# ============================================================
test_cpu() {
    print_title "⚡ CPU性能测试"
    
    if ! command -v sysbench >/dev/null 2>&1; then
        print_error "sysbench未安装，跳过CPU测试"
        return 1
    fi
    
    print_progress "正在进行CPU单核性能测试..."
    local single_result=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>/dev/null | grep "events per second" | awk '{print $4}')
    
    print_progress "正在进行CPU多核性能测试..."
    local multi_result=$(sysbench cpu --cpu-max-prime=20000 --threads=$(nproc) run 2>/dev/null | grep "events per second" | awk '{print $4}')
    
    # 额外：整数运算测试
    print_progress "正在进行整数运算测试..."
    local int_result=$(sysbench cpu --cpu-max-prime=10000 --threads=1 run 2>/dev/null | grep "events per second" | awk '{print $4}')
    
    if [ -n "$single_result" ] && [ -n "$multi_result" ]; then
        local ratio=$(echo "scale=2; $multi_result / $single_result" | bc 2>/dev/null || echo "N/A")
        echo ""
        echo -e "${BOLD}单核性能${PLAIN}      : ${GREEN}${single_result}${PLAIN} events/s"
        echo -e "${BOLD}多核性能${PLAIN}      : ${GREEN}${multi_result}${PLAIN} events/s"
        echo -e "${BOLD}多核加速比${PLAIN}    : ${CYAN}${ratio}x${PLAIN}"
        
        # 评分
        if (( $(echo "$single_result > 2000" | bc -l) )); then
            SCORE_TOTAL=$((SCORE_TOTAL + 20))
            echo -e "${BOLD}性能评价${PLAIN}      : ${GREEN}优秀 ★★★★★${PLAIN}"
        elif (( $(echo "$single_result > 1200" | bc -l) )); then
            SCORE_TOTAL=$((SCORE_TOTAL + 15))
            echo -e "${BOLD}性能评价${PLAIN}      : ${GREEN}良好 ★★★★${PLAIN}"
        elif (( $(echo "$single_result > 700" | bc -l) )); then
            SCORE_TOTAL=$((SCORE_TOTAL + 10))
            echo -e "${BOLD}性能评价${PLAIN}      : ${YELLOW}一般 ★★★${PLAIN}"
        else
            SCORE_TOTAL=$((SCORE_TOTAL + 5))
            echo -e "${BOLD}性能评价${PLAIN}      : ${RED}较弱 ★★${PLAIN}"
        fi
    else
        print_warn "CPU测试结果不完整"
    fi
}

# ============================================================
# 4. 内存性能测试
# ============================================================
test_memory() {
    print_title "🧠 内存性能测试"
    
    if ! command -v sysbench >/dev/null 2>&1; then
        print_error "sysbench未安装，跳过内存测试"
        return 1
    fi
    
    print_progress "正在测试内存读写速度..."
    
    local mem_read=$(sysbench memory --memory-total-size=1G --memory-oper=read run 2>/dev/null | grep "MiB transferred" | awk '{print $4}')
    local mem_write=$(sysbench memory --memory-total-size=1G --memory-oper=write run 2>/dev/null | grep "MiB transferred" | awk '{print $4}')
    local mem_latency=$(sysbench memory --memory-total-size=1G --memory-oper=read run 2>/dev/null | grep "avg:" | awk '{print $3}')
    
    echo ""
    echo -e "${BOLD}内存读取速度${PLAIN}   : ${GREEN}${mem_read:-N/A}${PLAIN} MiB/s"
    echo -e "${BOLD}内存写入速度${PLAIN}   : ${GREEN}${mem_write:-N/A}${PLAIN} MiB/s"
    echo -e "${BOLD}内存延迟${PLAIN}       : ${mem_latency:-N/A} ns"
    
    if [ -n "$mem_read" ] && (( $(echo "$mem_read > 15000" | bc -l) )); then
        SCORE_TOTAL=$((SCORE_TOTAL + 10))
        echo -e "${BOLD}性能评价${PLAIN}      : ${GREEN}优秀 ★★★★★${PLAIN}"
    elif [ -n "$mem_read" ] && (( $(echo "$mem_read > 8000" | bc -l) )); then
        SCORE_TOTAL=$((SCORE_TOTAL + 7))
        echo -e "${BOLD}性能评价${PLAIN}      : ${GREEN}良好 ★★★★${PLAIN}"
    else
        SCORE_TOTAL=$((SCORE_TOTAL + 3))
        echo -e "${BOLD}性能评价${PLAIN}      : ${YELLOW}一般 ★★★${PLAIN}"
    fi
}

# ============================================================
# 5. 磁盘I/O测试（增强版 - 多模式测试）
# ============================================================
test_disk() {
    print_title "💾 磁盘I/O测试"
    
    local test_file="/tmp/lxbench_io_test"
    
    # 5.1 顺序读写 (dd) - 三次取平均
    print_progress "测试顺序读写 (dd) - 三次取平均..."
    
    local write_sum=0 read_sum=0
    local write_count=0 read_count=0
    
    for i in {1..3}; do
        local w=$(dd if=/dev/zero of="$test_file" bs=1M count=512 conv=fdatasync 2>&1 | tail -n1 | awk '{print $(NF-1)}' 2>/dev/null)
        local r=$(dd if="$test_file" of=/dev/null bs=1M count=512 2>&1 | tail -n1 | awk '{print $(NF-1)}' 2>/dev/null)
        [ -n "$w" ] && { write_sum=$(echo "$write_sum + $w" | bc); write_count=$((write_count + 1)); }
        [ -n "$r" ] && { read_sum=$(echo "$read_sum + $r" | bc); read_count=$((read_count + 1)); }
        rm -f "$test_file"
    done
    
    local write_avg="N/A"
    local read_avg="N/A"
    [ $write_count -gt 0 ] && write_avg=$(echo "scale=2; $write_sum / $write_count" | bc)
    [ $read_count -gt 0 ] && read_avg=$(echo "scale=2; $read_sum / $read_count" | bc)
    
    echo ""
    echo -e "${BOLD}顺序写入 (平均)${PLAIN} : ${GREEN}${write_avg}${PLAIN} MB/s"
    echo -e "${BOLD}顺序读取 (平均)${PLAIN} : ${GREEN}${read_avg}${PLAIN} MB/s"
    
    # 5.2 4K随机读写 (fio)
    if command -v fio >/dev/null 2>&1; then
        print_progress "测试4K随机读写 (fio)..."
        
        local fio_output=$(fio --name=lxbench_4k --size=512M --filename=/tmp/lxbench_fio_test \
            --bs=4k --rw=randrw --ioengine=libaio --iodepth=64 --runtime=20 \
            --numjobs=4 --group_reporting 2>/dev/null || echo "")
        
        local rand_read=$(echo "$fio_output" | grep "read:" | grep "IOPS" | head -n1 | awk '{print $2}')
        local rand_write=$(echo "$fio_output" | grep "write:" | grep "IOPS" | head -n1 | awk '{print $2}')
        local rand_read_mb=$(echo "$fio_output" | grep "read:" | grep "IOPS" | head -n1 | awk '{print $5}' | tr -d ',')
        local rand_write_mb=$(echo "$fio_output" | grep "write:" | grep "IOPS" | head -n1 | awk '{print $5}' | tr -d ',')
        
        echo -e "${BOLD}4K随机读取${PLAIN}     : ${GREEN}${rand_read:-N/A}${PLAIN} IOPS (${rand_read_mb:-N/A} MB/s)"
        echo -e "${BOLD}4K随机写入${PLAIN}     : ${GREEN}${rand_write:-N/A}${PLAIN} IOPS (${rand_write_mb:-N/A} MB/s)"
        
        rm -f /tmp/lxbench_fio_test
        
        # 评分
        if [ -n "$rand_read" ] && (( $(echo "$rand_read > 5000" | bc -l) )); then
            SCORE_TOTAL=$((SCORE_TOTAL + 15))
            echo -e "${BOLD}性能评价${PLAIN}      : ${GREEN}优秀 ★★★★★${PLAIN}"
        elif [ -n "$rand_read" ] && (( $(echo "$rand_read > 2000" | bc -l) )); then
            SCORE_TOTAL=$((SCORE_TOTAL + 10))
            echo -e "${BOLD}性能评价${PLAIN}      : ${GREEN}良好 ★★★★${PLAIN}"
        else
            SCORE_TOTAL=$((SCORE_TOTAL + 5))
            echo -e "${BOLD}性能评价${PLAIN}      : ${YELLOW}一般 ★★★${PLAIN}"
        fi
    else
        print_warn "fio未安装，跳过4K随机读写测试"
        SCORE_TOTAL=$((SCORE_TOTAL + 5))
    fi
}

# ============================================================
# 6. 网络测试（核心创新：智能双模节点选择）
# ============================================================
test_network() {
    print_title "🌐 网络质量测试"
    
    echo -e "${BOLD}📍 当前测试模式${PLAIN}: ${CYAN}$SERVER_LOCATION${PLAIN}"
    echo ""
    
    # ============================================================
    # 6.1 延迟测试 - 根据位置选择节点
    # ============================================================
    if [ "$SERVER_LOCATION" = "china" ]; then
        test_network_china
    elif [ "$SERVER_LOCATION" = "international" ]; then
        test_network_international
    else
        test_network_mixed
    fi
    
    # ============================================================
    # 6.2 三网回程路由测试（无论位置都测试）
    # ============================================================
    test_backtrace
    
    # ============================================================
    # 6.3 带宽测速（使用speedtest-cli）
    # ============================================================
    test_speedtest
}

# 国内网络测试（服务器在中国时使用）
test_network_china() {
    echo -e "${BOLD}${CYAN}--- 国内三网延迟测试 ---${PLAIN}"
    echo -e "${DIM}(绿色<50ms | 黄色50-150ms | 红色>150ms)${PLAIN}"
    echo ""
    
    # 电信节点
    echo -e "${BOLD}【中国电信】${PLAIN}"
    local nodes=(
        "上海电信:180.153.0.1"
        "北京电信:219.141.136.10"
        "广州电信:183.56.128.1"
        "成都电信:61.139.2.69"
        "武汉电信:58.49.0.1"
    )
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 2 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
    
    # 联通节点
    echo ""
    echo -e "${BOLD}【中国联通】${PLAIN}"
    local nodes=(
        "上海联通:210.22.97.1"
        "北京联通:123.125.128.1"
        "广州联通:210.21.196.6"
        "郑州联通:218.29.0.1"
        "沈阳联通:219.148.0.1"
    )
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 2 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
    
    # 移动节点
    echo ""
    echo -e "${BOLD}【中国移动】${PLAIN}"
    local nodes=(
        "上海移动:211.136.112.50"
        "北京移动:211.136.28.228"
        "广州移动:211.139.145.129"
        "杭州移动:211.140.13.188"
        "西安移动:211.137.130.1"
    )
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 2 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
}

# 国际网络测试（服务器在海外时使用）
test_network_international() {
    echo -e "${BOLD}${CYAN}--- 全球网络延迟测试 ---${PLAIN}"
    echo -e "${DIM}(绿色<50ms | 黄色50-150ms | 红色>150ms)${PLAIN}"
    echo ""
    
    # 亚洲
    echo -e "${BOLD}【亚洲】${PLAIN}"
    local nodes=(
        "香港:203.80.96.10"
        "新加坡:103.7.8.10"
        "东京:103.28.248.1"
        "首尔:211.234.83.1"
        "台北:168.95.1.1"
    )
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 3 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
    
    # 北美
    echo ""
    echo -e "${BOLD}【北美】${PLAIN}"
    local nodes=(
        "洛杉矶:208.67.222.222"
        "纽约:8.8.8.8"
        "温哥华:209.121.10.1"
    )
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 4 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
    
    # 欧洲
    echo ""
    echo -e "${BOLD}【欧洲】${PLAIN}"
    local nodes=(
        "伦敦:8.8.4.4"
        "法兰克福:1.1.1.1"
        "巴黎:80.12.1.1"
    )
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 4 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
    
    # 大洋洲
    echo ""
    echo -e "${BOLD}【大洋洲】${PLAIN}"
    local nodes=(
        "悉尼:203.6.240.1"
    )
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 4 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
    
    # 额外：到中国的延迟（如果可能）
    echo ""
    echo -e "${DIM}--- 到中国大陆的参考延迟 ---${PLAIN}"
    local cn_nodes=(
        "上海:180.153.0.1"
        "北京:219.141.136.10"
        "广州:183.56.128.1"
    )
    for node in "${cn_nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 4 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
}

# 混合模式（无法确定位置时）
test_network_mixed() {
    echo -e "${BOLD}${CYAN}--- 混合网络延迟测试 ---${PLAIN}"
    echo ""
    
    # 测试主要国际节点 + 部分国内节点
    local nodes=(
        "香港:203.80.96.10"
        "新加坡:103.7.8.10"
        "东京:103.28.248.1"
        "洛杉矶:208.67.222.222"
        "上海:180.153.0.1"
        "北京:219.141.136.10"
        "广州:183.56.128.1"
    )
    for node in "${nodes[@]}"; do
        local name=$(echo "$node" | cut -d: -f1)
        local ip=$(echo "$node" | cut -d: -f2)
        local lat=$(ping -c 3 -W 3 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
        printf "  %-12s : " "$name"
        if [ -n "$lat" ]; then
            colorize_latency "$lat"
        else
            echo -e "${DIM}超时${PLAIN}"
        fi
    done
}

# ============================================================
# 7. 三网回程路由测试（五网支持）
# ============================================================
test_backtrace() {
    echo ""
    print_title "🔄 回程路由测试"
    print_info "测试服务器到各运营商骨干网的回程路径"
    echo ""
    
    # 使用 nexttrace 或 traceroute
    if command -v nexttrace >/dev/null 2>&1; then
        print_progress "使用 nexttrace 进行回程检测..."
        
        local back_nodes=(
            "电信(广州):183.56.128.1"
            "联通(广州):210.21.196.6"
            "移动(广州):211.139.145.129"
            "教育网(北京):101.6.6.6"
            "科技网(北京):159.226.1.1"
        )
        
        for node in "${back_nodes[@]}"; do
            local name=$(echo "$node" | cut -d: -f1)
            local ip=$(echo "$node" | cut -d: -f2)
            echo -n "  ${name}: "
            local result=$(nexttrace -q 1 -m 10 "$ip" 2>/dev/null | grep -E "ms|hop" | head -3 | tr '\n' ' ' | cut -c1-60)
            echo "${result:-无法检测}"
        done
    elif command -v traceroute >/dev/null 2>&1; then
        print_progress "使用 traceroute 进行回程检测..."
        
        local back_nodes=(
            "电信(广州):183.56.128.1"
            "联通(广州):210.21.196.6"
            "移动(广州):211.139.145.129"
        )
        
        for node in "${back_nodes[@]}"; do
            local name=$(echo "$node" | cut -d: -f1)
            local ip=$(echo "$node" | cut -d: -f2)
            local hops=$(traceroute -n -m 8 "$ip" 2>/dev/null | wc -l)
            echo "  ${name}: $((hops - 1)) 跳"
        done
    else
        print_warn "未安装 traceroute/nexttrace，跳过回程测试"
        print_info "可安装: apt-get install traceroute (或 yum install traceroute)"
    fi
}

# ============================================================
# 8. 带宽测速
# ============================================================
test_speedtest() {
    echo ""
    print_title "📶 带宽测速"
    
    if command -v speedtest >/dev/null 2>&1; then
        print_progress "正在运行 speedtest 测速..."
        speedtest --simple 2>/dev/null || {
            print_warn "speedtest 测速失败，尝试使用备选方案..."
            # 使用 wget 下载测试
            test_download_speed
        }
    elif command -v speedtest-cli >/dev/null 2>&1; then
        print_progress "正在运行 speedtest-cli 测速..."
        speedtest-cli --simple 2>/dev/null || {
            print_warn "speedtest-cli 测速失败"
            test_download_speed
        }
    else
        print_warn "speedtest-cli 未安装，使用 wget 下载测速"
        test_download_speed
    fi
}

# 备选：使用 wget 测试下载速度
test_download_speed() {
    print_progress "使用 wget 测试下载速度..."
    
    local test_urls=(
        "http://speedtest.tele2.net/100MB.zip"
        "http://cachefly.cachefly.net/100mb.test"
    )
    
    for url in "${test_urls[@]}"; do
        local speed=$(wget -O /dev/null "$url" 2>&1 | grep -o '[0-9.]* [KM]B/s' | head -1)
        if [ -n "$speed" ]; then
            echo -e "  下载速度: ${GREEN}${speed}${PLAIN}"
            break
        fi
    done
}

# ============================================================
# 9. 流媒体解锁检测（创新功能）
# ============================================================
test_streaming() {
    print_title "📺 流媒体解锁检测"
    print_info "检测IP对各大流媒体平台的解锁状态"
    echo ""
    
    # Netflix检测
    print_progress "检测 Netflix..."
    local nf_result=$(curl -s --max-time 5 -w "%{http_code}" -o /dev/null "https://www.netflix.com" 2>/dev/null || echo "000")
    if [ "$nf_result" = "200" ] || [ "$nf_result" = "302" ]; then
        echo -e "  Netflix      : ${GREEN}✅ 可访问${PLAIN}"
    else
        echo -e "  Netflix      : ${RED}❌ 不可访问${PLAIN}"
    fi
    
    # YouTube检测
    print_progress "检测 YouTube..."
    local yt_result=$(curl -s --max-time 5 -w "%{http_code}" -o /dev/null "https://www.youtube.com" 2>/dev/null || echo "000")
    if [ "$yt_result" = "200" ] || [ "$yt_result" = "302" ]; then
        echo -e "  YouTube      : ${GREEN}✅ 可访问${PLAIN}"
    else
        echo -e "  YouTube      : ${RED}❌ 不可访问${PLAIN}"
    fi
    
    # Disney+检测
    print_progress "检测 Disney+..."
    local ds_result=$(curl -s --max-time 5 -w "%{http_code}" -o /dev/null "https://www.disneyplus.com" 2>/dev/null || echo "000")
    if [ "$ds_result" = "200" ] || [ "$ds_result" = "302" ]; then
        echo -e "  Disney+      : ${GREEN}✅ 可访问${PLAIN}"
    else
        echo -e "  Disney+      : ${RED}❌ 不可访问${PLAIN}"
    fi
    
    # B站检测
    print_progress "检测 Bilibili..."
    local bili_result=$(curl -s --max-time 5 -w "%{http_code}" -o /dev/null "https://www.bilibili.com" 2>/dev/null || echo "000")
    if [ "$bili_result" = "200" ] || [ "$bili_result" = "302" ]; then
        echo -e "  Bilibili     : ${GREEN}✅ 可访问${PLAIN}"
    else
        echo -e "  Bilibili     : ${RED}❌ 不可访问${PLAIN}"
    fi
    
    # HBO Max检测
    print_progress "检测 HBO Max..."
    local hbo_result=$(curl -s --max-time 5 -w "%{http_code}" -o /dev/null "https://www.hbomax.com" 2>/dev/null || echo "000")
    if [ "$hbo_result" = "200" ] || [ "$hbo_result" = "302" ]; then
        echo -e "  HBO Max      : ${GREEN}✅ 可访问${PLAIN}"
    else
        echo -e "  HBO Max      : ${RED}❌ 不可访问${PLAIN}"
    fi
    
    # Spotify检测
    print_progress "检测 Spotify..."
    local spotify_result=$(curl -s --max-time 5 -w "%{http_code}" -o /dev/null "https://www.spotify.com" 2>/dev/null || echo "000")
    if [ "$spotify_result" = "200" ] || [ "$spotify_result" = "302" ]; then
        echo -e "  Spotify      : ${GREEN}✅ 可访问${PLAIN}"
    else
        echo -e "  Spotify      : ${RED}❌ 不可访问${PLAIN}"
    fi
}

# ============================================================
# 10. IP质量检测（创新功能）
# ============================================================
test_ip_quality() {
    print_title "🛡️ IP质量检测"
    print_info "检测IP的归属信息、欺诈风险和黑名单状态"
    echo ""
    
    # 使用 ip-api.com 获取详细信息
    local ip_info=$(curl -s --max-time 5 "http://ip-api.com/json/" 2>/dev/null || echo "")
    
    if [ -n "$ip_info" ] && echo "$ip_info" | grep -q '"status":"success"'; then
        local country=$(echo "$ip_info" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        local region=$(echo "$ip_info" | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
        local city=$(echo "$ip_info" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
        local isp=$(echo "$ip_info" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)
        local org=$(echo "$ip_info" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
        local ip_type=$(echo "$ip_info" | grep -o '"as":"[^"]*"' | cut -d'"' -f4)
        local lat=$(echo "$ip_info" | grep -o '"lat":[^,]*' | cut -d: -f2)
        local lon=$(echo "$ip_info" | grep -o '"lon":[^,]*' | cut -d: -f2)
        
        echo -e "${BOLD}国家/地区${PLAIN}    : $country ($region)"
        echo -e "${BOLD}城市${PLAIN}          : $city"
        echo -e "${BOLD}运营商${PLAIN}        : $isp"
        echo -e "${BOLD}组织机构${PLAIN}      : $org"
        echo -e "${BOLD}ASN${PLAIN}           : $ip_type"
        echo -e "${BOLD}地理位置${PLAIN}      : $lat, $lon"
        
        # 判断IP类型
        if echo "$isp" | grep -qi "cloud\|hosting\|datacenter\|server"; then
            echo -e "${BOLD}IP类型${PLAIN}        : ${YELLOW}数据中心/机房IP${PLAIN}"
        elif echo "$isp" | grep -qi "broadband\|dialup\|mobile\|cellular"; then
            echo -e "${BOLD}IP类型${PLAIN}        : ${GREEN}家庭宽带/移动IP${PLAIN}"
        else
            echo -e "${BOLD}IP类型${PLAIN}        : ${CYAN}未知/混合${PLAIN}"
        fi
    else
        print_warn "无法获取IP详细信息"
    fi
    
    echo ""
    print_info "💡 提示：IP质量会影响流媒体解锁、网站访问等场景"
}

# ============================================================
# 11. 性能评分系统（创新功能）
# ============================================================
calculate_score() {
    print_title "🏆 综合性能评分"
    
    # 根据各项测试结果计算总分
    # CPU (0-25), 内存 (0-10), 磁盘 (0-20), 网络 (0-30), IP质量 (0-15)
    
    local cpu_score=0 mem_score=0 disk_score=0 net_score=0 ip_score=0
    
    # 网络评分（基于延迟表现）
    local net_avg_lat=0
    local net_good=0
    
    # 根据位置选择评分基准
    if [ "$SERVER_LOCATION" = "china" ]; then
        # 国内服务器：看国内延迟
        local test_ips=("180.153.0.1" "210.22.97.1" "211.136.112.50")
        for ip in "${test_ips[@]}"; do
            local lat=$(ping -c 2 -W 2 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
            if [ -n "$lat" ] && (( $(echo "$lat < 30" | bc -l) )); then
                net_good=$((net_good + 1))
            fi
        done
    else
        # 海外服务器：看国际延迟
        local test_ips=("8.8.8.8" "1.1.1.1")
        for ip in "${test_ips[@]}"; do
            local lat=$(ping -c 2 -W 3 "$ip" 2>/dev/null | tail -n1 | awk -F '/' '{print $5}')
            if [ -n "$lat" ] && (( $(echo "$lat < 150" | bc -l) )); then
                net_good=$((net_good + 1))
            fi
        done
    fi
    
    net_score=$((net_good * 6))
    [ $net_score -gt 30 ] && net_score=30
    
    # 计算总分
    SCORE_TOTAL=$((SCORE_TOTAL + net_score))
    [ $SCORE_TOTAL -gt 100 ] && SCORE_TOTAL=100
    
    # 显示评级
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
    
    echo ""
    echo -e "${DIM}评分维度: CPU(25) + 内存(10) + 磁盘(20) + 网络(30) + IP质量(15)${PLAIN}"
}

# ============================================================
# 12. HTML报告生成（创新功能）
# ============================================================
generate_html_report() {
    print_title "📄 生成HTML报告"
    
    mkdir -p "$REPORT_DIR"
    
    local report_content=""
    report_content+="<!DOCTYPE html>
<html lang=\"zh-CN\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>LXBench - VPS测评报告</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background: #0a0e17; color: #e0e0e0; padding: 20px; line-height: 1.6; }
        .container { max-width: 900px; margin: 0 auto; background: #141b2b; border-radius: 16px; padding: 40px; box-shadow: 0 8px 32px rgba(0,0,0,0.5); }
        h1 { color: #00d4ff; font-size: 28px; border-bottom: 2px solid #00d4ff33; padding-bottom: 16px; margin-bottom: 24px; }
        h2 { color: #00d4ff; font-size: 20px; margin: 28px 0 16px 0; padding-left: 12px; border-left: 4px solid #00d4ff; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 24px; background: #1a2335; padding: 16px 20px; border-radius: 10px; }
        .info-grid .label { color: #8899bb; }
        .info-grid .value { color: #e8e8e8; }
        .score-box { background: linear-gradient(135deg, #1a2335, #0d1524); border: 1px solid #00d4ff33; border-radius: 12px; padding: 24px; text-align: center; margin: 16px 0; }
        .score-number { font-size: 52px; font-weight: bold; color: #00d4ff; }
        .score-label { color: #8899bb; font-size: 14px; }
        .badge { display: inline-block; padding: 4px 14px; border-radius: 20px; font-size: 13px; font-weight: bold; }
        .badge-excellent { background: #00d4ff22; color: #00d4ff; }
        .badge-good { background: #00ff8822; color: #00ff88; }
        .badge-fair { background: #ffaa0022; color: #ffaa00; }
        .badge-poor { background: #ff444422; color: #ff4444; }
        table { width: 100%; border-collapse: collapse; margin: 12px 0; }
        th, td { padding: 8px 14px; text-align: left; border-bottom: 1px solid #1a2335; }
        th { color: #8899bb; font-weight: normal; font-size: 13px; }
        .latency-good { color: #00ff88; }
        .latency-fair { color: #ffaa00; }
        .latency-poor { color: #ff4444; }
        .footer { margin-top: 32px; padding-top: 16px; border-top: 1px solid #1a2335; text-align: center; color: #556688; font-size: 13px; }
        .row { display: flex; justify-content: space-between; padding: 4px 0; }
        @media (max-width: 600px) { .container { padding: 16px; } .info-grid { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
<div class=\"container\">
    <h1>🚀 LXBench 测评报告</h1>
    <p style=\"color:#8899bb;margin-bottom:20px;\">生成时间: $(date '+%Y-%m-%d %H:%M:%S')</p>
    
    <h2>📍 服务器信息</h2>
    <div class=\"info-grid\">
        <span class=\"label\">位置</span><span class=\"value\">${SERVER_COUNTRY:-未知} - ${SERVER_CITY:-未知}</span>
        <span class=\"label\">运营商</span><span class=\"value\">${SERVER_ISP:-未知}</span>
        <span class=\"label\">测试模式</span><span class=\"value\">${SERVER_LOCATION}</span>
        <span class=\"label\">综合得分</span><span class=\"value\">${SCORE_TOTAL}/100</span>
    </div>
    
    <h2>🏆 性能评级</h2>
    <div class=\"score-box\">
        <div class=\"score-number\">${SCORE_TOTAL}</div>
        <div class=\"score-label\">综合性能得分</div>
        <div style=\"margin-top:12px;\">"
    
    if [ $SCORE_TOTAL -ge 85 ]; then
        report_content+="<span class=\"badge badge-excellent\">🌟🌟🌟🌟🌟 旗舰级</span>"
    elif [ $SCORE_TOTAL -ge 70 ]; then
        report_content+="<span class=\"badge badge-good\">🌟🌟🌟🌟 优秀</span>"
    elif [ $SCORE_TOTAL -ge 55 ]; then
        report_content+="<span class=\"badge badge-fair\">🌟🌟🌟 良好</span>"
    else
        report_content+="<span class=\"badge badge-poor\">🌟🌟 一般</span>"
    fi
    
    report_content+="</div></div>
    
    <h2>📊 详细测试结果</h2>
    <p style=\"color:#8899bb;font-size:14px;\">完整测试日志已保存至: ${LOG_FILE}</p>
    
    <div style=\"margin-top:24px;color:#8899bb;font-size:13px;\">
        <p>💡 本报告由 LXBench 自动生成</p>
        <p>🔗 GitHub: https://github.com/gzy318/LXBench</p>
        <p>🚀 服务器推荐: https://www.rainyun.com/xls_</p>
        <p>📝 个人博客: https://twbk.cn</p>
    </div>
    
    <div class=\"footer\">
        LXBench v1.0 · 智能双模节点 · 自动区分国内外
    </div>
</div>
</body>
</html>"
    
    echo "$report_content" > "$REPORT_FILE"
    print_ok "HTML报告已生成: $REPORT_FILE"
    print_info "可在浏览器中打开查看"
}

# ============================================================
# 13. 清理功能
# ============================================================
cleanup() {
    print_title "🧹 清理"
    
    # 清理临时文件
    rm -f /tmp/lxbench_* 2>/dev/null || true
    rm -f /tmp/lxbench_fio_test 2>/dev/null || true
    
    print_ok "临时文件已清理"
    print_info "报告保存在: $REPORT_DIR"
}

# ============================================================
# 14. 主函数
# ============================================================
main() {
    clear
    print_banner
    
    print_info "开始全面测评，预计耗时 5-15 分钟..."
    print_info "请耐心等待..."
    echo ""
    
    # 创建报告目录
    mkdir -p "$REPORT_DIR"
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 安装依赖
    install_deps
    
    # 执行各项测试
    detect_location
    collect_system_info
    test_cpu
    test_memory
    test_disk
    test_network
    test_streaming
    test_ip_quality
    calculate_score
    generate_html_report
    cleanup
    
    # 计算耗时
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo ""
    print_title "✅ 测评完成"
    echo -e "${BOLD}总耗时${PLAIN}: ${CYAN}${minutes}分${seconds}秒${PLAIN}"
    echo -e "${BOLD}综合得分${PLAIN}: ${CYAN}${SCORE_TOTAL}/100${PLAIN}"
    echo -e "${BOLD}HTML报告${PLAIN}: ${CYAN}${REPORT_FILE}${PLAIN}"
    echo -e "${BOLD}日志文件${PLAIN}: ${CYAN}${LOG_FILE}${PLAIN}"
    echo ""
    print_ok "感谢使用 LXBench！"
}

# ============================================================
# 脚本入口
# ============================================================
main "$@"
