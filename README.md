# 格格记工

> 工地记工记账 App（Flutter）：考勤、工资、借支、结算、开支、拍照存证、云端备份一体化工具。
> 当前版本：**v1.1.12+24**

## 功能模块

| 模块 | 说明 |
|---|---|
| 📋 记工 | 日历点工/包工/计件记录，加班小时手填，休息天标记，备注，未到日期禁止记工 |
| 💰 项目 | 多项目管理，默认日薪/加班单价/包工日薪/计件单价（默认单位"平方"） |
| 📊 统计 | 工天/加班/工资/借支/结算汇总，fl_chart 图表，考勤日历 |
| 🧾 结算 | 部分/全额结算；工资按工种类型**互斥**计算（见下方公式），借支在结算时自动冲抵 |
| 🔒 借支 | 借支记录，结算时自动冲抵，累计自动统计 |
| 📷 拍照 | 现场照片带防篡改水印（时间/GPS/项目），可挂到具体记工记录 |
| 📓 笔记 / 开支 | 工地笔记、日常开支按月汇总 |
| 🔞 隐私模式 | 一键隐藏所有金额，各页独立眼睛图标切换，状态自动保存 |
| 💾 数据备份 | 本地 JSON 导出/导入（结构校验+事务回滚）、网络备份、腾讯云 COS 存储桶 |

## 使用说明（App 端）

1. 底部导航 4 个 Tab：**记工 / 项目 / 统计 / 工具**。
2. **项目** 页先建项目，可设默认日薪（默认 300）、加班单价（默认 50）、包工日薪、计件单价与计量单位（默认"平方"）。
3. **记工** 页在日历上点日期记工：选类型（点工/包工/计件/休息）、天数、加班小时、备注；未到当前日期禁止记工。
4. 工资为**按需计算**（`totalWage` 不落库，读取时按公式重算），口径永不漂移。
5. **工具** 页：
   - **导出备份 / 导入备份**：JSON 本地备份；导入前做结构与字段类型校验，异常事务回滚，失败不污染数据。
   - **腾讯云备份**：填服务器地址（须 HTTPS；本机测试可 `http://127.0.0.1`）与 Token，点「上传备份」。
     结果分两条提示：**服务器备份成功/失败**、**腾讯云存储桶备份成功/失败**，哪个失败报哪个。
   - **腾讯云存储桶下载** 卡片：展示最新备份的**预签名下载链接**（默认 1 小时有效），
     可一键复制/长按复制，**剩余 60 秒内自动换新链接**，长开也不会拿到过期链接。

## 服务端（备份服务器）

纯 Python stdlib + qcloud_cos，无第三方 Web 框架。完整部署代码见 [`server/`](server/) 目录。

- 存储：SQLite（`backups.db`，保留最新 10 份）+ **腾讯云 COS 镜像**（桶内前缀 `jigong/`，备份/删除同步，失败不阻断主流程）
- 鉴权：仅 master token（`.backup_token` 文件，0600），匿名/无效一律 401
- 部署：systemd（`jianyi-backup.service`，`Restart=on-failure`），默认端口 18080，Caddy 反代 HTTPS

### 接口一览

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/ping` | 匿名探活，返回 `{ok, time}` |
| GET | `/api/backups` | 备份列表（需 token） |
| POST | `/api/backup` | 上传备份 JSON（需 token，50MB 上限，文件名 URL 编码防路径遍历），返回 `{ok, name, cos_ok}` |
| GET | `/api/backup/<name>` | 下载指定备份（需 token） |
| DELETE | `/api/backup/<name>` | 删除并同步删 COS 副本（需 token） |
| GET | `/api/cos-link?name=&expire=` | 腾讯云 COS 预签名下载链接（需 token，默认最新备份 / 3600 秒） |

### 部署步骤

```bash
# 1. 安装 COS SDK（清华镜像）
pip3 install qcloud_cos -i https://pypi.tuna.tsinghua.edu.cn/simple

# 2. 配置 COS 凭据（coscmd 或手工写 ~/.cos.conf）
#    [COS] SecretId / SecretKey / Region(ap-guangzhou)

# 3. 启动（首次自动生成 .backup_token）
python3 server/backup_server.py --port 18080

# 4. 用 systemd 常驻： server/jianyi-backup.service（把 ExecStart 路径改成实际位置）
# 5. Caddy 反代 HTTPS 到 127.0.0.1:18080（fbc299.xyz:10443）
```

Token 填入 App「工具 → 腾讯云备份 → 设置」即可。

## 开发文档

架构、数据库 schema、工资公式、目录结构与构建方法见 **[docs/development.md](docs/development.md)**。

## 构建（Android）

```bash
export PATH="$PATH:$FLUTTER_HOME/bin"
flutter pub get
flutter build apk --release --split-per-abi
# 产物: build/app/outputs/flutter-apk/app-<abi>-release.apk
# 发版习惯: versionCode +1, versionName 语义化
```

## 技术栈

Flutter 3.8+ · Dart · Provider · sqflite · fl_chart · pdf/printing · http · image(水印) · 纯 stdlib Python 服务端 · 腾讯云 COS

## 版本历史（近期）

- **v1.1.12+24** 工具页加腾讯云 COS 预签名下载链接卡片（可复制 + 临期自动刷新）
- **v1.1.11+23** 备份提示分服务器/腾讯云存储桶，失败指明哪个失败
- **v1.1.10+22** 备份地址强制 HTTPS 校验
- **v1.1.4+16** 审计修复基线（财务口径统一/备份含照片/删项目清缓存/隐藏明文/移除硬编码 token）

## 开发者

格格记工（fbc299）
