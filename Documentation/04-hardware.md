# Hardware Support

Querencia Linux comes with drivers and firmware pre-installed for a wide range of
hardware. This guide covers what's included and how to verify things are working.

---

## GPU

Querencia Linux ships in two variants — **AMD** (default) and **NVIDIA** — each with a
purpose-built GPU stack. Pick the one that matches your graphics card.

### AMD (Default Variant)

Image: `ghcr.io/endegelaende/querencia-linux:latest`

The AMD variant includes everything you need out of the box:

- **Mesa** — OpenGL and Vulkan (RADV) drivers
- **VA-API** — hardware video decoding (Firefox uses this automatically)
- **linux-firmware** — GPU microcode and firmware blobs
- **amdgpu kernel driver** — modern kernel driver for GCN and RDNA GPUs
- **Xorg DDX drivers** — `xorg-x11-drv-amdgpu` (modern) and `xorg-x11-drv-ati` (legacy)

**Legacy AMD GPUs** (HD 7000 / R5 200 / R7 200 / R9 200 / R7 300 / R9 300 series) are
supported via the `amdgpu` kernel driver with GCN 1.0 (Southern Islands) and GCN 2.0
(Sea Islands) support enabled. The older `radeon` driver is disabled for these chips so
that `amdgpu` handles them instead — this is configured automatically.

**Power management** is fully unlocked (`ppfeaturemask=0xffffffff`), which means you can
adjust fan curves, undervolt, and tweak power limits if you want to. The default behavior
is automatic and safe — you only need to touch this if you're a power user.

#### Check your GPU

```bash
ujust gpu-info            # driver, Vulkan, VA-API status
ujust gpu-sensors         # one-shot sensor readings (temp, power, VRAM)
ujust gpu-monitor         # live monitoring (Ctrl+C to exit)
ujust gpu-test            # run Vulkan test (vkcube)
```

#### Power profiles (AMD only)

```bash
ujust gpu-performance     # high performance mode
ujust gpu-powersave       # power saving mode
ujust gpu-auto            # automatic (default)
```

These set the kernel power profile for the GPU. The default (`auto`) is fine for most
use cases — the GPU clocks up under load and idles quietly otherwise.

### NVIDIA Variant

Image: `ghcr.io/endegelaende/querencia-linux-nvidia:latest`

The NVIDIA variant uses **AlmaLinux's official NVIDIA support** — pre-compiled,
Secure Boot signed kernel modules. No manual driver installation needed.

Included:

- **nvidia-open-kmod** — open-source NVIDIA kernel module (Secure Boot signed by AlmaLinux)
- **nvidia-driver** — NVIDIA proprietary userspace (libGL, Xorg driver, settings)
- **nvidia-driver-cuda** — CUDA support and `nvidia-smi`
- **switcheroo-control** — hybrid GPU switching for laptops with Intel/AMD iGPU + NVIDIA dGPU
- **Mesa** — fallback drivers for non-NVIDIA outputs and software rendering

The `nouveau` driver is blacklisted at every level (modprobe, initramfs, kernel command
line) to prevent conflicts. NVIDIA DRM modesetting is enabled for smooth VT switching
and proper suspend/resume.

#### Verify NVIDIA is working

```bash
nvidia-smi                # GPU status, temperature, driver version
lsmod | grep nvidia       # should show: nvidia, nvidia_modeset, nvidia_uvm, nvidia_drm
lsmod | grep nouveau      # should be empty (nouveau is blacklisted)
cat /proc/cmdline         # should contain: modprobe.blacklist=nouveau nvidia-drm.modeset=1
```

#### Hybrid GPU laptops

If your laptop has both an integrated GPU (Intel or AMD) and a discrete NVIDIA GPU,
`switcheroo-control` is enabled automatically. Desktop applications can offer a
"Launch using Discrete GPU" option. You can also force an app to use the NVIDIA GPU:

```bash
switcherooctl launch <command>
```

### Virtual Machines

VM display drivers are included out of the box: **QXL**, **VESA**, **fbdev**, and
**spice-vdagent**. Querencia Linux works in QEMU/KVM, VirtualBox, and VMware without
any extra configuration.

---

## Audio

- **PipeWire** with PulseAudio and ALSA compatibility layers
- **WirePlumber** session manager
- **pavucontrol** for GUI volume control (System → Sound & Video → PulseAudio Volume Control)

Audio runs as a per-user service — it starts automatically when you log in. No setup
needed.

If audio isn't working, check that PipeWire is running:

```bash
systemctl --user status pipewire.socket
systemctl --user status wireplumber.service
```

---

## Printing

- **CUPS** is pre-installed and socket-activated (starts on demand, not wasting resources when idle)
- **Drivers:** Gutenprint + Foomatic (covers the vast majority of printers)
- **Network discovery:** Avahi/mDNS is configured — network printers are discovered automatically

### Setup

```bash
ujust printer-setup       # opens the graphical printer configuration tool
ujust printer-status      # shows CUPS status and configured printers
```

Or go to **System → Administration → Printing** in the menu.

### Network printers

mDNS name resolution is configured in `nsswitch.conf`, so `.local` hostnames work
system-wide. If your printer advertises itself as `myprinter.local`, you can reach it
from any application — including the browser at `http://myprinter.local:631`.

This also means `ping somedevice.local` and `ssh pi.local` work out of the box.

---

## Scanning

- **SANE** backends are installed for USB and network scanners
- Install **Simple Scan** for a graphical scanning interface:

```bash
ujust install-essentials    # includes Simple Scan along with other recommended apps
```

