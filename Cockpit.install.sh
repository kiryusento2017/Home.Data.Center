#!/usr/bin/env bash
#Cockpit.install.sh
clear
##############################
# 颜色定义
##############################
readonly BLACK='\033[30m'
readonly RED='\033[31m'
readonly GREEN='\033[32m'
readonly YELLOW='\033[33m'
readonly BLUE='\033[34m'
readonly MAGENTA='\033[35m'
readonly CYAN='\033[36m'
readonly WHITE='\033[37m'
readonly RESET='\033[0m'


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
# 确保以 root 运行
##############################
if [[ $EUID -ne 0 ]]; then
   echo "→ 检测到非 root，自动提权再执行脚本..."
   exec sudo bash "$0" "$@"
fi

##############################
# 步骤函数
##############################
step_1_prepare() {
  echo -e "${YELLOW}工作区已创建${RESET}"
  mkdir -p "$WORK_DIR" "$CACHE_DIR"
  cd "$WORK_DIR"
}

step_2_mirror() {
  echo -e "==> ${YELLOW}② 换国内源${RESET}"
  download "$MIRROR_MAIN" main.sh
  bash main.sh
}

step_3_docker() {
  echo -e "==> ${YELLOW}③ 换 Docker 源并安装 Docker${RESET}"
  download "$MIRROR_DOCKER" docker.sh
  bash docker.sh
}

step_4_speeder() {
  echo -e "==> ${YELLOW}④ 执行 docker.speeder.sh${RESET}"
  download "$SPEEDER" docker.speeder.sh
  chmod +x docker.speeder.sh && ./docker.speeder.sh
}


step_6_cockpit() {
  echo -e "==> ${YELLOW}⑤ 更新软件列表${RESET}"
  apt update
  echo -e "==> ${YELLOW}⑥ 安装 cockpit 主程序（backports）${RESET}"
  # shellcheck source=/dev/null
  . /etc/os-release
  apt_install "-t ${VERSION_CODENAME}-backports cockpit"
}

step_7_disallowed() {
  echo -e "==> ${YELLOW}⑦ 清空 disallowed-users${RESET}"
  mv -f /etc/cockpit/disallowed-users /etc/cockpit/disallowed-users.bak 2>/dev/null || true
  touch /etc/cockpit/disallowed-users
}

step_8_plugins() {
  echo -e "==> ${YELLOW}⑧ 安装 cockpit 官方插件${RESET}"
  for plugin in storaged networkmanager packagekit sosreport machines; do
    apt_install "cockpit-$plugin"
  done
}

step_9_thirdparty() {
  echo -e "==> ${YELLOW}⑨ 安装第三方 cockpit 插件${RESET}"
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
}

step_10_enable() {
  echo -e "==> ${YELLOW}⑩ 启用并启动 cockpit${RESET}"
  systemctl enable --now cockpit.socket
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
}

step_11_grant() {
  read -rp "是否为指定账号提权（追加 sudo、docker 组）？[y/N] " CONFIRM
  [[ "$CONFIRM" =~ [Yy] ]] || { echo "已取消提权操作。"; return; }
  read -rp "请输入用于登录 Cockpit 系统的账号: " USER_NAME
  if ! id "$USER_NAME" &>/dev/null; then
    echo -e "${CYAN}错误：用户 $USER_NAME 不存在！${RESET}"
    return 0
  fi
  echo -e "${YELLOW}升级中，正在为 $USER_NAME 追加所需权限 ……${RESET}"
  usermod -aG sudo "$USER_NAME"
  usermod -aG docker "$USER_NAME"
  systemctl restart cockpit.socket
  echo -e "${BLUE}$USER_NAME 提权已完成。${RESET}"
}

# 一键执行全部
step_all() {
  step_1_prepare
  step_2_mirror
  step_3_docker && step_4_speeder
  step_6_cockpit && step_7_disallowed
  step_8_plugins
  step_9_thirdparty
  step_10_enable
  step_11_grant
}

##############################
# ①⑤ 必须步骤 —— 自动顺序执行
##############################
step_1_prepare

##############################
# 精简交互菜单
##############################
while true; do
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
          一键 部署Cockpit v2.0  ${RED}请以root用户执行脚本${RESET}
${GREEN}================================================================${RESET}"
  echo " A) 一键完整安装（推荐）"
  echo " 1) ② 换国内源（https://linuxmirrors.cn脚本）"
  echo " 2) ③ 安装 Docker（https://linuxmirrors.cn脚本） + ④ 执行自定义换源"
  echo " 3) ⑥ 安装 cockpit + ⑦ 去除root账号登录限制"
  echo " 4) ⑧ 安装官方插件"
  echo " 5) ⑨ 安装第三方插件"
  echo " 6) ⑩ 启用并启动 cockpit"
  echo " G) ⑪ 给用户提权(需要输入用户名)"
  echo " X) 退出"
  echo "=========================================="
  read -rp "请选择操作 [A,1-6,G,X]: " CHOICE
  CHOICE=$(echo "$CHOICE" | tr '[:lower:]' '[:upper:]')
  case $CHOICE in
    A) step_all ;;
    1) step_2_mirror ;;
    2) step_3_docker && step_4_speeder ;;
    3) step_6_cockpit && step_7_disallowed ;;
    4) step_8_plugins ;;
    5) step_9_thirdparty ;;
    6) step_10_enable ;;
    G) step_11_grant ;;
    X) echo "Bye~"; exit 0 ;;
    *) echo "输入无效，请重试" ;;
  esac
  echo
  read -rp "按 Enter 返回主菜单..."
  clear
done


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
