# 核云 VPS Watchdog

一个适合 OpenWrt 使用的核云 VPS 状态检测脚本。

脚本每次运行只做一次检测：使用核云 API 凭据登录，检查一个或多个 VPS 实例状态；如果发现实例已经关机，则自动发送开机指令。脚本本身不会常驻运行，推荐交给 Linux/OpenWrt 的 `cron` 定时执行。

## 功能

- 使用核云 API 登录
- 支持一个或多个 VPS 服务 ID
- 检测 VPS 电源状态
- 状态为关机时自动开机
- 自带日志输出
- 适合 OpenWrt，无需 Python

## 依赖

需要系统具备：

```sh
sh
curl
```

OpenWrt 上推荐有：

```sh
jsonfilter
```

如果没有 `jsonfilter`，脚本会用 `sed` 做简单字段解析。

## 文件说明

```text
heyun_vps_watchdog.sh           主脚本
heyun_vps_watchdog.conf.example 配置模板
heyun_vps_watchdog.conf         私有配置文件，不要提交到 Git
```

## 配置

复制配置模板：

```sh
cp heyun_vps_watchdog.conf.example heyun_vps_watchdog.conf
chmod 600 heyun_vps_watchdog.conf
```

编辑配置文件：

```sh
vi heyun_vps_watchdog.conf
```

填写你的核云 API 凭据和实例 ID：

```sh
API_USERNAME="你的API用户名"
API_KEY="你的API密钥"
HEYUN_SERVICE_ID="8924"
```

`HEYUN_SERVICE_ID` 就是核云详情页 URL 里的 `id`，例如：

```text
https://www.heyunidc.cn/servicedetail?id=8924
```

这里的服务 ID 就是：

```text
8924
```

## 多个实例

支持空格分隔：

```sh
HEYUN_SERVICE_ID="8924 9001 9002"
```

也支持逗号分隔：

```sh
HEYUN_SERVICE_ID="8924,9001,9002"
```

## 可选配置

```sh
BASE_URL="https://www.heyunidc.cn"
TIMEOUT="15"
COOKIE_FILE="/tmp/heyun_vps_watchdog.cookie"
LOG_PATH="/tmp/heyun_vps_watchdog.log"
```

说明：

- `BASE_URL`：核云站点地址
- `TIMEOUT`：请求超时时间，单位秒
- `COOKIE_FILE`：临时 cookie 文件路径
- `LOG_PATH`：日志输出路径

## 环境变量覆盖

也可以不写配置文件，直接用环境变量：

```sh
export HEYUN_API_USERNAME="你的API用户名"
export HEYUN_API_KEY="你的API密钥"
export HEYUN_SERVICE_ID="8924,9001"
export HEYUN_LOG_PATH="/tmp/heyun_vps_watchdog.log"
```

环境变量优先级高于 `heyun_vps_watchdog.conf`。

也可以直接把服务 ID 作为参数传入：

```sh
./heyun_vps_watchdog.sh 8924 9001
```

## 手动执行

```sh
chmod +x heyun_vps_watchdog.sh
./heyun_vps_watchdog.sh
```

查看日志：

```sh
tail -n 50 /tmp/heyun_vps_watchdog.log
```

日志示例：

```text
[2026-06-16 09:11:18] run: start
[09:11:18] 登录: 成功
[09:11:18] 实例: 开始检测 id=8924
[09:11:19] 状态: running; 原始信息: on 开机
[2026-06-16 09:11:19] run: exit=0
```

## OpenWrt 部署

上传文件到 OpenWrt：

```sh
mkdir -p /root/heyun
scp heyun_vps_watchdog.sh heyun_vps_watchdog.conf.example root@openwrt:/root/heyun/
```

在 OpenWrt 上配置：

```sh
cd /root/heyun
cp heyun_vps_watchdog.conf.example heyun_vps_watchdog.conf
chmod 600 heyun_vps_watchdog.conf
chmod 700 heyun_vps_watchdog.sh
vi heyun_vps_watchdog.conf
```

手动测试：

```sh
/root/heyun/heyun_vps_watchdog.sh
tail -n 50 /tmp/heyun_vps_watchdog.log
```

## 定时执行

编辑 root 的 crontab：

```sh
crontab -e
```

每小时第 7 分钟执行一次：

```cron
7 * * * * /root/heyun/heyun_vps_watchdog.sh
```

如果需要每 30 分钟执行一次：

```cron
*/30 * * * * /root/heyun/heyun_vps_watchdog.sh
```

如果需要每天凌晨 3 点执行一次：

```cron
0 3 * * * /root/heyun/heyun_vps_watchdog.sh
```

OpenWrt 上如需重载 cron：

```sh
/etc/init.d/cron reload
```

查看日志：

```sh
tail -n 100 /tmp/heyun_vps_watchdog.log
```

## 安全提醒

- 不要提交 `heyun_vps_watchdog.conf`
- 不要把 API 密钥写进公开仓库
- 如果 API 密钥曾经泄露，建议在核云 API 管理里重新生成
- 建议设置配置文件权限：

```sh
chmod 600 heyun_vps_watchdog.conf
```
