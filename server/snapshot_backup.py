#!/usr/bin/env python3
"""记工备份数据库 —— 每小时快照，保留 7 天（防误操作/数据损坏可回退）。
在线 SQLite backup API（WAL 安全，不锁主库）。
定时: 由 cron 每小时调用一次。"""
import os, time, sqlite3, glob, shutil
from pathlib import Path

DB = "/vol1/fbc299/jianyi-jigong-server/backups.db"
SNAP_DIR = Path("/vol1/fbc299/jianyi-jigong-backups-snapshots")
RETAIN_HOURS = 24 * 7   # 保留 7 天


def main():
    SNAP_DIR.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y%m%d-%H%M")
    snap = SNAP_DIR / f"backups-{ts}.db"
    src = sqlite3.connect(DB)
    dst = sqlite3.connect(str(snap))
    with dst:
        src.backup(dst)
    dst.close()
    src.close()
    # 清理超期快照
    cutoff = time.time() - RETAIN_HOURS * 3600
    for f in glob.glob(str(SNAP_DIR / "backups-*.db")):
        if os.path.getmtime(f) < cutoff:
            os.unlink(f)
    print(f"快照完成: {snap.name} ({os.path.getsize(snap)} B)")


if __name__ == "__main__":
    main()
