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
一键更新 Proxmox 9.0（原地备份版） v1.1
================================================================
"     
                                                                                        
# ================================================================
# 一键修改 Debian / Proxmox 的 apt 源（原地备份版）
# ================================================================
set -euo pipefail

# 定义可选的源地址
declare -A SOURCES=(
    ["1"]="阿里云:mirrors.aliyun.com"
    ["2"]="腾讯云:mirrors.tencent.com"
    ["3"]="华为云:repo.huaweicloud.com"
    ["4"]="网易:mirrors.163.com"
    ["5"]="火山引擎:mirrors.volces.com"
    ["6"]="清华大学:mirrors.tuna.tsinghua.edu.cn"
    ["7"]="北京大学:mirrors.pku.edu.cn"
    ["8"]="浙江大学:mirrors.zju.edu.cn"
    ["9"]="南京大学:mirrors.nju.edu.cn"
    ["a"]="兰州大学:mirror.lzu.edu.cn"
    ["b"]="上海交通大学:mirror.sjtu.edu.cn"
    ["c"]="重庆邮电大学:mirrors.cqupt.edu.cn"
    ["d"]="中国科学技术大学:mirrors.ustc.edu.cn"
    ["e"]="中国科学院软件研究所:mirror.iscas.ac.cn"
    ["x"]="退出"
)

# 打印可选的源地址
echo "请选择源地址："
# 对键值进行排序后打印
for key in $(echo "${!SOURCES[@]}" | tr ' ' '\n' | sort); do
    echo "$key. ${SOURCES[$key]}"
done

# 读取用户输入
read -p "请输入编号（1-9 或 a-e，输入 x 退出）： " choice

# 检查用户输入是否有效
if [[ "$choice" == "x" ]]; then
    echo "👋 已退出脚本。"
    exit 0
elif [[ -z "${SOURCES[$choice]}" ]]; then
    echo "❌ 无效的编号，请重新运行脚本并输入正确的编号（1-9 或 a-e，输入 x 退出）！"
    exit 1
fi

# 提取域名
DOMAIN=$(echo "${SOURCES[$choice]}" | cut -d':' -f2)

# 定义其他变量
TS="$(date +%s)"                           # 秒级时间戳，保证唯一
SOURCES_LIST="/etc/apt/sources.list"
SOURCES_D="/etc/apt/sources.list.d"
BACKUP_DIR1="/etc/apt/bak"    # /etc/apt 下的 bak 子目录
BACKUP_DIR2="/etc/apt/sources.list.d/bak"  # /etc/apt/sources.list.d 下的 bak 子目录

# 创建备份目录，如果不存在则创建
if [ ! -d "$BACKUP_DIR1" ]; then
    mkdir -p "$BACKUP_DIR1"
else
    echo "目录 $BACKUP_DIR1 已存在，跳过创建。"
fi

if [ ! -d "$BACKUP_DIR2" ]; then
    mkdir -p "$BACKUP_DIR2"
else
    echo "目录 $BACKUP_DIR2 已存在，跳过创建。"
fi


# -------------- 1. 备份原 sources.list --------------
if [[ -f "$SOURCES_LIST" ]]; then
    cp "$SOURCES_LIST" "$BACKUP_DIR1/sources.list.bak-$TS"
fi

# -------------- 2. 写入新的 sources.list --------------
cat > "$SOURCES_LIST" <<EOF
## 默认禁用源码镜像以提高速度，如需启用请自行取消注释
deb http://$DOMAIN/debian trixie main contrib non-free non-free-firmware
deb http://$DOMAIN/debian trixie-updates main contrib non-free non-free-firmware
deb http://$DOMAIN/debian trixie-backports main contrib non-free non-free-firmware
deb http://$DOMAIN/debian-security trixie-security main contrib non-free non-free-firmware
EOF

# -------------- 3. 生成 ceph.sources --------------
cat > "$SOURCES_D/ceph.sources" <<EOF
Types: deb
URIs: https://enterprise.proxmox.com/debian/ceph-squid
Suites: trixie
Components: enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: false
EOF

# -------------- 4. 生成 pve-enterprise.sources --------------
cat > "$SOURCES_D/pve-enterprise.sources" <<EOF
Types: deb
URIs: https://enterprise.proxmox.com/debian/pve
Suites: trixie
Components: pve-enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: false
EOF

# -------------- 5. 生成 pve-no-subscription.list --------------
cat > "$SOURCES_D/pve-no-subscription.list" <<EOF
deb http://$DOMAIN/proxmox/debian/pve trixie pve-no-subscription
EOF

# -------------- 6. 原地备份旧的 ceph.list / pve-enterprise.list --------------
for f in "$SOURCES_D"/ceph.list "$SOURCES_D"/pve-enterprise.list; do
    if [[ -f "$f" ]]; then
        cp "$f" "$BACKUP_DIR2/$(basename "$f").bak-$TS"
    fi
done

# -------------- 7. 提示 --------------
echo "✅ 所有源文件已更新完毕！"
echo "📦 旧文件已备份到 $BACKUP_DIR1 和 $BACKUP_DIR2 目录中，文件名为 *.bak-$TS"

# 是否立即更新源？
read -p "是否现在更新源？(Y/n) : " update_choice
update_choice=${update_choice:-y}  # 如果用户直接按下回车，默认为 y

if [[ "$update_choice" == "y" || "$update_choice" == "Y" ]]; then
    echo "正在更新源..."
    apt update
    echo "✅ 源已更新完成！"
else
    echo "ℹ️  源未更新。您可以稍后手动运行 'apt update'。"
fi


# 是否立即升级系统？
read -p "是否现在升级系统？(y/N) : " upgrade_choice
upgrade_choice=${upgrade_choice:-n}  # 如果用户直接按下回车，默认为 n

if [[ "$upgrade_choice" == "y" || "$upgrade_choice" == "Y" ]]; then
    echo "正在升级系统..."
    apt upgrade -y
    echo "✅ 系统已升级完成！"
else
    echo "ℹ️  系统未升级。您可以稍后手动运行 'apt upgrade'。"
fi

# MIT License
#
# Copyright (c) [2025] [GoGoBlacktea]
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
