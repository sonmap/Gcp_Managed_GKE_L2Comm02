#!/usr/bin/env bash
set -euo pipefail

# PoC helper: export the repository's mnt/ directory from the current VM via NFSv4.
# Production recommendation: use managed Filestore rather than the VM root disk.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GIT_MNT="$REPO_ROOT/mnt"
NFS_ROOT="${NFS_ROOT:-/srv/l2comm-nfs}"

if [[ ! -d "$GIT_MNT" ]]; then
  echo "ERROR: Git mnt directory not found: $GIT_MNT"
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-kernel-server

mkdir -p "$NFS_ROOT"

if ! mountpoint -q "$NFS_ROOT"; then
  mount --bind "$GIT_MNT" "$NFS_ROOT"
fi

FSTAB_LINE="$GIT_MNT $NFS_ROOT none bind 0 0"
grep -Fqx "$FSTAB_LINE" /etc/fstab || echo "$FSTAB_LINE" >> /etc/fstab

# Read-only source export. Git pull on the VM updates the same backing directory.
EXPORT_LINE="$NFS_ROOT *(ro,sync,no_subtree_check,root_squash,fsid=0)"
if grep -qE "^[[:space:]]*$NFS_ROOT[[:space:]]" /etc/exports; then
  sed -i "\|^[[:space:]]*$NFS_ROOT[[:space:]]|c\$EXPORT_LINE" /etc/exports
else
  echo "$EXPORT_LINE" >> /etc/exports
fi

exportfs -rav
systemctl enable --now nfs-kernel-server

SERVER_IP="$(hostname -I | awk '{print $1}')"

echo
echo "============================================================"
echo "NFSv4 PoC server ready"
echo "============================================================"
echo "Git source : $GIT_MNT"
echo "NFS bind   : $NFS_ROOT"
echo "Server IP  : $SERVER_IP"
echo "Client path: /"
echo "Mode       : read-only"
echo "Port       : TCP 2049"
echo "============================================================"
echo
echo "GKE Pod CIDR 100.64.128.0/19 must be allowed to TCP/2049 on this VM."
