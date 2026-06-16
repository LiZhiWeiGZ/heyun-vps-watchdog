# Heyun VPS Watchdog

OpenWrt-friendly shell watchdog for Heyun IDC VPS instances.

The script logs in with Heyun API credentials, checks one or more VPS service IDs once, and sends a power-on command when an instance is stopped. It is designed to be run by `cron`, so it does not keep a long-running process.

## Requirements

- POSIX `sh`
- `curl`
- `jsonfilter` recommended on OpenWrt

If `jsonfilter` is unavailable, the script falls back to simple `sed` parsing for the fields it needs.

## Files

```text
heyun_vps_watchdog.sh           Main script
heyun_vps_watchdog.conf.example Example private config
```

## Configuration

Copy the example config:

```sh
cp heyun_vps_watchdog.conf.example heyun_vps_watchdog.conf
chmod 600 heyun_vps_watchdog.conf
```

Edit `heyun_vps_watchdog.conf`:

```sh
API_USERNAME="your-api-username"
API_KEY="your-api-key"
HEYUN_SERVICE_ID="8924"
```

Multiple service IDs are supported:

```sh
HEYUN_SERVICE_ID="8924 9001 9002"
```

or:

```sh
HEYUN_SERVICE_ID="8924,9001,9002"
```

Optional settings:

```sh
BASE_URL="https://www.heyunidc.cn"
TIMEOUT="15"
COOKIE_FILE="/tmp/heyun_vps_watchdog.cookie"
LOG_PATH="/tmp/heyun_vps_watchdog.log"
```

The private config file is ignored by git.

## Environment Overrides

All settings can also be provided with environment variables:

```sh
export HEYUN_API_USERNAME="your-api-username"
export HEYUN_API_KEY="your-api-key"
export HEYUN_SERVICE_ID="8924,9001"
export HEYUN_LOG_PATH="/tmp/heyun_vps_watchdog.log"
```

Environment variables override values from `heyun_vps_watchdog.conf`.

You can also pass service IDs as command arguments:

```sh
./heyun_vps_watchdog.sh 8924 9001
```

## Manual Run

```sh
chmod +x heyun_vps_watchdog.sh
./heyun_vps_watchdog.sh
tail -n 50 /tmp/heyun_vps_watchdog.log
```

Example log:

```text
[2026-06-16 09:11:18] run: start
[09:11:18] 登录: 成功
[09:11:18] 实例: 开始检测 id=8924
[09:11:19] 状态: running; 原始信息: on 开机
[2026-06-16 09:11:19] run: exit=0
```

## OpenWrt Cron

Upload the files to your router, for example:

```sh
mkdir -p /root/heyun
scp heyun_vps_watchdog.sh heyun_vps_watchdog.conf.example root@openwrt:/root/heyun/
```

On OpenWrt:

```sh
cd /root/heyun
cp heyun_vps_watchdog.conf.example heyun_vps_watchdog.conf
chmod 600 heyun_vps_watchdog.conf
chmod 700 heyun_vps_watchdog.sh
vi heyun_vps_watchdog.conf
```

Edit root crontab:

```sh
crontab -e
```

Run every hour at minute 7:

```cron
7 * * * * /root/heyun/heyun_vps_watchdog.sh
```

Reload cron if needed:

```sh
/etc/init.d/cron reload
```

View logs:

```sh
tail -n 100 /tmp/heyun_vps_watchdog.log
```

## Notes

- Use API credentials from the Heyun client area API management page.
- Do not commit `heyun_vps_watchdog.conf`.
- If an API key was ever shared or committed, revoke it and generate a new one.
