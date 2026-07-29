#!/usr/bin/env bash
#
# LXBench 一键安装脚本
# GitHub: https://github.com/gzy318/LXBench
# 版本: 2.1.0
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
PLAIN='\033[0m'

SCRIPT_URL="https://raw.githubusercontent.com/gzy318/LXBench/main/lxbench.sh"
GITHUB_URL="https://github.com/gzy318/LXBench"
RAINYUN_URL="https://www.rainyun.com/xls_"
BLOG_URL="https://twbk.cn"

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
    echo "  ║              LXBench 一键安装脚本                            ║"
    echo "  ║                        v2.1.0                                ║"
    echo "  ║                                                               ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${PLAIN}"
    echo -e "${CYAN}📦 ${GITHUB_URL}${PLAIN}"
    echo -e "${CYAN}🚀 ${RAINYUN_URL}${PLAIN}"
    echo -e "${CYAN}📝 ${BLOG_URL}${PLAIN}"
    echo ""
}

download_file() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    else
        echo -e "${RED}错误: 未找到 curl 或 wget${PLAIN}"
        exit 1
    fi
}

check_update() {
    local remote=$(curl -fsSL "$SCRIPT_URL" 2>/dev/null | grep -o 'VERSION="[0-9.]*"' | head -1 | cut -d'"' -f2)
    local local="2.0.0"
    if [ -n "$remote" ] && [ "$remote" != "$local" ]; then
        echo -e "${YELLOW}⚠️ 发现新版本 ${remote} (当前 ${local})${PLAIN}"
    else
        echo -e "${GREEN}✅ 已是最新版本${PLAIN}"
    fi
    echo ""
}

run_lxbench() {
    echo -e "${GREEN}正在下载并运行 LXBench...${PLAIN}"
    bash -c "$(curl -fsSL ${SCRIPT_URL})"
}

download_lxbench() {
    echo -e "${GREEN}正在下载 LXBench...${PLAIN}"
    download_file "$SCRIPT_URL" "lxbench.sh"
    chmod +x lxbench.sh
    echo -e "${GREEN}✅ 下载完成！运行 ./lxbench.sh${PLAIN}"
}

install_global() {
    echo -e "${GREEN}正在安装到 /usr/local/bin...${PLAIN}"
    if [ "$EUID" -ne 0 ]; then
        sudo bash -c "curl -fsSL -o /usr/local/bin/lxbench ${SCRIPT_URL} && chmod +x /usr/local/bin/lxbench"
    else
        curl -fsSL -o /usr/local/bin/lxbench "$SCRIPT_URL"
        chmod +x /usr/local/bin/lxbench
    fi
    echo -e "${GREEN}✅ 安装完成！输入 lxbench 运行${PLAIN}"
}

show_help() {
    echo ""
    echo "LXBench 是一款全能VPS测评脚本"
    echo ""
    echo "测试内容：系统信息 / CPU诚信度检测 / Geekbench+UnixBench /"
    echo "         内存 / 磁盘I/O / 国内三网延迟 / 国际延迟 /"
    echo "         海外→国内回程 / 五网路由 / 去程路由 /"
    echo "         流媒体解锁(15+) / IP质量 / DNS泄露 / IPv6"
    echo ""
    echo "输出：HTML报告 + Markdown报告 + 日志"
    echo ""
    echo "GitHub: https://github.com/gzy318/LXBench"
    echo ""
    read -p "按 Enter 返回..."
}

exit_install() {
    echo -e "${GREEN}已退出${PLAIN}"
    exit 0
}

show_menu() {
    echo -e "${BOLD}请选择操作:${PLAIN}"
    echo "  1) 直接运行 LXBench"
    echo "  2) 下载到当前目录"
    echo "  3) 全局安装到 /usr/local/bin"
    echo "  4) 查看帮助"
    echo "  5) 退出"
    echo ""
    read -p "请输入选项 [1-5]: " choice
    case "$choice" in
        1) run_lxbench ;;
        2) download_lxbench ;;
        3) install_global ;;
        4) show_help; show_menu ;;
        5) exit_install ;;
        *) echo -e "${RED}无效选项${PLAIN}"; show_menu ;;
    esac
}

main() {
    clear
    print_banner
    check_update
    show_menu
}

main "$@"
