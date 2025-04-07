#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "請使用 sudo 執行。"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/centos_info_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BASE_DIR"/{net,process,system,account,log}

# 網路
ip a > "$BASE_DIR/net/ip_a.txt"
ip route > "$BASE_DIR/net/ip_route.txt"
ss -tulnp > "$BASE_DIR/net/ss.txt"
ss -anlp > "$BASE_DIR/net/netstat.txt"
lsof -i > "$BASE_DIR/net/lsof.txt" 2>/dev/null
firewall-cmd --list-all > "$BASE_DIR/net/firewalld.txt" 2>/dev/null
iptables -L -v -n > "$BASE_DIR/net/iptables.txt"
who > "$BASE_DIR/net/who.txt"

# 檢查共享與網路掛載狀況
SHARE_DIR="$BASE_DIR/net/share"
mkdir -p "$SHARE_DIR"

# Samba 狀態與設定
if systemctl list-unit-files | grep -q smb; then
    systemctl status smb > "$SHARE_DIR/smb_status.txt" 2>/dev/null
    systemctl status nmb > "$SHARE_DIR/nmb_status.txt" 2>/dev/null

    if systemctl is-active --quiet smb; then
        [ -f /etc/samba/smb.conf ] && cp /etc/samba/smb.conf "$SHARE_DIR/smb.conf"
        which smbstatus &>/dev/null && smbstatus > "$SHARE_DIR/smbstatus.txt"
    fi
fi

# 檢查是否啟用 NFS 伺服器
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

# 額外檢查常見分享服務埠是否開啟（如 TCP 445、139、2049）
ss -tuln | grep -E ':445|:139|:2049' > "$SHARE_DIR/share_ports.txt"

# 掛載資源 (CIFS, NFS, SSHFS, WebDAV)
mount | grep -E 'type (cifs|nfs|fuse.sshfs|davfs)' > "$SHARE_DIR/mounted_network.txt"

# 開啟的分享埠
ss -tuln | grep -E ':139|:445|:2049' > "$SHARE_DIR/share_ports.txt"

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
cat /etc/centos-release >> "$BASE_DIR/system/uname.txt"
uptime > "$BASE_DIR/system/uptime.txt"
timedatectl > "$BASE_DIR/system/time.txt"
yum list installed > "$BASE_DIR/system/packages.txt"
dmidecode -t system > "$BASE_DIR/system/systeminfo.txt" 2>/dev/null

# 使用者與帳號
id > "$BASE_DIR/account/you.txt"
whoami > "$BASE_DIR/account/whoami.txt"
cat /etc/passwd > "$BASE_DIR/account/passwd.txt"
cat /etc/group > "$BASE_DIR/account/group.txt"
getent shadow > "$BASE_DIR/account/shadow.txt" 2>/dev/null
ss -anp | grep ssh > "$BASE_DIR/account/remote_ssh.txt"

# 系統日誌
journalctl -xe > "$BASE_DIR/log/journalctl.txt" 2>/dev/null
[ -f /var/log/secure ] && tail -n 200 /var/log/secure > "$BASE_DIR/log/secure.txt"
[ -f /var/log/messages ] && tail -n 200 /var/log/messages > "$BASE_DIR/log/messages.txt"
dmesg | tail -n 200 > "$BASE_DIR/log/dmesg.txt"

echo "✅ CentOS 系統資訊已收集完成，存於：$BASE_DIR"