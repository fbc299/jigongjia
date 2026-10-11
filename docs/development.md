# 格格记工 — 开发文档

> 版本基线：v1.1.12+24（commit `60726b6`）
> 技术栈：Flutter 3.8+ / Dart · Provider + Repository · sqflite · 纯 stdlib Python 服务端 · 腾讯云 COS

---

## 1. 架构总览

```
UI (screens/) ──▶ Providers (状态/业务) ──▶ Repositories (数据访问) ──▶ sqflite (SQLite)
                              │
                              ├── NetworkBackupService (网络备份, http)
                              ├── pdf_util (导出 PDF)
                              ├── watermark_util (照片水印, image 包)
                              └── PrivacyService (金额隐藏, SharedPreferences)
```

- **Provider**：每个业务实体一个 Provider + 一个 Repository（`provider_base.dart` 提供通用
  CRUD 壳，减少重复代码）。页面只依赖 Provider，不直接碰数据库。
- **Repository**：封装 sqflite 读写；删除项目级数据靠数据库 `ON DELETE CASCADE` 外键。
- **金额隐藏（隐私模式）**：`PrivacyService` 持久化开关；所有金额显示统一走
  `AppConstants.privacyMask(value)`，隐藏时渲染 `****`。

### 1.1 目录结构（lib/）

```
lib/
├── main.dart                     # 入口：ProviderScope 装配所有 Provider
├── app.dart                      # 主框架：4 Tab（记工/项目/统计/工具）IndexedStack
├── core/
│   ├── constants/app_constants.dart   # 表名/DB名/常量
│   ├── database/database_helper.dart  # sqflite 建库建表（_onCreate）
│   ├── errors/app_error_helper.dart   # 统一错误解析/提示
│   ├── theme/app_theme.dart           # 主题
│   └── utils/
│       ├── network_backup.dart        # 网络备份服务（ping/list/upload/restore/delete/cosLink）
│       ├── pdf_util.dart              # 结算单 PDF 导出
│       ├── watermark_util.dart        # 照片防篡改水印（时间/GPS/项目）
│       └── privacy_service.dart       # 隐私模式
├── models/      # 7 个数据模型（含 WorkType 枚举、salary 计算）
├── providers/   # 8 个 Provider（Project/Work/Borrow/Settlement/Expense/Note/PhotoEvidence/Stats）
├── repositories/# 8 个 Repository（一一对应模型）
└── screens/     # 9 个页面 + widgets/ 公共组件
```

---

## 2. 数据模型与工资公式（核心口径）

### 2.1 工种类型（互斥）

```dart
enum WorkType {
  point,      // 点工
  packageDay, // 包工（按天）
  packageQty, // 包工（按量/计件）
}
```

### 2.2 工资计算（`WorkRecord.calcTotalWage()`，按需计算）

```
isRest = true            → 0
type = point             → days × dailyRate + overtimeHours × overtimeRate
type = packageDay        → packageDays × packageDayRate
type = packageQty        → quantity × qtyUnitPrice
```

> 三种类型**互斥**，同一记录只按一种口径算钱。`totalWage` 字段仍存库（兼容旧数据），
> 但读取时按公式**重算**，杜绝口径漂移；改单价/天数后工资自动正确。

### 2.3 项目默认值

`Project` 建项时可设默认工价，新建记录时自动带出：

| 字段 | 默认 | 说明 |
|---|---|---|
| `defaultDailyRate` | 300 | 点工日薪 |
| `defaultOvertimeRate` | 50 | 加班单价（元/小时） |
| `defaultPackageDayRate` | 0 | 包工日薪 |
| `defaultPackageQtyRate` | 0 | 计件单价 |
| `defaultQtyUnit` | "平方" | 计量单位 |

### 2.4 未结工资口径

```
未结工资 = 总工资（按 2.2 公式） - 累计借支 - 累计已结算
```

不钳负（允许为负 = 表示已多结），这是 `v1.1.6` 定下的口径，勿改。

---

## 3. 数据库 schema（sqflite, `jigongjia.db`, version=1）

7 张表，全部 `id TEXT PRIMARY KEY`（UUID），项目级表带
`FOREIGN KEY (projectId) ... ON DELETE CASCADE`（删项目自动清子表）：

| 表 | 关键字段 | 说明 |
|---|---|---|
| `projects` | name, isArchived, default*Rate, defaultQtyUnit | 项目/默认工价 |
| `work_records` | type, days, dailyRate, overtimeHours, overtimeRate, packageDays, packageDayRate, quantity, qtyUnit, qtyUnitPrice, totalWage, note, isRest | 记工记录 |
| `borrow_records` | amount, note | 借支 |
| `settlements` | amount, type('partial'/'full'), note | 结算（永久保留） |
| `photo_evidence` | filePath, projectName, timestamp, workRecordId(SET NULL) | 照片存证 |
| `expenses` | amount, category, note | 开支 |
| `notes` | content, updatedAt | 笔记 |

