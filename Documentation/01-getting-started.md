# Getting Started with Querencia Linux

> *"Where Linux Feels at Home"*

Welcome to Querencia Linux — an atomic, immutable desktop built on AlmaLinux 10 with the MATE Desktop Environment.

## What is Querencia Linux?

Querencia Linux is an **immutable desktop operating system**. That means the root filesystem (`/usr`, `/etc` defaults, system binaries) is **read-only** — you can't break it with a stray `sudo rm` or a bad package install. The system image is built as a container and deployed atomically via [bootc](https://containers.github.io/bootc/).

Here's what that gives you:

- **Automatic updates** — the system checks for a new image every 6 hours, stages it, and you get it on your next reboot.
- **Instant rollback** — if an update causes problems, roll back to the previous image in seconds (`ujust rollback`).
- **Reproducibility** — every Querencia Linux machine running the same image is identical at the system level.

Software you install goes through three channels, all of which live outside the immutable root:

| Channel | What it's for | Example |
|---|---|---|
| **Flatpak** | Desktop apps (GUI) | LibreOffice, Thunderbird, GIMP |
| **Micromamba** | CLI tools & dev environments | ripgrep, Python, Node.js |
| **Distrobox** | Full mutable Linux containers | An Ubuntu or Fedora shell when you need one |

## First Login

When you log in for the first time, a one-time setup runs automatically. Once it completes, the **Welcome Center** opens to guide you through your new system. Here's what the setup does:

1. **XDG directories created** — `Documents`, `Downloads`, `Pictures`, `Music`, `Videos`, and others are set up in your home folder.
2. **Caja bookmarks configured** — the file manager sidebar gets shortcuts to Documents, Downloads, Pictures, Music, and Videos.
3. **Flatpak overrides applied** — GPU access, the BlueMenta theme, and the Adwaita cursor are passed through to Flatpak apps so they look and feel native.
4. **Flathub remote added** — the Flathub app repository is enabled for your user, giving you access to thousands of apps.
5. **Warehouse installed** — [Warehouse](https://flathub.org/apps/io.github.flattool.Warehouse) (a graphical Flatpak store) is installed automatically. Find it in your Applications menu.
6. **Micromamba `base` environment created** — the user-space package manager is ready immediately. Just open a terminal and run `micromamba install <package>`.
7. **Welcome Center shown** — once the setup steps above are finished, the [Welcome Center](#welcome-center) opens automatically, guiding you through first steps, app installation, and system info. If the Welcome Center is unavailable, a desktop notification is shown as fallback.

This setup only runs once. A marker file (`~/.config/querencia-setup-done`) prevents it from running again on subsequent logins.

## Welcome Center

The Welcome Center is a guided introduction to Querencia Linux. It opens automatically on first login and is available anytime from the Applications menu: **System → Welcome to Querencia Linux**.

The Welcome Center is **fully localized in 12 languages** — it automatically matches the language you chose during installation (English, Deutsch, Français, Español, Italiano, Português, Nederlands, Polski, Русский, 日本語, 中文, 한국어).

It includes five pages:

- **Welcome** — version info and a quick "Let's get started!" entry point
- **First Steps** — action cards to customize your desktop (Appearance, App Store, Caja File Manager, MATE Control Center, Firewall, Updates)
- **Installing Software** — how to install apps via Flatpak, Micromamba, and Distrobox on an atomic system
- **System Info** — hardware and software details, copy-to-clipboard, quick ujust commands
- **Help & Links** — links to the website, GitHub, AlmaLinux Wiki, and bug reporting

To stop it from appearing at login, uncheck **"Show at startup"** at the bottom of the window. You can always reopen it from the menu.

## Your Desktop

Querencia Linux uses the **MATE Desktop** — a traditional, lightweight desktop environment that stays out of your way.

### Look & Feel

- **Theme:** BlueMenta (GTK + window borders)
- **Fonts:** Noto Sans 10pt (UI), Noto Sans Bold 10pt (titlebar)
- **Cursor:** Adwaita (consistent across desktop, login screen, and Flatpak apps)
- **Compositing:** enabled by default (for shadows, transparency)

### Workspaces

You have **4 virtual workspaces** out of the box:

- `Ctrl+Alt+←` / `Ctrl+Alt+→` — switch between workspaces
- `Ctrl+Alt+Shift+←` / `Ctrl+Alt+Shift+→` — move the current window to another workspace

### Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Super+L` | Lock screen |
| `Super+D` | Show desktop (minimize all windows) |
| `Super+E` | Open file manager (Caja) |
| `Ctrl+Alt+T` | Open terminal |
| `Alt+F1` | Open application menu |
| `Alt+Tab` | Switch windows |

### Screenshots

| Shortcut | Action |
|---|---|
| `Print` | Capture full screen (saved to file) |
| `Alt+Print` | Capture active window (saved to file) |
| `Shift+Print` | Select an area to capture (saved to file) |

### Night Mode

**Redshift** runs in the system tray and automatically adjusts your screen's color temperature based on the time of day. It uses [BeaconDB](https://beacondb.net/) for WiFi-based geolocation (a privacy-friendly alternative to Google's location services). No configuration needed — it just works.

### Key Applications

| App | What it is |
|---|---|
| **Caja** | File manager (list view by default, bookmarks in the sidebar) |
| **MATE Terminal** | Terminal emulator with Dracula color scheme and unlimited scrollback |
| **Firefox** | Web browser (pre-installed as an RPM for best system integration) |
| **Warehouse** | Graphical Flatpak store — browse and install apps |
| **pavucontrol** | Audio volume control (PipeWire under the hood) |

### Handy Shell Tricks

- **`open <file>`** — works like macOS. Opens any file in its default application (it's an alias for `xdg-open`).
- **`fastfetch`** — displays system info (distro, kernel, CPU, GPU, memory, etc.) in a nice summary.

## Keyboard Layout

Your keyboard layout is **whatever you selected during installation** — it is not hardcoded. Querencia Linux respects the Anaconda installer's language and keyboard choices.

To change your keyboard layout after installation:

**System → Preferences → Hardware → Keyboard → Layouts**

You can add multiple layouts and switch between them from the panel.

## Installing Software

Since the root filesystem is read-only, you don't use `dnf install` on the desktop. Instead:

### Flatpak (GUI Apps)

```
# Search for an app
flatpak search gimp

# Install an app
flatpak install flathub org.gimp.GIMP

# Or use Warehouse (graphical store) from the Applications menu
```

A curated set of recommended apps can be installed in one shot:

```
ujust install-essentials
```

This installs Thunderbird, LibreOffice, Calculator, Evince (PDF viewer), Flatseal (permission manager), Celluloid (video player), and Simple Scan. (Firefox is already pre-installed as a system RPM.)

### Micromamba (CLI Tools & Dev Environments)

Micromamba is a fast, minimal conda-compatible package manager. The `base` environment is created on first login and always active in your terminal.

```
# Install a package into base
micromamba install ripgrep

# Search for packages
micromamba search nodejs

# Create a separate environment for a project
micromamba create -n myproject -c conda-forge python=3.12 pip
micromamba activate myproject
```

There are also ujust shortcuts:

```
ujust mamba-install ripgrep bat fd-find    # Install packages into base
ujust mamba-install-tools                  # Install a curated set of CLI tools
ujust mamba-python 3.12                    # Create a Python dev environment
ujust mamba-node 22                        # Create a Node.js dev environment
```

### Distrobox (Full Linux Containers)

Need a full mutable Linux environment? Distrobox gives you a containerized shell that integrates seamlessly with your desktop (clipboard, files, even GUI apps).

```
ujust distrobox-alma       # Create an AlmaLinux 10 container
ujust distrobox-fedora     # Create a Fedora container
ujust distrobox-ubuntu     # Create an Ubuntu container

distrobox enter alma       # Enter the container
```

Inside the container, you have full `dnf install` / `apt install` access.

## System Updates

Updates happen **automatically every 6 hours**. When a new image is available, it's staged in the background. You get the update on your next reboot. A desktop notification tells you when a new image has been staged.

You can also manage updates manually:

| Command | What it does |
|---|---|
| `ujust update` | Update everything (bootc image + Flatpak apps) |
| `ujust status` | Show the current bootc image status |
| `ujust rollback` | Roll back to the previous image (takes effect on reboot) |
| `ujust update-status` | Check the auto-update timer and recent log |
| `ujust update-disable` | Disable automatic updates |
| `ujust update-enable` | Re-enable automatic updates |

Updates are skipped automatically when you're on a metered connection.

## Getting Help

The `ujust` command is your Swiss Army knife. It provides shortcuts for common tasks:

| Command | What it does |
|---|---|
| `ujust --list` | Show all available recipes |
| `ujust info` | Display system info (fastfetch) |
| `ujust status` | Show bootc image status (current + staged) |
| `ujust device-info` | Collect system diagnostics and upload to a pastebin (shareable URL for support) |
| `ujust gpu-info` | Show GPU driver, Vulkan, and VA-API status |
| `ujust disk` | Show disk usage |
| `ujust memory` | Show memory usage |
| `ujust firewall-status` | Show firewall rules |
| `ujust printer-setup` | Open printer configuration |
| `ujust mamba-setup` | Show Micromamba status |

### If Something Goes Wrong

1. **Roll back:** `ujust rollback` then reboot — you're back on the previous working image.
2. **Check logs:** `ujust logs` shows the last 50 lines from the current boot session.
3. **Collect diagnostics:** `ujust device-info` gathers system info and gives you a shareable URL you can send to someone helping you.
4. **Ask for help:** Open an issue at [github.com/endegelaende/querencia-linux](https://github.com/endegelaende/querencia-linux/issues) with the diagnostics URL.