Or install it individually:

```bash
flatpak install flathub org.gnome.SimpleScan
```

Check if your scanner is detected:

```bash
scanimage -L
```

If your scanner doesn't show up, make sure it's connected via USB or on the same
network, and that the SANE backend for your model is supported. Most major brands
(HP, Epson, Canon, Brother) work.

---

## Bluetooth

- **BlueZ** — the Linux Bluetooth stack
- **Blueman** — graphical Bluetooth manager (system tray icon)

Bluetooth is enabled by default. Click the Bluetooth icon in the system tray to pair
devices, or use the command line:

```bash
bluetoothctl scan on      # discover nearby devices
bluetoothctl pair <MAC>   # pair a device
bluetoothctl connect <MAC>
```

---

## WiFi & Networking

- **NetworkManager** — manages all network connections
- **NM applet** — system tray icon for quick access to WiFi, VPN, and wired connections
- **WiFi** — `NetworkManager-wifi` is pre-installed; most WiFi chipsets work out of the box

### VPN

Both **OpenVPN** and **WireGuard** are included with NetworkManager plugins, so they
appear directly in the network menu:

- **OpenVPN:** Import `.ovpn` files via the NM applet → VPN Connections → Configure VPN
- **WireGuard:** The kernel module is built-in (Linux 5.6+). Import configs via NM or use
  `wg-quick` from `wireguard-tools`

### Firewall

**firewalld** is enabled by default with sensible defaults (public zone, most ports closed).

```bash
ujust firewall-status          # current rules and allowed services
ujust firewall-allow ssh       # open a service
ujust firewall-block ssh       # close it
```

---

## USB-C Docks & USB Ethernet

Realtek USB Ethernet adapters — the kind found in most USB-C docks — are auto-configured
via udev rules. This covers common docks from Lenovo, TP-Link, Samsung, and generic
Realtek-based dongles.

The `usb_modeswitch` tool is installed to handle adapters that need a mode switch before
they function as network devices. This all happens automatically when you plug in.

---

## Apple USB SuperDrive

The Apple USB SuperDrive requires a special initialization command before it will read
discs. A udev rule handles this automatically — just plug it in and it works.

---

## iOS Devices

iPhones and iPads can be mounted and accessed for file transfer:

- **libimobiledevice** — protocol library for iOS communication
- **ifuse** — FUSE filesystem for mounting iOS devices
- **usbmuxd** — USB multiplexing daemon (starts automatically)

Plug in your device, trust the computer on the iOS prompt, and it should appear in
Caja (the file manager).

---

## Monitor Control

**ddcutil** is installed for controlling external monitors over DDC/CI — the protocol
that lets your computer talk to your monitor's on-screen display.

```bash
ddcutil detect                # list connected monitors
ddcutil getvcp 10             # read current brightness
ddcutil setvcp 10 50          # set brightness to 50%
ddcutil setvcp 12 75          # set contrast to 75%
```

This works with most monitors connected via HDMI or DisplayPort. Some monitors need
DDC/CI enabled in their OSD settings first.

> **Note:** ddcutil requires the `i2c-dev` kernel module. If `ddcutil detect` shows
> nothing, try `sudo modprobe i2c-dev` and run it again.

---

## Power Management

**powertop** is included for analyzing and tuning power consumption on laptops:

```bash
sudo powertop                 # interactive power analysis
sudo powertop --auto-tune     # apply all recommended power-saving settings
```

The system also uses **ZRAM** (compressed swap in RAM) with zstd compression at 50% of
RAM. Together with a swappiness of 180 (tuned for ZRAM — no disk penalty), this gives
you effective memory expansion without touching your SSD. Check it with:

```bash
swapon --show                 # should show a /dev/zram0 device
```

---

## Night Mode

**Redshift** is installed for reducing blue light in the evening. Find **Redshift** in
the application menu (System Tray), or run:

```bash
redshift-gtk &                # starts with a system tray icon
```

Redshift adjusts your screen color temperature based on your location and time of day.
It needs location access to work — you can configure coordinates in
`~/.config/redshift.conf` if automatic detection doesn't work.

---

## Troubleshooting

### Something isn't working?

A few things to check:

| Symptom | Try this |
|---|---|
| No GPU acceleration | `ujust gpu-info` — check if the driver is loaded |
| No sound | `pavucontrol` — check output device and volume |
| WiFi not showing | `nmcli device status` — check if the adapter is recognized |
| Bluetooth not pairing | `systemctl status bluetooth` — is the service running? |
| Printer not found | `ujust printer-status` — is CUPS running? Is the printer on the network? |
| Scanner not detected | `scanimage -L` — does SANE see the device? |
| Monitor brightness control not working | `ddcutil detect` — is DDC/CI enabled on the monitor? |
| USB-C dock Ethernet not working | `dmesg | tail -20` — check for USB device recognition |
| SELinux blocking something | Check the SELinux Troubleshooter notifications (pre-installed) |

### Checking system logs

```bash
ujust logs                    # last 50 lines of current boot
journalctl -b -p err          # errors only from current boot
dmesg | grep -i firmware      # firmware loading messages
dmesg | grep -i error         # hardware errors
```

### Reporting issues

If your hardware isn't supported, open an issue at
[github.com/endegelaende/querencia-linux/issues](https://github.com/endegelaende/querencia-linux/issues)
with the output of:

```bash
ujust gpu-info                # GPU details
lspci -nn                     # all PCI devices with vendor/device IDs
lsusb                         # all USB devices
uname -r                      # kernel version
cat /etc/os-release           # image version
```
