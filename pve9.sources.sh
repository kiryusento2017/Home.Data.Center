#!/bin/bash
# ================================================================
#  一键修改 Debian / Proxmox 的 apt 源（原地备份版）
# ================================================================
set -euo pipefail

TS="$(date +%s)"                           # 秒级时间戳，保证唯一
SOURCES_LIST="/etc/apt/sources.list"
SOURCES_D="/etc/apt/sources.list.d"

# -------------- 1. 备份原 sources.list --------------
[[ -f "$SOURCES_LIST" ]] && \
    cp "$SOURCES_LIST" "$SOURCES_LIST.bak-$TS"

# -------------- 2. 写入新的 sources.list --------------
cat > "$SOURCES_LIST" <<'EOF'
## 默认禁用源码镜像以提高速度，如需启用请自行取消注释
deb http://mirrors.nju.edu.cn/debian trixie main contrib non-free non-free-firmware
deb http://mirrors.nju.edu.cn/debian trixie-updates main contrib non-free non-free-firmware
deb http://mirrors.nju.edu.cn/debian trixie-backports main contrib non-free non-free-firmware
deb http://mirrors.nju.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
EOF

# -------------- 3. 生成 ceph.sources --------------
cat > "$SOURCES_D/ceph.sources" <<'EOF'
Types: deb
URIs: https://enterprise.proxmox.com/debian/ceph-squid
Suites: trixie
Components: enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: false
EOF

# -------------- 4. 生成 pve-enterprise.sources --------------
cat > "$SOURCES_D/pve-enterprise.sources" <<'EOF'
Types: deb
URIs: https://enterprise.proxmox.com/debian/pve
Suites: trixie
Components: pve-enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: false
EOF

# -------------- 5. 生成 pve-no-subscription.list --------------
cat > "$SOURCES_D/pve-no-subscription.list" <<'EOF'
deb http://mirrors.nju.edu.cn/proxmox/debian/pve trixie pve-no-subscription
EOF

# -------------- 6. 原地备份旧的 ceph.list / pve-enterprise.list --------------
for f in "$SOURCES_D"/ceph.list "$SOURCES_D"/pve-enterprise.list; do
    [[ -f "$f" ]] && cp "$f" "$f.bak-$TS"
done

# -------------- 7. 提示 --------------
echo "✅ 所有源文件已更新完毕！"
echo "📦 旧文件已在原目录备份为 *.bak-$TS"
echo "ℹ️  现在可以执行：sudo apt update"
