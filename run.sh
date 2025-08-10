#!/bin/bash
set -e

# Direktori kerja
WORKDIR="$HOME/firecracker-alpine"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Cek firecracker
if ! command -v firecracker &>/dev/null; then
    echo "[!] Firecracker belum terinstall. Silakan install dulu."
    exit 1
fi

# Download kernel dan rootfs kalau belum ada
if [ ! -f hello-vmlinux.bin ]; then
    echo "[*] Downloading kernel..."
    wget https://s3.amazonaws.com/spec.ccfc.min/img/hello/kernel/hello-vmlinux.bin
fi

if [ ! -f hello-rootfs.ext4 ]; then
    echo "[*] Downloading rootfs..."
    wget https://s3.amazonaws.com/spec.ccfc.min/img/hello/fsfiles/hello-rootfs.ext4
fi

# Hapus socket lama jika ada
SOCK=/tmp/firecracker.socket
[ -e "$SOCK" ] && rm "$SOCK"

echo "[*] Menjalankan Firecracker..."
# Jalankan Firecracker di background
sudo firecracker --api-sock "$SOCK" &
FCPID=$!

# Tunggu socket siap
sleep 1

echo "[*] Mengatur kernel..."
curl --silent --unix-socket "$SOCK" -i \
    -X PUT 'http://localhost/boot-source' \
    -H 'Content-Type: application/json' \
    -d '{
        "kernel_image_path": "./hello-vmlinux.bin",
        "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
    }' >/dev/null

echo "[*] Mengatur rootfs..."
curl --silent --unix-socket "$SOCK" -i \
    -X PUT 'http://localhost/drives/rootfs' \
    -H 'Content-Type: application/json' \
    -d '{
        "drive_id": "rootfs",
        "path_on_host": "./hello-rootfs.ext4",
        "is_root_device": true,
        "is_read_only": false
    }' >/dev/null

echo "[*] Menyalakan VM..."
curl --silent --unix-socket "$SOCK" -i \
    -X PUT 'http://localhost/actions' \
    -H 'Content-Type: application/json' \
    -d '{
        "action_type": "InstanceStart"
    }' >/dev/null

echo "[+] VM Alpine Linux berjalan! Output ada di terminal Firecracker."
echo "    Gunakan CTRL+A lalu Q untuk keluar dari screen, atau bunuh PID $FCPID."
wait $FCPID
