#!/usr/bin/env python3
"""简约记工 备份服务端 — 零依赖，Python 标准库实现（SQLite 单共享表）。

启动:  python3 backup_server.py [--port 18080] [--token YOUR_SECRET]

存储模型: SQLite 单库（/vol1/fbc299/jianyi-jigong-server/backups.db）
  backups 表 : name 主键 + body + created_at（所有设备共享一个备份空间）

鉴权模型:
  - master token（.backup_token 文件或 --token 参数）→ 放行
  - 匿名请求一律拒绝；token 即唯一凭据

API:
  GET  /api/ping            健康检查（无需认证）
  POST /api/backup          上传备份（Bearer <token>，Body=JSON 文本，可带 __backup_name）
  GET  /api/backups        列出备份（按 created_at 降序）
  GET  /api/backup/<name>  下载指定备份
  DELETE /api/backup/<name> 删除指定备份
"""

import argparse
import configparser
import hmac
import json
import os
import re
import secrets
import sqlite3
import sys
import threading
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import unquote, urlparse, quote, parse_qs

# 腾讯云官方 SDK（qcloud_cos，system python3 已装）
try:
    import qcloud_cos
except ImportError:
    qcloud_cos = None

# ─── 配置 ───
SERVER_DIR = Path(__file__).parent
DB_FILE = SERVER_DIR / "backups.db"
MAX_BACKUPS = 10                  # 保留最新 N 份备份
UPLOAD_LIMIT = 50 * 1024 * 1024   # 50MB 上限
DEFAULT_PORT = 18080
TOKEN_FILE = SERVER_DIR / ".backup_token"
TABLE = "backups"

# ─── COS 镜像（腾讯云官方 SDK qcloud_cos，尽力而为，失败不影响 NAS 主备份）───
COS_CONF = "/home/fbc299/.cos.conf"
COS_BUCKET = "fbc299-1258301468"
COS_PREFIX = "jigong"            # 桶内前缀目录
_cos_client = None


def _get_cos_client():
    """惰性初始化 qcloud_cos 客户端。SDK 缺失或配置异常时返回 None（镜像自动跳过）。"""
    global _cos_client
    if _cos_client is not None or qcloud_cos is None:
        return _cos_client
    try:
        cp = configparser.ConfigParser()
        cp.read(COS_CONF)
        d = cp["common"]
        cfg = qcloud_cos.CosConfig(
            Region=d["region"],
            SecretId=d["secret_id"],
            SecretKey=d["secret_key"],
        )
        _cos_client = qcloud_cos.CosS3Client(cfg)
    except Exception as e:
        sys.stderr.write(f"[COS] 初始化失败，镜像关闭: {e}\n")
        _cos_client = False
    return _cos_client

DB_SCHEMA = f"""
CREATE TABLE IF NOT EXISTS {TABLE} (
  name       TEXT PRIMARY KEY,
  body       TEXT NOT NULL,
  created_at TEXT NOT NULL
);
"""

_db_lock = threading.Lock()


def _db() -> sqlite3.Connection:
    conn = sqlite3.connect(str(DB_FILE), timeout=10)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.executescript(DB_SCHEMA)
    return conn


def load_or_create_token(cli_token: str | None) -> str:
    if cli_token:
        TOKEN_FILE.write_text(cli_token)
        TOKEN_FILE.chmod(0o600)
        return cli_token
    if TOKEN_FILE.exists():
        return TOKEN_FILE.read_text().strip()
    token = secrets.token_urlsafe(32)
    TOKEN_FILE.write_text(token)
    TOKEN_FILE.chmod(0o600)
    return token


def _sanitize_backup_name(name: str | None) -> str:
    now = datetime.now()
    if name:
        name = re.sub(r"[^\w\u4e00-\u9fff\-.]", "_", name)
        if not name.endswith(".json"):
            name += ".json"
        return name
    return f"jianyi_backup_{now.year}{now.month:02d}{now.day:02d}_{now.hour:02d}{now.minute:02d}{now.second:02d}.json"


