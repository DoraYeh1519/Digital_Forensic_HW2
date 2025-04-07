#!/bin/sh

if [ "$(id -u)" -ne 0 ]; then
    echo "請使用 sudo 執行。"
    exit 1
fi

OS="unknown"

# Detect using /etc/os-release if present (Linux)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu|debian)
            OS="debian/ubuntu"
            ;;
        centos|rhel|rocky|almalinux)
            OS="centos"
            ;;
    esac
# FreeBSD
elif [ "$(uname -s)" = "FreeBSD" ]; then
    OS="freebsd"
fi

echo "偵測到系統為：$OS"

case "$OS" in
    debian/ubuntu)
        bash collect_ubuntu_debian.sh
        ;;
    centos)
        bash collect_centos.sh
        ;;
    freebsd)
        sh collect_freebsd.sh
        ;;
    *)
        echo "❌ 無法辨識的作業系統，請手動執行對應腳本"
        exit 1
        ;;
esac