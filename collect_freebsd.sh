#!/bin/sh
# 適用於 FreeBSD 系統的資訊收集腳本

if [ "$(id -u)" -ne 0 ]; then
    echo "請使用 sudo 執行。"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$SCRIPT_DIR/freebsd_info_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BASE_DIR"

# 建立分類資料夾（sh 不支援大括號展開）
mkdir -p "$BASE_DIR/net"
mkdir -p "$BASE_DIR/process"
mkdir -p "$BASE_DIR/system"
mkdir -p "$BASE_DIR/account"
mkdir -p "$BASE_DIR/log"

# 網路資訊
sockstat -4 -6 > "$BASE_DIR/net/sockstat.txt"
netstat -an > "$BASE_DIR/net/netstat.txt"
fstat | grep -i internet > "$BASE_DIR/net/fstat_inet.txt"
ifconfig -a > "$BASE_DIR/net/ifconfig.txt"
netstat -rn > "$BASE_DIR/net/route.txt"
pfctl -sr > "$BASE_DIR/net/pf_rules.txt" 2>/dev/null
ipfw list > "$BASE_DIR/net/ipfw_rules.txt" 2>/dev/null
w > "$BASE_DIR/net/w.txt"
who > "$BASE_DIR/net/who.txt"

# 檢查共享與網路掛載狀況
SHARE_DIR="$BASE_DIR/net/share"
mkdir -p "$SHARE_DIR"

# Samba 狀態（FreeBSD 多用 samba_server）
service samba_server onestatus > "$SHARE_DIR/samba_status.txt" 2>/dev/null
[ -f /usr/local/etc/smb4.conf ] && cp /usr/local/etc/smb4.conf "$SHARE_DIR/smb4.conf"
which smbstatus >/dev/null 2>&1 && smbstatus > "$SHARE_DIR/smbstatus.txt"

# 檢查是否啟用 NFS 伺服器
if service -e | grep -q nfsd; then
    service nfsd onestatus > "$SHARE_DIR/nfs_status.txt" 2>/dev/null

    # 如果 NFS server 有啟動，收集 NFS 共享與存取資訊
    if service nfsd status | grep -q 'is running'; then
        [ -f /etc/exports ] && cp /etc/exports "$SHARE_DIR/nfs_exports.txt"
        which showmount >/dev/null 2>&1 && showmount -e > "$SHARE_DIR/nfs_showmount.txt"
    fi
fi

# 不論是否為 NFS server，都可檢查本機是否有掛載 NFS share
mount | grep nfs > "$SHARE_DIR/nfs_mounts.txt"

# 額外檢查常見分享服務埠是否開啟（如 TCP 445、139、2049）
sockstat -4 -6 | grep -E ':(445|139|2049)' > "$SHARE_DIR/share_ports.txt"

# 掛載資源（含 NFS、SMB、SSHFS）
mount | grep -E 'smbfs|nfs|sshfs|webdav' > "$SHARE_DIR/mounted_network.txt"

# 監聽分享用的 Port
sockstat -4 -6 | grep -E ':(139|445|2049)' > "$SHARE_DIR/share_ports.txt"


# 程序與排程
ps auxww > "$BASE_DIR/process/ps_aux.txt"
top -b -n 1 > "$BASE_DIR/process/top.txt"
service -e > "$BASE_DIR/process/enabled_services.txt"
crontab -l > "$BASE_DIR/process/user_crontab.txt" 2>/dev/null
cat /etc/crontab > "$BASE_DIR/process/etc_crontab.txt"
{
    echo "/usr/local/etc/periodic:"
    find /usr/local/etc/periodic -type d \( -name "daily" -o -name "monthly" -o -name "security" -o -name "weekly" \) -exec sh -c 'echo "Directory: {}"; ls {}' \;
} > "$BASE_DIR/process/periodic_local.txt"

{
    echo "/etc/periodic:"
    find /etc/periodic -type d \( -name "daily" -o -name "monthly" -o -name "security" -o -name "weekly" \) -exec sh -c 'echo "Directory: {}"; ls {}' \;
} > "$BASE_DIR/process/periodic_system.txt"
find / -type f \( -name "*.sh" -o -name "*.pl" -o -name "*.py" \) -exec ls -al {} \; > "$BASE_DIR/process/suspicious_scripts.txt" 2>/dev/null

# 系統資訊
uname -a > "$BASE_DIR/system/uname.txt"
freebsd-version >> "$BASE_DIR/system/uname.txt"
uptime > "$BASE_DIR/system/uptime.txt"
date > "$BASE_DIR/system/time.txt"
sysctl kern | grep -i version > "$BASE_DIR/system/kernel.txt"
sysctl hw.model hw.ncpu hw.physmem > "$BASE_DIR/system/hardware.txt"
pkg info > "$BASE_DIR/system/pkg_info.txt"

# 使用者與帳號
id > "$BASE_DIR/account/id.txt"
whoami > "$BASE_DIR/account/whoami.txt"
cat /etc/passwd > "$BASE_DIR/account/passwd.txt"
cat /etc/group > "$BASE_DIR/account/group.txt"
pw user show -a > "$BASE_DIR/account/all_users.txt"
pw group show -a > "$BASE_DIR/account/all_groups.txt"

# 系統日誌
tail -n 200 /var/log/messages > "$BASE_DIR/log/messages.txt" 2>/dev/null
[ -f /var/log/auth.log ] && tail -n 200 /var/log/auth.log > "$BASE_DIR/log/authlog.txt"
[ -f /var/log/security ] && tail -n 200 /var/log/security > "$BASE_DIR/log/security.txt"
dmesg | tail -n 200 > "$BASE_DIR/log/dmesg.txt"

echo "Completed! FreeBSD information saved at：$BASE_DIR"