# Querencia Linux — User Documentation

> **Querencia Linux** — "Where Linux Feels at Home"
>
> An atomic, immutable Linux desktop built on AlmaLinux 10 with MATE Desktop.

## Documentation

| Guide | Description |
|---|---|
| [Getting Started](01-getting-started.md) | First steps after installation — your desktop, keyboard, shortcuts |
| [Installing Software](02-installing-software.md) | Flatpak, Micromamba, Distrobox — how to install apps and tools |
| [Updates & Maintenance](03-updates-and-maintenance.md) | Automatic updates, rollback, cleanup, ZRAM, system info |
| [Hardware Support](04-hardware.md) | GPU (AMD/NVIDIA), printing, scanning, audio, Bluetooth, WiFi, USB-C, monitors |
| [FAQ](05-faq.md) | Frequently asked questions |

## Quick Reference

```
ujust --list              # show all available commands
ujust update              # update system + Flatpak
ujust rollback            # roll back to previous image
ujust install-essentials  # install recommended apps
ujust info                # system info
```

## Links

- **Website:** [querencialinux.org](https://querencialinux.org)
- **GitHub:** [endegelaende/querencia-linux](https://github.com/endegelaende/querencia-linux)
- **AMD Image:** `ghcr.io/endegelaende/querencia-linux:latest`
- **NVIDIA Image:** `ghcr.io/endegelaende/querencia-linux-nvidia:latest`
