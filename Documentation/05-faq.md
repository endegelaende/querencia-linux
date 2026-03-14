# Frequently Asked Questions

## General

### What is Querencia Linux?

An atomic, immutable desktop Linux distribution based on AlmaLinux 10 with MATE Desktop. The name "Querencia" (Spanish) means a place where you feel safe and at home.

### What does "atomic" / "immutable" mean?

The root filesystem (`/usr`, `/etc`) is read-only at runtime. You can't break the system by accidentally deleting system files or installing incompatible packages. Updates replace the entire system image atomically — either the update succeeds completely or nothing changes.

### Is this based on Fedora?

No. Querencia Linux is based on **AlmaLinux 10** (RHEL-compatible). The MATE Desktop packages come from our own COPR repository.

### Which GPU variant should I use?

- **AMD** (`querencia-linux`) — if you have an AMD/Intel GPU or no dedicated GPU
- **NVIDIA** (`querencia-linux-nvidia`) — if you have an NVIDIA GPU

### Can I switch between AMD and NVIDIA variants?

Yes: `sudo bootc switch ghcr.io/endegelaende/querencia-linux-nvidia:latest` (or the AMD image URL). Reboot to activate.

---

## Software

### Why can't I use `sudo dnf install`?

The root filesystem is read-only. Use Flatpak for GUI apps, Micromamba for CLI tools, or Distrobox for full mutable environments. See [Installing Software](02-installing-software.md).

### Where is the app store?

**Warehouse** — installed automatically on first login. Find it in Applications → System Tools → Warehouse. Or: `ujust open-store`.

### Can I install Chrome/Chromium?

Yes, via Flatpak: `flatpak install flathub com.google.Chrome`

### Can I install Steam?

Yes: `flatpak install flathub com.valvesoftware.Steam`

### Can I install VS Code?

Yes: `flatpak install flathub com.visualstudio.code`

### What's the difference between Micromamba and Distrobox?

- **Micromamba** — installs individual packages into `~/micromamba`. Best for CLI tools and languages (Python, Node, Rust). No root needed. Fast.
- **Distrobox** — creates full Linux containers (Fedora, Ubuntu, AlmaLinux). Best when you need `dnf install` or `apt install` for complex dependency chains. Shares your home directory.

---

## System

### How do I update?

`ujust update` — or it happens automatically every 6 hours. See [Updates & Maintenance](03-updates-and-maintenance.md).

### How do I roll back a bad update?

`ujust rollback` then reboot. Or select the previous image from the GRUB boot menu.

### How do I check what version I'm running?

`cat /etc/os-release` or `ujust status`

### Why is my swap showing as ZRAM?

Querencia uses compressed RAM as swap (ZRAM) instead of a disk swap partition. It's faster and doesn't wear out your SSD. `swapon --show` to verify.

### How do I change my keyboard layout?

System → Preferences → Hardware → Keyboard → Layouts. The initial layout was set during installation.

### How do I change the theme?

- Dark: `ujust mate-dark`
- Light: `ujust mate-light`
- Or manually: System → Preferences → Appearance

### Where are my files?

Your home directory (`/home/username`) is on a regular writable partition. Only the system directories are read-only. Documents, Downloads, Pictures etc. all work normally.

### Why does SELinux show alerts?

SELinux is in Enforcing mode with the troubleshooter enabled. If you see an alert, it means something tried to do something the security policy doesn't allow. Most alerts are informational and don't affect functionality. If an app doesn't work, check the alert details.

### How do I connect my iPhone?

Plug it in via USB. Trust the device on the iPhone when prompted. It should appear in Caja (file manager). If not: `idevicepair pair` then try again.

### How do I set up a printer?

`ujust printer-setup` or System → Administration → Printing. Network printers on your local network should be auto-discovered. For `ping printer.local` to work, mDNS is already configured.

### How do I control my monitor's brightness from the desktop?

External monitors via HDMI/DP: `ddcutil setvcp 10 70` (set brightness to 70%). Laptop screens: use the laptop's function keys.

### What is `ujust`?

A command-line shortcut tool. Run `ujust --list` to see all available commands, or check the [full command reference in the README](../README.md#all-ujust-commands).