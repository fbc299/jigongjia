#!/usr/bin/env python3
"""记工备份数据库 —— 定时快照（GFS 分层保留 + gzip 压缩）。

保留策略（按文件名时间戳，不依赖 mtime）：
  · 近 24 小时：每小时 1 份          → 最多 24 份
  · 1~7 天前 ：每天 1 份（当天最早） → 最多  6 份
  · 7~28 天前：每周 1 份（该周最早） → 最多  3 份
  · 更早     ：删除
合计约 33 份，gzip 后每份 ~20KB（DB 原始 ~500KB，JSON 文本压缩率 25:1）。

另：每周一首次运行前对主库做 VACUUM（回收 INSERT OR REPLACE / DELETE 造成的页碎片，
否则 backup() 会拷出数倍体积的空页）。

在线 SQLite backup API（WAL 安全，不锁主库）。cron 每小时调用一次。
"""
import glob
import gzip
import os
import re
import shutil
import sqlite3
import time
from datetime import datetime, timedelta
from pathlib import Path

DB = "/vol1/fbc299/jianyi-jigong-server/backups.db"
SNAP_DIR = Path("/vol1/fbc299/jianyi-jigong-backups-snapshots")
PAT = re.compile(r"backups-(\d{8})-(\d{4})\.db(\.gz)?$")


def vacuum_if_monday_first_run():
    """每周一做一次 VACUUM；靠标记文件保证一天一次。"""
    now = datetime.now()
    if now.weekday() != 0:
        return
    flag = SNAP_DIR / ".vacuum-done"
    tag = now.strftime("%Y%m%d")
    if flag.exists() and flag.read_text().strip() == tag:
        return
    try:
        conn = sqlite3.connect(DB, timeout=30)
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        conn.execute("VACUUM")
        conn.close()
        flag.write_text(tag)
        print(f"VACUUM 完成: {os.path.getsize(DB)} B")
    except Exception as e:  # VACUUM 失败不影响快照
        print(f"VACUUM 跳过: {e}")


def take_snapshot():
    ts = time.strftime("%Y%m%d-%H%M")
    tmp = SNAP_DIR / f".tmp-backups-{ts}.db"
    snap = SNAP_DIR / f"backups-{ts}.db.gz"
    src = sqlite3.connect(DB)
    dst = sqlite3.connect(str(tmp))
    with dst:
        src.backup(dst)
    dst.close()
    src.close()
    with open(tmp, "rb") as fi, gzip.open(snap, "wb", compresslevel=9) as fo:
        shutil.copyfileobj(fi, fo)
    os.unlink(tmp)
    return snap


def prune():
    """GFS 分层：<24h 全留；1~7 天每天留最早；7~28 天每周留最早；更早删除。"""
    now = datetime.now()
    entries = []
    for f in glob.glob(str(SNAP_DIR / "backups-*.db*")):
        m = PAT.search(os.path.basename(f))
        if not m:
            continue
        try:
            t = datetime.strptime(m.group(1) + m.group(2), "%Y%m%d%H%M")
        except ValueError:
            continue
        entries.append((t, f))
    entries.sort()

    keep = set()
    daily, weekly = {}, {}
    for t, f in entries:
        age = now - t
        if age < timedelta(hours=24):
            keep.add(f)                                      # 逐小时
        elif age < timedelta(days=7):
            daily.setdefault(t.date(), []).append(f)          # 每天
        elif age < timedelta(days=28):
            weekly.setdefault(t.isocalendar()[:2], []).append(f)  # 每周
    for buckets in (daily, weekly):
        for _k, files in buckets.items():
            keep.add(min(files))                              # 该天/该周最早的一份

    removed = 0
    for t, f in entries:
        if f not in keep:
            try:
                os.unlink(f)
                removed += 1
            except OSError:
                pass
    return len(keep), removed


def main():
    SNAP_DIR.mkdir(parents=True, exist_ok=True)
    vacuum_if_monday_first_run()
    snap = take_snapshot()
    kept, removed = prune()
    total = sum(os.path.getsize(f) for f in glob.glob(str(SNAP_DIR / "backups-*.db*")))
    print(f"快照完成: {snap.name} ({os.path.getsize(snap)} B) | "
          f"保留 {kept} 份 / 清理 {removed} 份 / 合计 {total / 1024:.1f} KB")


if __name__ == "__main__":
    main()
