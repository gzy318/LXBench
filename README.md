# LXBench — 全能VPS服务器测评脚本


## 📖 简介

LXBench 是一款全功能VPS服务器性能测评脚本，集成了系统检测、CPU诚信度检测、Geekbench+UnixBench双跑分、内存/磁盘I/O、智能双模网络测试、五网回程路由、流媒体解锁检测、IP质量检测、DNS泄露检测、IPv6检测等全方位功能。

**GitHub**：[https://github.com/gzy318/LXBench](https://github.com/gzy318/LXBench)

* * *


## 📦 安装方式

### 方式一：一键安装脚本（推荐）

```bash

bash -c "$(curl -fsSL https://raw.githubusercontent.com/gzy318/LXBench/main/install.sh)"
```

### 方式二：直接运行

```bash

bash -c "$(curl -fsSL https://raw.githubusercontent.com/gzy318/LXBench/main/lxbench.sh)"
```

### 方式三：下载后运行

```bash

curl -fsSL -o lxbench.sh https://raw.githubusercontent.com/gzy318/LXBench/main/lxbench.sh
chmod +x lxbench.sh
./lxbench.sh
```

### 方式四：全局安装

```bash

sudo curl -fsSL -o /usr/local/bin/lxbench https://raw.githubusercontent.com/gzy318/LXBench/main/lxbench.sh
sudo chmod +x /usr/local/bin/lxbench
lxbench
```

* * *

## 📊 测试功能

| 模块 | 说明 |
| --- | --- |
| 系统信息 | CPU/内存/磁盘/虚拟化/BBR状态 |
| CPU诚信度检测 | Steal Time + Kernel Latency（超卖检测） |
| CPU性能 | sysbench + Geekbench 5 + UnixBench |
| 内存性能 | 读写速度 + 延迟测试 |
| 磁盘I/O | 顺序读写 + 4K随机读写 + ioping延迟 |
| 国内三网延迟 | 15节点（电信/联通/移动） |
| 国际延迟 | 15节点（五大洲） |
| 海外→国内回程 | 海外服务器到中国主要城市延迟 |
| 五网回程路由 | 电信/联通/移动/教育网/科技网 |
| 去程路由检测 | 从国内节点到服务器的路由 |
| 三网测速 | 每个运营商选最优节点 |
| 流媒体解锁 | 15+平台（Netflix/YouTube/Disney+/B站/HBO/TikTok/PrimeVideo等） |
| IP质量检测 | 归属地/运营商/ASN/IP类型 |
| DNS泄露检测 | 检测DNS是否泄露 |
| IPv6检测 | IPv6连通性+延迟 |
| 综合评分 | 0-100分量化评分 + 评级 |
| HTML报告 | 可视化报告 |
| Markdown报告 | 方便论坛发帖 |
| 交互模式 | 可选择测试项目 |

* * *

## 🎯 交互模式

运行后出现菜单：


请选择测试模式:
  1) 完整测试 (全部项目，约15-20分钟)
  2) 快速测试 (跳过Geekbench/UnixBench，约5-8分钟)
  3) 仅网络测试 (延迟+路由+测速)
  4) 仅性能测试 (CPU+内存+磁盘)
  5) 仅流媒体+IP质量
  6) 直接运行 (默认完整测试)

* * *

## 📁 输出文件

测试完成后生成在 `./lxbench_reports/` 目录：

| 文件 | 说明 |
| --- | --- |
| `lxbench_*.html` | HTML可视化报告 |
| `lxbench_*.md` | Markdown格式报告 |
| `lxbench_*.log` | 完整测试日志 |

* * *

## 🔗 相关链接

*   📦 GitHub：[https://github.com/gzy318/LXBench](https://github.com/gzy318/LXBench)
    
*   🚀 服务器推荐：[雨云高性价比服务器](https://www.rainyun.com/xls_)
    
*   📝 个人博客：[叹惋博客](https://twbk.cn/)
    

* * *

## 🙏 致谢

本脚本参考了以下开源项目：

| 项目 | 参考内容 |
| --- | --- |
| [NodeLoc](https://github.com/NodeLoc/NodeLoc) | 聚合测试脚本设计思路 |
| [融合怪](https://github.com/spiritLHLS/ecs) | 一键测评架构 |
| [LemonBench](https://github.com/LemonBench/LemonBench) | 流媒体解锁检测 |
| [YABS](https://github.com/masonr/yet-another-bench-script) | Geekbench测试集成 |
| [MatrixBench](https://github.com/gebu8f8/MatrixBench) | CPU诚信度/超卖检测 |
| [SuperBench](https://github.com/oooldking/script) | 三网回程路由 |
| [NodeQuality](https://github.com/LloydAsp/NodeQuality) | HTML报告生成 |
| [bench.sh](https://bench.sh/) | 系统信息采集 |
| [秋水逸冰 UnixBench](https://github.com/teddysun/across) | UnixBench集成 |

感谢以上开源项目的作者们！

* * *

## 📄 许可证

MIT License