def cos_mirroring_upload(name: str, body_json: str) -> bool:
    """备份上传成功后镜像一份到腾讯云 COS。尽力而为，失败仅告警。"""
    cli = _get_cos_client()
    if not cli:
        return False
    key = f"{COS_PREFIX}/{name}"
    try:
        data = body_json.encode("utf-8")
        cli.put_object(Bucket=COS_BUCKET, Key=key, Body=data)
        return True
    except Exception as e:
        sys.stderr.write(f"[COS镜像] 上传 {name} 失败: {e}\n")
        return False


def cos_mirroring_delete(name: str) -> bool:
    """备份删除时同步删 COS 副本。尽力而为，失败仅告警。"""
    cli = _get_cos_client()
    if not cli:
        return False
    key = f"{COS_PREFIX}/{name}"
    try:
        cli.delete_object(Bucket=COS_BUCKET, Key=key)
        return True
    except Exception as e:
        sys.stderr.write(f"[COS镜像] 删除 {name} 失败: {e}\n")
        return False


def cos_presigned_link(name: str | None = None, expire: int = 3600) -> dict:
    """生成腾讯云 COS 预签名下载链接（有时限，默认 1 小时）。
    不带 name → 取最新一份备份。"""
    cli = _get_cos_client()
    if not cli:
        return {"ok": False, "error": "COS 镜像未启用"}
    if not name:
        with _db_lock, _db() as conn:
            row = conn.execute(
                f"SELECT name FROM {TABLE} ORDER BY created_at DESC, name DESC LIMIT 1"
            ).fetchone()
        if not row:
            return {"ok": False, "error": "暂无备份"}
        name = row[0]
    key = f"{COS_PREFIX}/{name}"
    try:
        url = cli.get_presigned_download_url(Bucket=COS_BUCKET, Key=key, Expired=expire)
        return {
            "ok": True,
            "name": name,
            "url": url,
            "expire_seconds": expire,
            "expires_at": int(datetime.now().timestamp()) + expire,
        }
    except Exception as e:
        sys.stderr.write(f"[COS] 生成下载链接失败 {name}: {e}\n")
        return {"ok": False, "error": str(e)[:200]}


