#!/usr/bin/env bash
# Checks whether this host is ready to run Windows target VMs for AD practice.
# Windows can't run in a Linux container, so the Windows side of the lab uses
# KVM/libvirt VMs instead of podman.
set -euo pipefail
ok(){ printf '\033[32m[+]\033[0m %s\n' "$*"; }
no(){ printf '\033[31m[x]\033[0m %s\n' "$*"; }
nn(){ printf '\033[33m[!]\033[0m %s\n' "$*"; }

echo "== Windows-lab readiness =="

[ -e /dev/kvm ] && ok "/dev/kvm present (hardware virtualization)" || no "/dev/kvm missing - enable VT-x/AMD-V in firmware"

if command -v virsh >/dev/null; then ok "libvirt (virsh) installed"; else
  no "libvirt not installed  ->  sudo dnf install libvirt virt-install virt-manager qemu-kvm"; fi
command -v virt-install >/dev/null && ok "virt-install present" || nn "virt-install missing (needed to build VMs)"
command -v vagrant       >/dev/null && ok "vagrant present (needed for GOAD)" || nn "vagrant missing  ->  sudo dnf install vagrant  (+ vagrant-libvirt plugin)"
command -v ansible       >/dev/null && ok "ansible present (needed for GOAD provisioning)" || nn "ansible missing  ->  sudo dnf install ansible"

if systemctl is-active --quiet libvirtd 2>/dev/null; then ok "libvirtd running"; else
  nn "libvirtd not active  ->  sudo systemctl enable --now libvirtd"; fi

if groups | grep -qw libvirt; then ok "user in 'libvirt' group"; else
  nn "add yourself to libvirt group  ->  sudo usermod -aG libvirt \"$USER\" (re-login after)"; fi

echo
echo "RAM / disk guidance:"
echo "  single Windows target : ~4 GB RAM, ~40 GB disk"
echo "  GOAD full AD lab (3-5 VMs): 24+ GB RAM recommended, ~120 GB disk"
free -g | awk '/Mem/{printf "  this host has %s GB RAM\n",$2}'
df -h --output=avail "$HOME" | tail -1 | awk '{printf "  free in $HOME: %s\n",$1}'
