#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "請使用 sudo 執行。"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/debian_ubuntu_info_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BASE_DIR"

# 建立分類資料夾
mkdir -p "$BASE_DIR"/{net,process,system,account,log}

# 網路資訊
ss -tulnp > "$BASE_DIR/net/ss.txt"
ss -anp > "$BASE_DIR/net/netstat.txt" 2>/dev/null
lsof -i > "$BASE_DIR/net/lsof.txt" 2>/dev/null
ip a > "$BASE_DIR/net/ip_a.txt"
ip route > "$BASE_DIR/net/ip_route.txt"
ufw status verbose > "$BASE_DIR/net/ufw.txt" 2>/dev/null
iptables -L -v -n > "$BASE_DIR/net/iptables.txt" 2>/dev/null
who > "$BASE_DIR/net/who.txt"

# 檢查共享資料夾與網路資源狀況
SHARE_DIR="$BASE_DIR/net/share"
mkdir -p "$SHARE_DIR"

# 檢查是否安裝並啟用 Samba
if systemctl list-unit-files | grep -q smbd; then
    systemctl status smbd > "$SHARE_DIR/smbd_status.txt" 2>/dev/null
    systemctl status nmbd > "$SHARE_DIR/nmbd_status.txt" 2>/dev/null

    # 如果 smbd 正在執行，收集設定與連線資訊
    if systemctl is-active --quiet smbd; then
        [ -f /etc/samba/smb.conf ] && cp /etc/samba/smb.conf "$SHARE_DIR/smb.conf"
        which smbstatus &>/dev/null && smbstatus > "$SHARE_DIR/smbstatus.txt"
    fi
fi

# 檢查是否有掛載 CIFS / NFS 等網路檔案系統
mount | grep -E 'type (cifs|nfs)' > "$SHARE_DIR/network_mounts.txt"

# 額外檢查常見分享服務埠是否開啟（如 TCP 445、139）
ss -tuln | grep -E ':445|:139' > "$SHARE_DIR/share_ports.txt"

### 檢查是否啟用 NFS 伺服器 ###
if systemctl list-unit-files | grep -q nfs-server; then
    systemctl status nfs-server > "$SHARE_DIR/nfs_status.txt" 2>/dev/null

    # 如果 NFS server 有啟動，收集 NFS 共享與存取資訊
    if systemctl is-active --quiet nfs-server; then
        [ -f /etc/exports ] && cp /etc/exports "$SHARE_DIR/nfs_exports.txt"
        which exportfs &>/dev/null && exportfs -v > "$SHARE_DIR/nfs_exportfs.txt"
        which showmount &>/dev/null && showmount -a > "$SHARE_DIR/nfs_showmount.txt"
    fi
fi

# 不論是否為 NFS server，都可檢查本機是否有掛載 NFS share
findmnt -t nfs,nfs4 > "$SHARE_DIR/nfs_mounts.txt"

# 程序與排程
ps aux > "$BASE_DIR/process/ps_aux.txt"
top -b -n 1 > "$BASE_DIR/process/top.txt"
systemctl list-unit-files --type=service > "$BASE_DIR/process/services.txt"
systemctl list-timers > "$BASE_DIR/process/timers.txt"
crontab -l > "$BASE_DIR/process/crontab.txt" 2>/dev/null
ls /etc/cron* > "$BASE_DIR/process/cron_dirs.txt"
find / -type f \( -name "*.exe" -o -name "*.bat" -o -name "*.cmd" \) -exec ls -al {} \; > "$BASE_DIR/process/suspicious_exec.txt" 2>/dev/null

# 系統資訊
uname -a > "$BASE_DIR/system/uname.txt"
cat /etc/os-release >> "$BASE_DIR/system/uname.txt"
uptime > "$BASE_DIR/system/uptime.txt"
timedatectl > "$BASE_DIR/system/time.txt"
systeminfo=$(which systeminfo 2>/dev/null)
[ -n "$systeminfo" ] && systeminfo > "$BASE_DIR/system/systeminfo.txt"
dpkg -l > "$BASE_DIR/system/packages.txt"
wmic qfe list 2>/dev/null > "$BASE_DIR/system/hotfixes.txt" # 若裝有 wmic

# 使用者與帳號
id > "$BASE_DIR/account/you.txt"
whoami > "$BASE_DIR/account/whoami.txt"
cat /etc/passwd > "$BASE_DIR/account/passwd.txt"
cat /etc/group > "$BASE_DIR/account/group.txt"
getent shadow > "$BASE_DIR/account/shadow.txt" 2>/dev/null
ss -anp | grep ssh > "$BASE_DIR/account/remote_ssh.txt" 2>/dev/null

# 系統日誌
journalctl -xe > "$BASE_DIR/log/journalctl.txt" 2>/dev/null
[ -f /var/log/auth.log ] && tail -n 200 /var/log/auth.log > "$BASE_DIR/log/authlog.txt"
[ -f /var/log/syslog ] && tail -n 200 /var/log/syslog > "$BASE_DIR/log/syslog.txt"
dmesg | tail -n 200 > "$BASE_DIR/log/dmesg.txt"

echo "✅ 資訊收集完成，存於：$BASE_DIR"