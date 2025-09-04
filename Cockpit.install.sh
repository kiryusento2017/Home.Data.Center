#!/usr/bin/env bash
#Cockpit.install.sh
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
一键 部署Cockpit v1.3  ${RED}请以root用户执行脚本${RESET}
${GREEN}================================================================${RESET}
"


set -euo pipefail
trap 'echo "❌ 错误发生在第 $LINENO 行，退出码：$?" >&2' ERR

##############################
# 可调整参数
##############################
RETRY=5
WAIT=3
WORK_DIR="/home/cockpit_install"
CACHE_DIR="${WORK_DIR}/cache"
MIRROR_MAIN="https://linuxmirrors.cn/main.sh"
MIRROR_DOCKER="https://linuxmirrors.cn/docker.sh"
SPEEDER="https://xget.xi-xu.me/gh/GoGoBlacktea/Home.Data.Center/raw/refs/heads/main/docker.speeder.sh"

##############################
# 确保以 root 运行
##############################
if [[ $EUID -ne 0 ]]; then
   echo "→ 检测到非 root，自动提权再执行脚本..."
   exec sudo bash "$0" "$@"
fi

##############################
# 工具函数：带重试的下载
##############################
download() {
  local url=$1 dst=$2
  for i in $(seq 1 $RETRY); do
    echo "⏬ 下载 $url （第 $i/$RETRY 次）..."
    if wget -q --show-progress -O "$dst" "$url"; then
      return 0
    fi
    rm -f "$dst"
    sleep $WAIT
  done
  echo "❌ 下载失败：$url" >&2
  return 1
}

##############################
# 工具函数：带重试的 apt
##############################
apt_install() {
  local pkg=$1
  for i in $(seq 1 $RETRY); do
    echo "📦 apt 安装 $pkg （第 $i/$RETRY 次）..."
    if apt install -y $pkg; then
      return 0
    fi
    sleep $WAIT
  done
  echo "❌ apt 安装失败：$pkg" >&2
  return 1
}

##############################
# 主流程
##############################
echo -e "==> ${YELLOW}1. 创建目录并进入工作区${RESET}"
mkdir -p "$WORK_DIR" "$CACHE_DIR"
cd "$WORK_DIR"

echo " "
echo -e "==> ${YELLOW}2. 换国内源${RESET}"
download "$MIRROR_MAIN" main.sh
bash main.sh

echo " "
echo -e "==> ${YELLOW}3. 换 Docker 源并安装 Docker${RESET}"
download "$MIRROR_DOCKER" docker.sh
bash docker.sh

echo " "
echo -e "==> ${YELLOW}4. 下载并执行 docker.speeder.sh${RESET}"
download "$SPEEDER" docker.speeder.sh
chmod +x docker.speeder.sh
./docker.speeder.sh

echo " "
echo -e "==> ${YELLOW}5. 更新软件列表${RESET}"
apt update

echo " "
echo -e "==> ${YELLOW}6. 安装 cockpit 主程序（backports）${RESET}"
. /etc/os-release
apt_install "-t ${VERSION_CODENAME}-backports cockpit"

echo " "
echo -e "==> ${YELLOW}7. 清空 disallowed-users${RESET}"
mv -f /etc/cockpit/disallowed-users /etc/cockpit/disallowed-users.bak
touch /etc/cockpit/disallowed-users

echo " "
echo -e "==> ${YELLOW}8. 安装 cockpit 插件${RESET}"
for plugin in storaged networkmanager packagekit sosreport machines; do
  apt_install "cockpit-$plugin"
done


echo " "
echo -e "==> ${YELLOW}9. 下载并安装第三方 cockpit 插件${RESET}"
download \
  "https://xget.xi-xu.me/gh/chrisjbawden/cockpit-dockermanager/releases/download/latest/dockermanager.deb" \
  "${CACHE_DIR}/dockermanager.deb"

download \
  "https://xget.xi-xu.me/gh/45Drives/cockpit-navigator/releases/download/v0.5.10/cockpit-navigator_0.5.10-1focal_all.deb" \
  "${CACHE_DIR}/cockpit-navigator.deb"

download \
  "https://xget.xi-xu.me/gh/45Drives/cockpit-file-sharing/releases/download/v4.3.1-2/cockpit-file-sharing_4.3.1-2focal_all.deb" \
  "${CACHE_DIR}/cockpit-file-sharing.deb"

apt install -y "${CACHE_DIR}"/*.deb

echo " "
echo -e "==> ${YELLOW} 启用 cockpit 并启动${RESET}"
systemctl enable --now cockpit.socket

#############################################
# 智能输出本机访问地址
#############################################
MY_IP=$(ip -4 route get 1 2>/dev/null | awk '{print $7;exit}')
if [[ -z "$MY_IP" || "$MY_IP" =~ ^127\. ]]; then
    ACCESS_URL="https://<本机IP>:9090"
else
    ACCESS_URL="https://${MY_IP}:9090"
fi

echo " 🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
echo "============================================="
echo -e "${GREEN}✅ Cockpit 安装完成！浏览器访问 ${ACCESS_URL}${RESET}"
echo "============================================="
echo " 🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"

read -rp "是否为指定账号提权（追加 sudo、docker 组）？[y/N] " CONFIRM
case "$CONFIRM" in
    [Yy]) ;;
    *)
        echo "已取消提权操作。"
        exit 0
        ;;
esac
# ---------- 输入账号 ----------
read -rp "请输入用于登录 Cockpit 系统的账号: " USER_NAME

# ---------- 判断账号是否存在 ----------
if ! id "$USER_NAME" &>/dev/null; then
    echo -e "${CYAN}错误：用户 $USER_NAME 不存在！${RESET}"
    echo -e "可以通过执行 usermod 命令手动赋权。"
    exit 1
fi
echo -e "${YELLOW}升级中，正在为 $USER_NAME 追加所需权限 ……${RESET}"
# ---------- 提权 ----------
sudo /usr/sbin/usermod -aG sudo "$USER_NAME"
sudo /usr/sbin/usermod -aG docker "$USER_NAME"
# ---------- 重启 cockpit ----------
sudo systemctl restart cockpit.socket

echo -e "${BLUE}$USER_NAME 提权已完成。${RESET}"


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
