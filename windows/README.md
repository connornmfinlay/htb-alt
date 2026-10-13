# Windows targets (Active Directory practice)

Windows cannot run inside a Linux container, so the Windows half of the lab
uses **KVM/libvirt virtual machines** instead of podman. Your host already has
`/dev/kvm`, `qemu` and `virsh`, so it is capable of this.

Run the readiness check first:

```bash
./windows/setup-check.sh
```

Windows media is Microsoft's to distribute. Use the **free time-limited
evaluation images** Microsoft publishes for exactly this kind of testing — do
not pirate retail Windows:

- Windows Server evaluation ISOs: Microsoft Evaluation Center
- Windows 10/11 Enterprise evaluation ISOs: Microsoft Evaluation Center
- Pre-built eval VM images are also offered for several hypervisors

## Option A — a single Windows target VM

Good for standalone Windows service / privesc practice. Build it with
`virt-install` from an evaluation ISO and attach it to an isolated libvirt
network so it mirrors the podman lab's isolation. Keep a clean snapshot right
after install so you can roll back between practice runs:

```bash
sudo virsh snapshot-create-as win-target clean "fresh install"
sudo virsh snapshot-revert   win-target clean
```

## Option B — GOAD, a full vulnerable AD lab (the HTB-like one)

[**GOAD (Game of Active Directory)**](https://github.com/Orange-Cyberdefense/GOAD)
is the standard open-source vulnerable Active Directory environment — a
multi-host Windows domain built specifically for safe, legal AD attack
practice. It is the closest free equivalent to HTB's Pro Labs / AD boxes.

It provisions several Windows VMs (domain controllers + member servers) with
realistic misconfigurations, driven by Vagrant + Ansible. On this Fedora host
the `vagrant-libvirt` provider is the right backend (no VirtualBox needed):

```bash
sudo dnf install vagrant ansible
vagrant plugin install vagrant-libvirt
git clone https://github.com/Orange-Cyberdefense/GOAD
cd GOAD
# follow its README: choose a lab (GOAD / GOAD-Light), provider 'libvirt', then
./goad.sh -t install -l GOAD -p libvirt
```

GOAD-Light is the smaller footprint (2 VMs) if RAM is tight.

## Reaching Windows targets from the Kali attacker

The podman attacker and the libvirt VMs sit on different virtual networks by
default. To let the Kali box reach the Windows lab, either:

- bridge the libvirt lab network so the attacker's host-published ports can
  route to it, or
- run your attacker tooling from the host against the libvirt network, or
- give the attacker container a second interface on the libvirt bridge.

Keep both sides **isolated from your home LAN and the internet** — these are
intentionally vulnerable machines.

## Track your AD progress

The `ad` module in the tracker is ready for this side of the lab:

```bash
./tracker/track list ad
./tracker/track start ad-enum
```
