#!/usr/bin/env bash
# 记工备份异地容灾：每天把 SQLite 数据库推送到腾讯云 COS（保留 5 天）。
# 复用 ~/.cos.conf 的 coscmd 配置。
set -euo pipefail

SRC="/vol1/fbc299/jianyi-jigong-server/backups.db"
TS="$(date +%Y%m%d_%H%M)"
TMP="/tmp/jigong-cos-${TS}.db"
COS_PREFIX="jigong-backup/"
BUCKET_URI="cos://fbc299-1258301468"

# 在线安全拷一份（WAL 一致）
python3 - "$SRC" "$TMP" <<'PY'
import sqlite3, sys
src = sqlite3.connect(sys.argv[1])
dst = sqlite3.connect(sys.argv[2])
with dst:
    src.backup(dst)
dst.close(); src.close()
PY

# 推到 COS（coscmd 用全路径，cron 环境无 .local/bin；upload 第2参=桶内对象key，非 cos:// URI）
/home/fbc299/.local/bin/coscmd upload "$TMP" "${COS_PREFIX}backups-${TS}.db" -y >/dev/null
echo "已上传 ${BUCKET_URI}/${COS_PREFIX}backups-${TS}.db ($(du -h "$TMP" | cut -f1))"
rm -f "$TMP"

# 保留 5 天：删掉 5 天前 COS 里已有备份（list 输出第4列是日期 YYYY-MM-DD HH:MM:SS）
RETAIN_DAYS=5
CUTOFF="$(date -d "-${RETAIN_DAYS} days" +%Y-%m-%d)"
/home/fbc299/.local/bin/coscmd list "${COS_PREFIX}" 2>/dev/null | \
awk -v c="$CUTOFF" 'NF>=4 { d=substr($4,1,10); if (d < c) print $1 }' | \
while read -r key; do
  [ -n "$key" ] && /home/fbc299/.local/bin/coscmd delete "$key" -y -f >/dev/null 2>&1 && echo "已清理 $key"
done
