#!/usr/bin/env python3
"""记工备份异地容灾：把 SQLite 备份库推到腾讯云 COS。

策略（GFS 分层）：
  - 每小时传一份 backups-YYYYmmdd_HHMM.db
  - 48 小时内的全部保留（每小时一份，RPO ≤ 1 小时）
  - 超过 48 小时：每天只保留当天最早的一份，保留 30 天
  - 更早的全部删除

复用 ~/.cos.conf 的 coscmd 配置（cron 环境没有 ~/.local/bin，必须用全路径）。
"""
import datetime as dt
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile

SRC = "/vol1/fbc299/jianyi-jigong-server/backups.db"
COSCMD = "/home/fbc299/.local/bin/coscmd"
BUCKET = "cos://fbc299-1258301468"
PREFIX = "jigong-backup/"

HOURS_FULL = 48        # 48 小时内逐小时全留
DAILY_KEEP_DAYS = 30   # 之后每天留一份，保留 30 天

NAME_RE = re.compile(r"backups-(\d{8})_(\d{4})\.db$")


def cos(*args: str) -> str:
    result = subprocess.run([COSCMD, *args], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"coscmd {' '.join(args)} 失败: {result.stderr.strip()}", file=sys.stderr)
    return result.stdout


def snapshot(dst: str) -> None:
    """用 sqlite3 backup API 在线拷贝（WAL 一致）。"""
    src = sqlite3.connect(SRC)
    out = sqlite3.connect(dst)
    try:
        with out:
            src.backup(out)
    finally:
        out.close()
        src.close()


def upload() -> str:
    ts = dt.datetime.now().strftime("%Y%m%d_%H%M")
    key = f"{PREFIX}backups-{ts}.db"
    fd, tmp = tempfile.mkstemp(prefix="jigong-cos-", suffix=".db")
    os.close(fd)
    try:
        snapshot(tmp)
        cos("upload", tmp, key, "-y")
        print(f"已上传 {BUCKET}/{key} ({os.path.getsize(tmp) / 1024:.0f} KB)")
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)
    return key


def parse_time(name: str) -> dt.datetime | None:
    m = NAME_RE.search(name)
    if not m:
        return None
    return dt.datetime.strptime(m.group(1) + m.group(2), "%Y%m%d%H%M")


def prune() -> None:
    listing = cos("list", PREFIX)
    entries = []
    for line in listing.splitlines():
        parts = line.split()
        if not parts:
            continue
        key = parts[0]
        ts = parse_time(key)
        if ts:
            entries.append((ts, key))
    if not entries:
        return

    entries.sort()
    now = dt.datetime.now()
    full_cutoff = now - dt.timedelta(hours=HOURS_FULL)
    daily_cutoff = now - dt.timedelta(days=DAILY_KEEP_DAYS)

    keep = set()
    first_of_day = {}
    for ts, key in entries:
        if ts >= full_cutoff:
            keep.add(key)
            continue
        day = ts.date()
        if day not in first_of_day:
            first_of_day[day] = key
        if ts >= daily_cutoff:
            keep.add(first_of_day[day])

    for ts, key in entries:
        if key not in keep:
            cos("delete", key, "-y", "-f")
            print(f"已清理 {key}")

    print(f"保留 {len(keep)} 份 / 共 {len(entries)} 份")


def main() -> int:
    if not shutil.which(COSCMD) and not os.path.exists(COSCMD):
        print(f"找不到 coscmd: {COSCMD}", file=sys.stderr)
        return 1
    if not os.path.exists(SRC):
        print(f"找不到源库: {SRC}", file=sys.stderr)
        return 1
    upload()
    prune()
    return 0


if __name__ == "__main__":
    sys.exit(main())
