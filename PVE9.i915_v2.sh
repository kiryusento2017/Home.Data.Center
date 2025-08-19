#!/bin/bash
clear
echo -e "
    _    _             _                _    _                   _          _               
   | |  (_)           (_)              | |  / )                 | |        | |              
    \ \  _ ____  ____  _ ____   ____   | | / / ____   ___  _ _ _| | ____ _ | | ____  ____   
     \ \| |  _ \|  _ \| |  _ \ / _  |  | |< < |  _ \ / _ \| | | | |/ _  ) || |/ _  |/ _  )  
 _____) ) | | | | | | | | | | ( ( | |  | | \ \| | | | |_| | | | | ( (/ ( (_| ( ( | ( (/ /   
(______/|_| ||_/| ||_/|_|_| |_|\_|| |  |_|  \_)_| |_|\___/ \____|_|\____)____|\_|| |\____)  
          |_|   |_|           (_____|                                        (_____|        
       _      _        ______  _             _                                              
      (_)_   | |      (____  \| |           | |    _                                        
 _ _ _ _| |_ | | _     ____)  ) | ____  ____| |  _| |_  ____ ____                           
| | | | |  _)| || \   |  __  (| |/ _  |/ ___) | / )  _)/ _  ) _  |                          
| | | | | |__| | | |  | |__)  ) ( ( | ( (___| |< (| |_( (/ ( ( | |                          
 \____|_|\___)_| |_|  |______/|_|\_||_|\____)_| \_)\___)____)_||_|                          
                                                                                            
================================================================
一键 Proxmox 9.0 Kernel降级 [6.8.12-13] 安装i915驱动 v2.1
================================================================
"  
#!/bin/bash

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

# 询问用户输入GPU的拆分数量
echo "请输入GPU的拆分数量（0-7）："
read sriov_numvfs
echo " "

# 检查输入是否合法
if ! [[ $sriov_numvfs =~ ^[0-7]$ ]]; then
    echo "输入无效，请输入0到7之间的数字。"
    exit 1
fi
echo " "
# 创建目录
mkdir -p /home/i915.dkms.driver
cd /home/i915.dkms.driver

# 安装必要的软件包
apt update
apt install build-essential dkms -y
apt install sysfsutils -y

# 定义下载函数并校验
download_file() {
    local url=$1
    local filename=$(basename "$url")
    wget -O "$filename" "$url"
    if [ $? -ne 0 ]; then
        echo "下载文件失败: $url"
        echo "这可能是由于网络问题或链接无效导致的。请检查链接的合法性或稍后重试。"
        exit 1
    else
        echo "成功下载文件: $filename"
    fi
}

# 下载必要的文件
download_file http://mirrors.nju.edu.cn/proxmox/debian/dists/bookworm/pve-no-subscription/binary-amd64/proxmox-headers-6.8.12-13-pve_6.8.12-13_amd64.deb
download_file http://mirrors.nju.edu.cn/proxmox/debian/dists/bookworm/pve-no-subscription/binary-amd64/proxmox-kernel-6.8.12-13-pve-signed_6.8.12-13_amd64.deb
download_file https://github.com/strongtz/i915-sriov-dkms/releases/download/2025.07.22/i915-sriov-dkms_2025.07.22_amd64.deb

# 安装下载的文件
dpkg -i *.deb

# 列出当前的内核版本
ls /boot/vmlinuz-*

# 设置当前内核版本为6.8.12-13-pve
proxmox-boot-tool kernel pin 6.8.12-13-pve
proxmox-boot-tool refresh

# 修改GRUB配置
sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on i915.enable_guc=3 i915.max_vfs=7 module_blacklist=xe quiet"/' /etc/default/grub

# 更新GRUB和initramfs
update-grub
update-initramfs -u

# 设置SR-IOV数量
echo "devices/pci0000:00/0000:00:02.0/sriov_numvfs = $sriov_numvfs" > /etc/sysfs.conf
echo "已将sriov_numvfs设置为$sriov_numvfs。"

# 提示更新完成并询问是否需要重启
echo "更新已完成。"
echo "为了使更改生效，需要重启系统。"
read -p "是否现在重启系统？(y/n): " choice
case "$choice" in 
  y|Y ) echo "正在重启系统..."; sudo reboot;;
  n|N ) echo "请在方便时手动重启系统。";;
  * ) echo "无效输入，脚本结束。";;
esac

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

