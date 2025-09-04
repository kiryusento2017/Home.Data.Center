#!/bin/bash
clear
# 定义颜色代码
readonly BLACK='\033[30m'
readonly RED='\033[31m'
readonly GREEN='\033[32m'
readonly YELLOW='\033[33m'
readonly BLUE='\033[34m'
readonly MAGENTA='\033[35m'
readonly CYAN='\033[36m'
readonly WHITE='\033[37m'
readonly RESET='\033[0m'

echo -e "
${WHITE}    _    _             _                _    _                   _          _               
${RED}   | |  (_)           (_)              | |  / )                 | |        | |              
${CYAN}    \ \  _ ____  ____  _ ____   ____   | | / / ____   ___  _ _ _| | ____ _ | | ____  ____   
${YELLOW}     \ \| |  _ \|  _ \| |  _ \ / _  |  | |< < |  _ \ / _ \| | | | |/ _  ) || |/ _  |/ _  )  
${GREEN} _____) ) | | | | | | | | | | ( ( | |  | | \ \| | | | |_| | | | | ( (/ ( (_| ( ( | ( (/ /   
${BLUE}(______/|_| ||_/| ||_/|_|_| |_|\_|| |  |_|  \_)_| |_|\___/ \____|_|\____)____|\_|| |\____)  
${MAGENTA}          |_|   |_|           (_____|                                        (_____|        
${BLUE}       _      _        ______  _             _                                              
${GREEN}      (_)_   | |      (____  \| |           | |    _                                        
${YELLOW} _ _ _ _| |_ | | _     ____)  ) | ____  ____| |  _| |_  ____ ____                           
${CYAN}| | | | |  _)| || \   |  __  (| |/ _  |/ ___) | / )  _)/ _  ) _  |                          
${RED}| | | | | |__| | | |  | |__)  ) ( ( | ( (___| |< (| |_( (/ ( ( | |                          
${WHITE} \____|_|\___)_| |_|  |______/|_|\_||_|\____)_| \_)\___)____)_||_|                          
                                                                                            
${GREEN}================================================================${RESET}
        一键 Proxmox Kernel [6.8.12-13] 更新  v1.3
${GREEN}================================================================${RESET}

"  

# 提醒用户检查BIOS的Secure Boot功能
echo "在继续之前，请确保您已经关闭了BIOS的Secure Boot功能。"
echo "请先备份好你的重要数据。"
echo "如果您不确定如何操作，请阅读您的硬件文档或技术支持。"
echo "按Shift + Y继续，按任意其他键退出脚本。"
echo " "
read -n 1 -s key

# 检查用户输入
if [[ $key != "Y" ]]; then
    echo "脚本已退出。"
    exit 0
fi
# 定义带有动画效果的进度条函数
show_progress() {
  local duration=$1
  local progress=0
  local width=50
  local fill_char="#"
  local empty_char="-"
  local spinner_chars="/-\|"
  local spinner_index=0

  while [ $progress -le 100 ]; do
    local filled=$((width * progress / 100))
    local empty=$((width - filled))
    local spinner_char=${spinner_chars:$spinner_index:1}
    spinner_index=$((spinner_index + 1))
    if [ $spinner_index -ge ${#spinner_chars} ]; then
      spinner_index=0
    fi

    # 动态显示进度条和旋转指针
    printf "\r[%-${width}s] %3d%% %c" "$(printf "%-${filled}s" | tr ' ' "$fill_char")$(printf "%-${empty}s" | tr ' ' "$empty_char")" $progress $spinner_char
    sleep 0.1
    progress=$((progress + 1))
  done
  echo
}


# 创建目录 /home/Kernel 并切换到该目录
echo "创建目录 /home/Kernel 并切换到该目录..."
mkdir -p /home/Kernel
cd /home/Kernel

# 下载 Proxmox VE 的内核和头文件
echo "开始下载Kernel文件..."
show_progress 10
wget -q http://mirrors.nju.edu.cn/proxmox/debian/dists/bookworm/pve-no-subscription/binary-amd64/proxmox-headers-6.8.12-13-pve_6.8.12-13_amd64.deb
wget -q http://mirrors.nju.edu.cn/proxmox/debian/dists/bookworm/pve-no-subscription/binary-amd64/proxmox-kernel-6.8.12-13-pve-signed_6.8.12-13_amd64.deb
echo "文件下载完成。"

# 安装下载的 .deb 文件
echo "开始安装下载的 Kernel 6.8.12-13..."
show_progress 10
dpkg -i *.deb
echo "安装完成。"

# 使用 proxmox-boot-tool 设置默认内核版本
echo "设置默认内核版本为 6.8.12-13..."
show_progress 5
proxmox-boot-tool kernel pin 6.8.12-13-pve
echo "设置完成。"

# 刷新 proxmox-boot-tool 的配置
echo "刷新 proxmox-boot-tool 的配置..."
show_progress 5
proxmox-boot-tool refresh
echo "刷新完成。"

# 更新 grub 配置
echo "更新 grub 配置..."
show_progress 5
update-grub
echo "更新完成。"

echo "所有操作已完成。"
echo "请确认Grub配置后重启。"


# MIT License
#
# Copyright (c) [2025] [Blacktea]
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
