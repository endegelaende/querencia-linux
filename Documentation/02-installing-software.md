# Installing Software

Querencia Linux is an atomic/immutable system — the root filesystem is read-only.
This makes the system extremely reliable (no broken packages, no half-applied updates),
but it means `sudo dnf install` won't work.

Instead, you have **three ways** to install software, each suited for a different purpose:

| I want to…                       | Use                                                  |
|----------------------------------|------------------------------------------------------|
| Install a GUI app                | `flatpak install flathub <app>` or **Warehouse**     |
| Install a CLI tool               | `micromamba install <tool>`                           |
| Install Python / Node.js / Rust  | `micromamba install python=3.12`                      |
| Use `dnf` or `apt`              | `ujust distrobox-fedora`, then `dnf install` inside  |
| Install recommended apps         | `ujust install-essentials`                           |
| Install recommended CLI tools    | `ujust mamba-install-tools`                          |

---

## GUI Apps → Flatpak

Flatpak is the primary way to install graphical applications. The **Flathub** remote is
configured automatically, and **Warehouse** (a graphical Flatpak store) is installed on
your first login.

### Getting started

Open **Warehouse** from the application menu, or use the terminal:

```bash
flatpak install flathub com.spotify.Client
```

A curated bundle of recommended apps is available via:

```bash
ujust install-essentials
```

This installs: Thunderbird, LibreOffice, Calculator, Evince (PDF viewer),
Flatseal, Celluloid (video player), and Simple Scan.
Firefox is already pre-installed as an RPM for best system integration.

### Common commands

```bash
flatpak search <name>         # Find an app
flatpak list                  # See what's installed
flatpak update                # Update all apps (also runs automatically every 6 hours)
flatpak uninstall <app>       # Remove an app
ujust clean-flatpak           # Remove unused runtimes and free disk space
```

### Tips

- Apps are sandboxed — use **Flatseal** (included in `install-essentials`) to manage
  permissions if an app can't access a folder or device.
- The GTK theme (BlueMenta) and cursor (Adwaita) are automatically shared with Flatpak
  apps so they look consistent with the rest of the desktop.
- If an app doesn't appear in the menu after install, log out and back in.

---

## CLI Tools & Languages → Micromamba

[Micromamba](https://mamba.readthedocs.io/) is a fast, user-space package manager
compatible with conda. It draws from the enormous [conda-forge](https://conda-forge.org/)
repository — thousands of CLI tools, languages, and libraries are available.

The `base` environment is created on first login and is always active in your shell.

### Installing packages

```bash
micromamba install ripgrep bat fd-find eza    # CLI tools
micromamba install python=3.12 pip           # Python
micromamba install nodejs=22 yarn            # Node.js
micromamba install rust cargo                # Rust
micromamba search <anything>                 # Search conda-forge
```

Everything installs into `~/micromamba` — no root required, no system conflicts.

### ujust shortcuts

```bash
ujust mamba-install-tools        # Curated CLI tools bundle (ripgrep, bat, eza, fzf, starship, etc.)
ujust mamba-create myproject     # Create a separate environment
ujust mamba-backup myenv         # Export environment to a YAML file
ujust mamba-restore myenv.yml    # Recreate environment from YAML
```

### Good to know

- The aliases `mamba` and `conda` both work — they point to `micromamba`.
- Environments are isolated. Use `ujust mamba-create <name>` when you want a
  project-specific set of packages that won't interfere with your base tools.
- Micromamba is a single static binary (`/usr/bin/micromamba`). It doesn't need
  Anaconda or Miniconda installed.

---

## Dev Environments → Distrobox

For when you need a full, mutable Linux environment with `dnf` or `apt` —
[Distrobox](https://distrobox.it/) creates lightweight containers that feel like
native shells. Your home directory is shared, so files are accessible from both sides.

### Creating a container

```bash
ujust distrobox-fedora    # Fedora container (dnf)
ujust distrobox-alma      # AlmaLinux container (dnf)
ujust distrobox-ubuntu    # Ubuntu container (apt)
```

### Using a container

```bash
distrobox enter fedora           # Open a shell inside the container
sudo dnf install gcc cmake       # Install anything — it's a full mutable system
exit                             # Back to your host
```

### Managing containers

```bash
ujust distrobox-list             # List all containers
ujust distrobox-upgrade          # Upgrade all containers
```

### Exporting GUI apps from a container

If you install a GUI application inside Distrobox, you can make it appear in your
host application menu:

```bash
distrobox enter fedora
sudo dnf install gimp
distrobox-export --app gimp      # Creates a .desktop file on the host
```

The app will then show up in your MATE menu alongside native apps.

### Third-Party Apps (ujust recipes)

Some proprietary apps have dedicated install recipes that handle the entire Distrobox
setup automatically:

```bash
ujust install-horizon     # Install Omnissa Horizon Client (VDI)
ujust remove-horizon      # Remove Horizon Client and its container
```

The Horizon Client runs in a dedicated AlmaLinux 10 Distrobox with all required
dependencies (GTK3, Firefox for SAML/Workspace ONE authentication). After installation,
it appears in your application menu like a native app.

---

## Why Not dnf?

If you're coming from Fedora, Ubuntu, or a traditional Linux distribution, the read-only
root might feel unfamiliar at first. Here's the reasoning:

- **Reliability** — Your system can't break from a failed package transaction or a
  conflicting dependency. Every update is an atomic image swap.
- **Rollback** — If an update causes problems, reboot and select the previous image
  from the boot menu. Done.
- **Reproducibility** — Every Querencia Linux machine running the same image version is
  identical. No configuration drift.

The three methods above cover every use case that `dnf install` used to serve — they
just separate *system* (read-only image) from *user software* (Flatpak, Micromamba,
Distrobox). After a day or two, it feels completely natural.