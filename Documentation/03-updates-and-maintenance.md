# Updates & Maintenance

Querencia Linux keeps itself up to date automatically — but you're always in control. This guide covers how updates work, how to roll back if something goes wrong, and how to keep your system healthy.

---

## How Updates Work

Querencia Linux uses **atomic image-based updates** via [bootc](https://containers.github.io/bootc/). This is fundamentally different from traditional package-by-package updates — it's more like how phones or Chromebooks update:

- Updates download a **complete new system image** in the background
- The new image is **staged alongside** the current one
- On **reboot**, the new image becomes active
- The **old image is always kept** for rollback
- If something goes wrong, you can boot the previous image from GRUB

Your files, settings, Flatpak apps, and Micromamba environments are never touched by system updates — they live in `/var/home` which is separate from the immutable root filesystem.

---

## Automatic Updates

Automatic updates are **enabled by default** and run every 6 hours. They handle both the base system image (bootc) and your Flatpak apps.

**What happens automatically:**

1. `bootc upgrade` checks for a new system image and stages it
2. Flatpak apps are updated (both system and user scope)
3. If a new image was staged, you get a **desktop notification** telling you to reboot
4. On **metered connections** (mobile hotspot, etc.), updates are **skipped** automatically

**Managing auto-updates:**

```
ujust update-status       # check timer status and recent log
ujust update-disable      # disable automatic updates
ujust update-enable       # re-enable automatic updates
ujust update-now          # trigger an update right now (without waiting)
```

---

## Manual Updates

If you prefer to update on your own schedule, or want to run a quick update right now:

```
ujust update              # full update: bootc image + Flatpak apps
ujust update-system       # update only the bootc system image
ujust update-flatpak      # update only Flatpak apps
```

After a system image update, **reboot** to activate the new image:

```
sudo reboot
```

> **Tip:** Flatpak updates take effect immediately — no reboot needed. Only bootc image updates require a reboot.

---

## Rollback

If something breaks after an update, rolling back is simple and instant:

### From the command line

```
ujust rollback            # switch to the previous image
sudo reboot               # activate it
```

### From the GRUB boot menu

During boot, the GRUB menu shows both the **current** and **previous** image. Select the older entry to boot it. This is especially useful if the new image won't boot at all.

> **Note:** Querencia always keeps exactly one previous image. After a rollback and reboot, the "broken" image is still available as the alternate entry — so you can switch back if needed.

---

## Maintenance

### Full maintenance

```
ujust maintenance         # runs update + clean in one step
```

### Cleaning up

```
ujust clean               # clean journal logs (>7 days), unused Flatpak runtimes, podman cache
ujust clean-flatpak       # remove only unused Flatpak runtimes
ujust mamba-clean         # clean Micromamba download cache
```

### SSD TRIM

TRIM runs automatically once a week via `fstrim.timer`. To run it manually:

```
ujust trim                # run SSD TRIM now
```

### Disk and memory

```
ujust disk                # check disk usage (/, /boot, /var/home)
ujust memory              # check RAM and swap usage
```

---

## ZRAM (Compressed Swap)

Querencia uses **ZRAM** instead of traditional disk-based swap. ZRAM creates a compressed swap area in RAM, which is much faster than swapping to disk and produces zero SSD wear.

| Setting | Value |
|---------|-------|
| Size | 50% of physical RAM |
| Compression | zstd |
| Swap priority | 100 |
| `vm.swappiness` | 180 (tuned for ZRAM — higher values are correct here) |

> **Why swappiness 180?** Traditional disk swap benefits from low swappiness because disk I/O is slow. ZRAM swap is backed by RAM with compression, so there's no disk penalty. A high swappiness value tells the kernel to use ZRAM early, which actually improves performance by freeing up RAM for caches.

Check ZRAM status:

```
swapon --show
```

You should see something like `/dev/zram0` with type `partition`.

---

## System Info

```
ujust info                # system overview (fastfetch)
ujust status              # bootc image status (current + staged + rollback images)
ujust services            # list running systemd services
ujust logs                # last 50 lines of current boot session logs
ujust bios-info           # BIOS/UEFI information
ujust device-info         # full system diagnostics (useful for troubleshooting)
```

### GPU info (AMD variant)

```
ujust gpu-info            # driver, Vulkan, VA-API status
ujust gpu-monitor         # live GPU monitoring (temp, clock, VRAM, power)
ujust gpu-sensors         # one-shot sensor readings
```

---

## Frequently Asked Questions

### Do I need to do anything for updates?

No. Updates happen automatically every 6 hours. Just reboot when you see the notification (or whenever it's convenient — there's no rush).

### Will updates break my files?

No. Your home directory (`/var/home`) is completely separate from the system image. Updates only replace the immutable root filesystem.

### How much bandwidth do updates use?

bootc uses **delta downloads** — only the layers that changed are downloaded, not the entire image. Typical updates are a few hundred MB, not multiple GB.

### Can I install RPM packages with `dnf`?

No. The root filesystem is read-only. Use **Flatpak** for graphical apps, **Micromamba** for CLI tools, or **Distrobox** for a full mutable Linux environment. See the [Installing Software](02-installing-software.md) guide.

### What if auto-update stages an image I don't want?

Run `ujust rollback` before rebooting, or simply select the previous image from the GRUB menu during boot.

### How do I check which image I'm running?

```
ujust status
```

Or check directly:

```
cat /etc/os-release
```

The `PRETTY_NAME` field shows the Querencia version and GPU variant (AMD or NVIDIA).