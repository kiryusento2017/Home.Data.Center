#!/bin/bash

# 定义备份存储位置[根据实际情况修改]
_BACKUP_DIR="/mnt/pve/backup/SystemBackup/PVE-Config"
# 定义日志文件路径[根据实际情况修改]
_LOG_FILE="$_BACKUP_DIR/backup_log.txt"

# 创建备份目录
mkdir -p $_BACKUP_DIR

# 获取当前日期
_CURRENT_DATE=$(date +"%Y%m%d_%H%M%S")

# 创建带日期的备份目录
_BACKUP_DATE_DIR="$_BACKUP_DIR/backup_$_CURRENT_DATE"
mkdir -p $_BACKUP_DATE_DIR

# 备份配置文件
cp -r /etc/pve $_BACKUP_DATE_DIR
cp /etc/fstab $_BACKUP_DATE_DIR
cp /etc/hostname $_BACKUP_DATE_DIR
cp /etc/hosts $_BACKUP_DATE_DIR
# 备份集群配置
cp /var/lib/pve-cluster/config.db $_BACKUP_DATE_DIR

# 检查备份是否成功
if [ $? -eq 0 ]; then
    echo "[$(date)] Backup completed successfully." >> $_LOG_FILE
else
    echo "[$(date)] Backup failed." >> $_LOG_FILE
    exit 1
fi

# 删除旧备份，保留最近3个备份
cd $_BACKUP_DIR
# 列出所有备份目录并按日期排序
_BACKUP_LIST=($(ls -d backup_* | sort -r))
# 删除除最新的3个备份外的所有备份
for ((i=4; i<${#_BACKUP_LIST[@]}; i++)); do
    rm -rf "${_BACKUP_LIST[$i]}"
done

echo "[$(date)] Old backups cleaned up." >> $_LOG_FILE
echo "✅ PVE配置信息已完成备份！"


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