索引：`work_records(projectId)`、`work_records(date)`。
照片删项目时 `workRecordId ON DELETE SET NULL`，文件归档不丢。

---

## 4. 云端备份链路（App ↔ 服务端 ↔ 腾讯云 COS）

```
App 工具页「上传备份」
  → NetworkBackupService.upload(json)
  → POST {server}/api/backup  (Header: token=master)
服务端 backup_server.py
  ① 写 SQLite backups 表（保留最新 10 份，挤掉旧的）
  ② 镜像同步到腾讯云 COS 桶 fbc299-1258301468 前缀 jigong/（cos_mirroring_upload/delete，
     尽力而为，失败不阻断主备份）
  ③ 返回 {ok, name, cos_ok, time}
App 端提示
  → 服务器备份 ✓/✗   与   腾讯云存储桶备份 ✓/✗  两条分开（v1.1.11）

App 工具页「存储桶下载」卡片
  → GET {server}/api/cos-link?expire=3600   (Header: token=master)
  → 服务端 qcloud_cos.get_presigned_url() 生成限时下载 URL
  → App 每 30s 自检，剩余 <60s 自动换新（v1.1.12）
```

### 4.1 服务端 REST API

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/api/ping` | 无 | 探活 `{ok, time}` |
| GET | `/api/backups` | token | 列表 `[{name, modified, size}]` |
| POST | `/api/backup` | token | 上传；50MB 上限；`__backup_name` 经 URL 编码/白名单清洗防路径遍历 |
| GET | `/api/backup/<name>` | token | 下载 |
| DELETE | `/api/backup/<name>` | token | 删除 + 同步删 COS |
| GET | `/api/cos-link` | token | `?name=<备份名> ?expire=<秒>`（默认最新/3600s）→ `{ok, name, url, expires_at, expire_seconds}` |

鉴权：仅 master token（`hmac.compare_digest`，防时序攻击）；token 存
`server/.backup_token`（0600）。

### 4.2 COS 预签名链接的时限

`get_presigned_url(Method='GET', Expired=3600)` 生成限时 URL（COS V5 签名，
URL 内含 AccessKeyId —— 这是 AK 的 ID 非 SecretKey，符合 COS 机制，可接受；
SecretKey 不落 URL）。**有时限**，App 端到期前自动刷新。

---

## 5. 构建与发版

```bash
export PATH="$PATH:/vol1/fbc299/flutter/bin:/vol1/fbc299/android-sdk/..."
cd /vol1/fbc299/jigongjia
flutter pub get
flutter analyze --no-pub        # 必须 0 error（test/ 里既有旧问题可忽略）
flutter build apk --release --split-per-abi
# 产物 build/app/outputs/flutter-apk/app-{armeabi-v7a,arm64-v8a,x86_64}-release.apk
aapt dump badging <apk> | grep versionCode   # 验证版本号
```

**发版习惯**：每次迭代 `versionCode+1`、`versionName` 语义化（1.1.x 小功能/修复），
APK 通过飞书发送。

**工作流约定**（本项目）：代码修改与编译**分离**——改完 grep/analyze 验证 → 用户确认 →
再编译。改动必须 100% 到位，改完 grep 验证。

---

## 6. 已知注意事项 / 坑

- `totalWage` 存库但**读取时重算**——新增工资计算因素时同步改 `calcTotalWage()` 与
  `WorkRecord.fromMap()` 两处。
- 备份地址**强制 HTTPS**（v1.1.10）；本机测试可 `http://127.0.0.1`。
- 服务端 `jianyi-backup.service` 已改 `Restart=on-failure`（之前 on-failure 被 TERM 后
  曾躺死 2 天致 502）；`RestartSec=5`。
- 服务端域名：Caddy `jg.fbc299.xyz` / `bf.fbc299.xyz` 均反代 `127.0.0.1:18080`。
- 导入 JSON 校验：结构/字段类型不合 → 事务回滚，绝不半写入。
- 删项目：数据库 CASCADE 清子表 + 清本地照片缓存 + 结算记录保留（永久）。
- `test/` 目录有既有的 `AppConstants` getter 未定义旧 error，与新代码无关，勿因此卡发版。

---

## 7. 版本历史

- **v1.1.12+24** 工具页加腾讯云 COS 预签名下载链接卡片（可复制 + 临期自动刷新）
- **v1.1.11+23** 备份提示分服务器/腾讯云存储桶，失败指明哪个失败
- **v1.1.10+22** 备份地址强制 HTTPS 校验
- **v1.1.8~1.1.9** 包工计件（默认单位"平方"）、isRest 休息天、记录 note、totalWage 按需计算、
  安全审计修复（Token 不明文/文件名 URL 编码/导入校验+回滚）
- **v1.1.4+16** 审计修复基线：财务口径统一/备份含照片/删项目清缓存/全额结算带未结/
  隐藏明文/移除硬编码 token/换包名