class BackupHandler(BaseHTTPRequestHandler):
    master_token = ""

    def log_message(self, fmt, *args):
        ts = datetime.now().strftime("%H:%M:%S")
        sys.stderr.write(f"[{ts}] {fmt % args}\n")

    def _json(self, code: int, data: dict):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    # 鉴权：仅 master token → 放行；匿名 / 无效 → 401。
    def _auth(self) -> bool | str:
        """返回 'master' 表示放行；None 表示拒绝。"""
        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return None
        provided = auth[7:].strip()
        if not provided:
            return None
        if hmac.compare_digest(provided, self.master_token):
            return "master"
        return None

    def _read_body(self, max_bytes: int) -> bytes | None:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return b""
        if length > max_bytes:
            self._json(413, {"error": "备份文件过大（上限 50MB）"})
            return None
        return self.rfile.read(length)

    # ─── GET ───
    def do_GET(self):
        parsed = urlparse(self.path)
        path = unquote(parsed.path)

        if path == "/api/ping":
            return self._json(200, {"ok": True, "time": datetime.now().isoformat()})

        if not self._auth():
            return self._json(401, {"error": "未授权：token 无效"})

        if path == "/api/backups":
            with _db_lock, _db() as conn:
                rows = conn.execute(
                    f"SELECT name, created_at, length(body) FROM {TABLE} "
                    "ORDER BY created_at DESC, name DESC"
                ).fetchall()
                items = [{"name": n, "modified": c, "size": s} for n, c, s in rows]
            return self._json(200, {"backups": items, "total": len(items)})

        if path.startswith("/api/backup/"):
            name = path[len("/api/backup/"):]
            with _db_lock, _db() as conn:
                row = conn.execute(f"SELECT body FROM {TABLE} WHERE name=?", (name,)).fetchone()
            if not row:
                return self._json(404, {"error": f"备份 {name} 不存在"})
            content = row[0].encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
            return

        if path == "/api/cos-link":
            # 可选 ?name=<备份名> 与 ?expire=<秒>（默认最新备份 / 3600s）
            qs = parse_qs(urlparse(self.path).query)
            link_name = unquote(qs.get("name", [""])[0]) or None
            try:
                link_expire = int(qs.get("expire", ["3600"])[0])
            except ValueError:
                link_expire = 3600
            return self._json(200, cos_presigned_link(link_name, link_expire))

        self._json(404, {"error": "接口不存在"})

    # ─── POST ───
    def do_POST(self):
        parsed = urlparse(self.path)
        path = unquote(parsed.path)

        if not self._auth():
            return self._json(401, {"error": "未授权：token 无效"})

        if path == "/api/backup":
            body = self._read_body(UPLOAD_LIMIT)
            if body is None:
                return
            try:
                data = json.loads(body)
                if not isinstance(data, dict):
                    raise ValueError
            except (json.JSONDecodeError, ValueError):
                return self._json(400, {"error": "无效的 JSON 格式"})
            name = _sanitize_backup_name(data.pop("__backup_name", None))
            now = datetime.now()
            with _db_lock, _db() as conn:
                conn.execute(
                    f"INSERT OR REPLACE INTO {TABLE} (name, body, created_at) VALUES (?,?,?)",
                    (name, json.dumps(data, ensure_ascii=False), now.isoformat(timespec="seconds")),
                )
                # 保留最新 MAX_BACKUPS 份
                olds = [r[0] for r in conn.execute(
                    f"SELECT name FROM {TABLE} ORDER BY created_at DESC, name DESC LIMIT -1 OFFSET ?",
                    (MAX_BACKUPS,)).fetchall()]
                if olds:
                    conn.executemany(f"DELETE FROM {TABLE} WHERE name=?", [(o,) for o in olds])
            # 镜像到腾讯云 COS（尽力而为，失败不阻断主备份）
            cos_ok = cos_mirroring_upload(name, json.dumps(data, ensure_ascii=False))
            # 同时清理被挤掉的旧备份在 COS 的副本
            for o in olds:
                cos_mirroring_delete(o)
            return self._json(200, {"ok": True, "name": name,
                                    "cos_ok": cos_ok,
                                    "time": now.strftime("%Y-%m-%d %H:%M:%S")})

        self._json(404, {"error": "接口不存在"})

    # ─── DELETE ───
    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = unquote(parsed.path)

        if not self._auth():
            return self._json(401, {"error": "未授权：token 无效"})

        if path.startswith("/api/backup/"):
            name = path[len("/api/backup/"):]
            if "/" in name or "\\" in name or ".." in name:
                return self._json(400, {"error": "无效的文件名"})
            with _db_lock, _db() as conn:
                cur = conn.execute(f"DELETE FROM {TABLE} WHERE name=?", (name,))
            if cur.rowcount == 0:
                return self._json(404, {"error": f"备份 {name} 不存在"})
            # 同步删 COS 副本（尽力而为）
            cos_mirroring_delete(name)
            return self._json(200, {"ok": True, "deleted": name})

        self._json(404, {"error": "接口不存在"})


def main():
    parser = argparse.ArgumentParser(description="简约记工备份服务（SQLite 共享表）")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--token", type=str, default=None, help="master token")
    args = parser.parse_args()

    master = load_or_create_token(args.token)
    BackupHandler.master_token = master
    with _db() as conn:
        pass  # 建表

    server = HTTPServer(("127.0.0.1", args.port), BackupHandler)
    print(f"╔══════════════════════════════════════════╗")
    print(f"║   简约记工 备份服务端（SQLite 共享表）   ║")
    print(f"║   端口: {args.port:<33}║")
    print(f"║   数据库: {str(DB_FILE):<31}║")
    print(f"║   保留: {MAX_BACKUPS:<34}║")
    print(f"╚══════════════════════════════════════════╝")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n服务已停止")
        server.server_close()


if __name__ == "__main__":
    main()