#!/usr/bin/env bash
#
# LXBench 一键安装脚本
# GitHub: https://github.com/gzy318/LXBench
#

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
PLAIN='\033[0m'

echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║                                                       ║"
echo "  ║              LXBench 一键安装脚本                    ║"
echo "  ║           https://github.com/gzy318/LXBench          ║"
echo "  ║                                                       ║"
echo "  ╚═══════════════════════════════════════════════════════╝"
echo -e "${PLAIN}"

echo ""
echo -e "${BOLD}选择操作:${PLAIN}"
echo "  1) 直接运行 LXBench（下载并执行）"
echo "  2) 下载 LXBench 到当前目录"
echo "  3) 安装 LXBench 到 /usr/local/bin（全局可用）"
echo "  4) 退出"
echo ""
read -p "请输入选项 [1-4]: " choice

case $choice in
    1)
        echo -e "${GREEN}正在运行 LXBench...${PLAIN}"
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/gzy318/LXBench/main/lxbench.sh)"
        ;;
    2)
        echo -e "${GREEN}正在下载 LXBench...${PLAIN}"
        curl -fsSL -o lxbench.sh https://raw.githubusercontent.com/gzy318/LXBench/main/lxbench.sh
        chmod +x lxbench.sh
        echo -e "${GREEN}下载完成！运行 ./lxbench.sh 开始测试${PLAIN}"
        ;;
    3)
        echo -e "${GREEN}正在安装 LXBench 到系统...${PLAIN}"
        sudo curl -fsSL -o /usr/local/bin/lxbench https://raw.githubusercontent.com/gzy318/LXBench/main/lxbench.sh
        sudo chmod +x /usr/local/bin/lxbench
        echo -e "${GREEN}安装完成！输入 lxbench 即可运行${PLAIN}"
        ;;
    *)
        echo "已退出"
        exit 0
        ;;
esac
