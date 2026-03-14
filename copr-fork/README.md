# COPR Fork: MateDesktop-EL10

> Independent MATE Desktop package repository for Querencia Linux (AlmaLinux/EL10).
> All 128 packages under our control — no external runtime dependencies.

## Why Our Own COPR?

MATE Desktop is not available in the standard EL10 repositories. We maintain our own COPR to provide all required packages.

This gives us:
- **Independence** — we control the entire build pipeline, no external dependencies
- **Stability** — we pin to EL10-compatible Fedora branches (`f43`, not rawhide)
- **Automation** — scheduled rebuilds catch security updates from Fedora
- **Transparency** — full audit trail of what goes into our image

## EL10 Compatibility Strategy

### The Problem with `rawhide`

Building MATE packages from Fedora's `rawhide` branch is fragile:

- **rawhide** = Fedora 45+ (bleeding edge, constantly changing)
- **EL10** is based on the Fedora 40/41 dependency stack
- If rawhide bumps a dependency beyond what EL10 provides (e.g. `glib2 >= 2.84`
  when EL10 has `glib2-2.80`), the build **breaks silently**

### Why MATE Specs Are Stable Across Fedora Releases

Looking at the actual spec files (e.g. `mate-desktop.spec`), the differences
between `f41`, `f42`, and `f43` branches are almost exclusively **Mass Rebuild
bumps** (Release tag increments). The source tarballs, BuildRequires, and patches
are identical — MATE 1.28.x uses GTK3, glib2, cairo, and other libraries that
have been stable for years. The MATE upstream project releases only every 6–12
months and does not chase new dependencies.

This means: **the Fedora branch EOL status does not matter much for MATE
packages.** An EOL branch like `f41` still compiles fine against EL10. However,
the branch also receives **no security patches or bugfixes** from Fedora
maintainers after EOL. For desktop components like MATE this is acceptable
(security-critical code is in the base OS, not in the DE), but for libraries
like `libsoup`, `xorg-x11-server`, or `network-manager-applet` we want the
newest bugfixes we can safely build.

### Our Branch Strategy: Pin to `f43`

**Use the newest Fedora stable release** that still builds against EL10.
Currently that is **`f43`** (released Oct 2025, EOL ~Dec 2026).

| Branch | Fedora | Status (Mar 2026) | EL10 Compat | Our Use |
|---|---|---|---|---|
| `rawhide` | 45+ | 🔧 Development | ⚠️ Can break anytime | ❌ Avoid |
| `f44` | 44 | 🔧 Development / Pre-release | ⚠️ Unstable | ❌ Avoid |
| **`f43`** | **43** | ✅ **Current stable** | ✅ **Builds fine** | ✅ **Default** |
| `f42` | 42 | ⚠️ EOL May 2026 | ✅ Builds fine | 🔄 Fallback |
| `f41` | 41 | ❌ EOL Dec 2025 | ✅ Builds fine | 🔄 Fallback |
| `f40` | 40 | ❌ EOL May 2025 | ✅ Builds fine | ❌ Too old |
| `epel10` | EL10 | ✅ Active | ✅ Perfect | ✅ **Preferred when available** |

**Priority order for each package:**
1. `epel10` branch (if it exists) — built specifically for EL10, always prefer
2. `f43` branch — current stable Fedora, receives bugfixes and security patches
3. `f42` branch — fallback if f43 doesn't exist or breaks against EL10
4. `f41` branch — last resort stable branch (EOL, but specs still compile)
5. `rawhide` — absolute last resort, only for packages with no stable branch

### Why Not an Older Branch Closer to EL10's Base?

EL10 is based on Fedora 40/41, so one might think `f41` is the "safest" choice.
But:
- `f41` has been **EOL since Dec 2025** — zero security patches
- The MATE specs on `f43` have the **same source tarballs and deps** as `f41`
  (just rebuilt for the f43 mass rebuild)
- `f43` gets **active Fedora maintainer attention** — if a CVE hits libsoup or
  xorg-x11-server, the `f43` branch gets the patch; `f41` does not
- If an `f43` spec ever adds a dependency that EL10 can't satisfy, the COPR
  build will simply fail and we fall back to `f42` for that one package

### When to Bump to `f44`

When Fedora 44 is released as stable (~Apr 2026) and `f43` approaches EOL
(~Dec 2026), switch the default branch to `f44`. Update the `packages.json`
file and trigger a full rebuild. If any package fails, keep that specific
package on `f43` until the issue is resolved.

Also watch [AlmaLinux 10 release notes](https://wiki.almalinux.org/) — if a
point release (10.2, 10.3) rebases core libraries, that may require adjusting
our branch choice.

## Package Inventory

### Overview

| Category | Count | Source | Auto-Update? |
|---|---|---|---|
| SCM (Fedora src.fedoraproject.org) | 111 (105 active, 6 deprecated) | Git branches | ✅ Yes (COPR auto-rebuild or scheduled) |
| SCM (GitHub-Forks under `endegelaende/`) | 5 (+1 deprecated) | Fedora-based + EL10 patches | ⚠️ Manual (stable packages) |
| Upload (SRPMs) | 11 (10 dead/stable, 1 deprecated) | Manual uploads | ❌ Never needed (dead upstream) |
| **Total** | **128** | | |

### SCM Packages from Fedora (auto-updatable)

These point to `src.fedoraproject.org` and are pinned to our chosen branch (default `f43`):

#### MATE Desktop Core

| Package | Branch | Notes |
|---|---|---|
| `mate-common` | f43 | Build macros |
| `mate-desktop` | f43 | Core library |
| `mate-menus` | f43 | Menu system |
| `mate-menu` | f43 | Advanced menu |
| `mate-panel` | f43 | Panel |
| `mate-session-manager` | f43 | Session manager |
| `mate-control-center` | f43 | Control center |
| `mate-polkit` | f43 | PolicyKit agent |
| `mate-backgrounds` | f43 | Wallpapers |
| `mate-icon-theme` | f43 | Icons |
| `mate-themes` | f43 | GTK themes |
| `mate-media` | f43 | Volume control |
| `mate-notification-daemon` | f43 | Notifications |
| `mate-power-manager` | f43 | Power management |
| `mate-screensaver` | f43 | Screen lock |
| `mate-system-monitor` | f43 | Task manager |
| `mate-terminal` | f43 | Terminal emulator |
| `mate-calc` | f43 | Calculator |
| `mate-utils` | f43 | Utilities |
| `mate-applets` | f43 | Panel applets |
| `mate-sensors-applet` | f43 | Hardware sensors |
| `mate-user-guide` | f43 | Documentation |
| `mate-user-admin` | f43 | User management |
| `libmatekbd` | f43 | Keyboard library |
| `libmatemixer` | f43 | Audio mixer library |
| `libmateweather` | f43 | Weather library |
| `marco` | f43 | Window manager |

#### Caja (File Manager)

| Package | Branch |
|---|---|
| `caja` | f43 |
| `caja-extensions` | f43 |
| `caja-actions` | f43 |
| `python-caja` | f43 |

#### MATE Applications

| Package | Branch |
|---|---|
| `atril` | f43 |
| `engrampa` | f43 |
| `eom` | f43 |
| `mozo` | f43 |

#### Xorg Server + Drivers

| Package | Branch | Notes |
|---|---|---|
| `xorg-x11-server` | f43 | Core X server — benefits from f43 security patches |
| `xorg-x11-xauth` | f43 | |
| `xorg-x11-xinit` | f43 | |
| `xorg-x11-drv-libinput` | f43 | Input driver |
| `xorg-x11-drv-amdgpu` | f43 | AMD GPU |
| `xorg-x11-drv-ati` | f43 | ATI legacy |
| `xorg-x11-drv-evdev` | f43 | Event devices |
| `xorg-x11-drv-nouveau` | f43 | NVIDIA open |
| `xorg-x11-drv-vmware` | f43 | VMware guest |
| `xorg-x11-drv-wacom` | f43 | Wacom tablets |
| `xorg-x11-drv-dummy` | f43 | Headless |
| `xorg-x11-drv-intel` | f43 | Intel GPU |
| `mesa-compat` | f43 | Mesa compat libs |

#### LightDM + Greeters

| Package | Branch | Notes |
|---|---|---|
| `lightdm-gtk` | f43 | GTK greeter |
| `slick-greeter` | f43 | Slick greeter |
| `lightdm-settings` | f43 | Settings GUI |

#### Compiz (Desktop Effects)

| Package | Branch |
|---|---|
| `compiz-bcop` | f43 |
| `libcompizconfig` | f43 |
| `compizconfig-python` | f43 |
| `compiz-plugins-main` | f43 |
| `compiz-plugins-extra` | f43 |
| `compiz-plugins-experimental` | f43 |
| `ccsm` | f43 |
| `simple-ccsm` | f43 |
| `fusion-icon` | f43 |
| `emerald` | f43 |
| `emerald-themes` | f43 |

#### Libraries + Dependencies

| Package | Branch | Notes |
|---|---|---|
| `libXScrnSaver` | f43 | X screensaver ext |
| `libXvMC` | f43 | Video MC ext |
| `libsoup` | f43 | HTTP library — benefits from f43 security patches |
| `glibmm2.4` | f43 | C++ GLib bindings |
| `libsigc++20` | f43 | Signal framework |
| `pangomm` | f43 | C++ Pango bindings |
| `gtkmm3.0` | f43 | C++ GTK3 bindings |
| `atkmm` | f43 | C++ ATK bindings |
| `gtk-layer-shell` | f43 | Wayland layer shell |
| `gtk-murrine-engine` | f43 | GTK2 theme engine |
| `gnome-themes-extra` | f43 | Adwaita GTK2 |
| `libgnomekbd` | f43 | Keyboard library |
| `group-service` | f43 | Group management |
| `satyr` | f43 | Stack traces |
| `xfce4-dev-tools` | f43 | Build dep for xapps |
| `libreport` | f43 | Crash reporting library (ABRT dep) |

#### Extra Applications

| Package | Branch | Notes |
|---|---|---|
| `blueman` | f43 | Bluetooth manager |
| `celluloid` | f43 | Video player (mpv) |
| `xapps` | f43 | X-Apps library |
| `xed` | f43 | Text editor |
| `xreader` | f43 | Document viewer |
| `gparted` | f43 | Partition editor |
| ~~`dnfdragora`~~ | ~~f43~~ | ~~DNF GUI~~ — **DEPRECATED**: useless on immutable system |
| `gnome-abrt` | f43 | Crash reporter |
| `abrt` | f43 | Bug reporting |
| `gnome-backgrounds` | f43 | Wallpapers |
| `xscreensaver` | f43 | Screensavers |
| `system-config-language` | f43 | Language settings |
| `comps-extras` | f43 | Package groups |
| `multimedia-menus` | f43 | Menu categories |
| `fatsort` | f43 | FAT filesystem sort |
| `network-manager-applet` | f43 | NetworkManager tray applet |

#### Python Libraries

| Package | Branch | Notes |
|---|---|---|
| `python-xlib` | f43 | |
| `python-pystray` | f43 | |
| ~~`python-manatools`~~ | ~~f43~~ | **DEPRECATED**: dnfdragora dep |
| `python-gettext` | f43 | |
| `python-xapp` | f43 | |
| `python-cairosvg` | f43 | |
| `python-cssselect2` | f43 | |
| `python-tinycss2` | f43 | |

#### ~~libyui (DNFDragora dependency)~~ — DEPRECATED

| Package | Branch |
|---|---|
| ~~`libyui-mga`~~ | ~~f43~~ |
| ~~`libyui-gtk`~~ | ~~f43~~ |
| ~~`libyui-mga-gtk`~~ | ~~f43~~ |
| ~~`libyui-mga-ncurses`~~ | ~~f43~~ |

> **Deprecated:** dnfdragora and its entire dependency chain (libyui, python-manatools) are excluded from the Querencia Linux image. DNF GUI is useless on an immutable/atomic system. mintmenu is also deprecated (not installed in image). Packages remain in COPR but auto-rebuild is disabled.

#### Misc Tools

| Package | Branch |
|---|---|
| `appres` | f43 |
| `xvinfo` | f43 |
| `xinput` | f43 |
| `mathjax` | f43 |

#### Special Branch

| Package | Branch | Notes |
|---|---|---|
| `dnf5` | **epel10** | Already EL10-native — keep as-is! |

### GitHub-Forks (5 packages — all under `github.com/endegelaende/`)

These packages have minimal EL10 patches on top of clean Fedora specs. Each repo contains a `.copr/Makefile` for the `make_srpm` build method. See `forks/README.md` for detailed patch descriptions.

| Package | Repo | Branch | Base | EL10 Patch |
|---|---|---|---|---|
| `system-config-printer` | `rpms-system-config-printer` | `f43-el10` | Fedora f43 | RHEL>8 conditional removed → GUI builds |
| `qadwaitadecorations` | `rpms-qadwaitadecorations` | `f43-el10` | Fedora f43 | `%bcond_without qt5` → Qt5 enabled on EL10 |
| `lightdm` | `rpms-lightdm` | `f43-el10` | Fedora f43 | Greeter dep bootstrap (circular dep), `pam_lastlog` |
| `mate-settings-daemon` | `rpms-mate-settings-daemon` | `f43-el10` | Fedora f43 | Patch0 unconditional (otherwise not in SRPM) |
| `xorg-x11-drv-qxl` | `rpms-xorg-x11-drv-qxl` | `f43-el10` | Fedora f43 | Xspice disabled (no `spice-server-devel` on EL10) |
| ~~`mintmenu`~~ | ~~`rpms-mintmenu`~~ | ~~`r10`~~ | ~~Community packaging~~ | **DEPRECATED** — not installed in image |

Formerly upload, now on SCM: `system-config-printer`, `qadwaitadecorations` (→ GitHub forks), `mozo`, `network-manager-applet`, `libreport` (→ Fedora distgit).

### Upload Packages (11 SRPMs — all dead/stable/deprecated)

These were uploaded as `.src.rpm` files. All have dead or frozen upstream —
they will never need updating.

| Package | Version | Stability | Notes |
|---|---|---|---|
| `libxklavier` | 5.4-29.el10 | 🟢 Stable (dead upstream) | Keyboard layout lib |
| `python-distutils-extra` | 2.39-36.el10 | 🟢 Stable | Python build helper |
| `libXpresent` | 1.0.0-1.el10 | 🟢 Stable | X Present extension |
| `beesu` | 2.7-1.el10 | 🟢 Stable (dead upstream) | GUI privilege escalation |
| `compiz` | 0.8.18-17.el10 | 🟡 Frozen | Core compositor (circular dep bootstrap) |
| `compiz-manager` | 0.7.0-24.el10 | 🟢 Stable | Compiz launcher |
| `usermode` | 1.114-13.el10 | 🟢 Stable | User privilege helper |
| ~~`libyui`~~ | ~~4.2.16-25.el10~~ | ~~🟡~~ | ~~UI abstraction~~ — **DEPRECATED** |
| `t1lib` | 5.1.2-42.el10 | 🟢 Stable (dead upstream) | Type 1 font lib |
| `libglade2` | 2.6.4-36.el10 | 🟢 Stable (dead upstream) | GTK2 UI builder |
| `p7zip` | 16.02-33.el10 | 🟢 Stable (dead upstream) | 7-Zip implementation |

## Setup Instructions

### Prerequisites

1. **Fedora Account (FAS):** Create at https://accounts.fedoraproject.org/
2. **COPR access:** Log in at https://copr.fedorainfracloud.org/ with your FAS account
3. **copr-cli:** Install with `dnf install copr-cli` (or `pip install copr-cli`)
4. **API token:** Get from https://copr.fedorainfracloud.org/api/ and save to `~/.config/copr`

### Step 1: Create the COPR Project

```bash
copr-cli create \
  --chroot rhel+epel-10-x86_64 \
  --chroot rhel+epel-10-aarch64 \
  --description "MATE Desktop for AlmaLinux/EL10 — Querencia Linux" \
  --instructions "See https://github.com/endegelaende/querencia-linux for usage" \
  --repo "https://download.rockylinux.org/pub/rocky/\$releasever/devel/\$basearch/os/" \
  --repo "https://dl.fedoraproject.org/pub/epel/\${releasever}z/Everything/\$basearch/" \
  --unlisted-on-hp on \
  winonaoctober/MateDesktop-EL10
```

### Step 2: Run the Setup Script

```bash
# Downloads SRPMs, creates all package definitions, triggers builds
./setup-copr-fork.sh
```

See `setup-copr-fork.sh` for the full automation script.

### Step 3: Update the Querencia Linux Repo File

Ensure the winonaoctober COPR repo is configured in `files/system/etc/yum.repos.d/`:

```ini
[copr:copr.fedorainfracloud.org:winonaoctober:MateDesktop-EL10]
name=COPR winonaoctober/MateDesktop-EL10
baseurl=https://download.copr.fedorainfracloud.org/results/winonaoctober/MateDesktop-EL10/rhel+epel-10-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/winonaoctober/MateDesktop-EL10/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
```

### Step 4: Verify

After all builds complete (~2-4 hours for initial build):

```bash
# Check build status
copr-cli list-builds winonaoctober/MateDesktop-EL10 | head -20

# Test install in a container
podman run --rm -it quay.io/almalinuxorg/almalinux:10 bash -c '
  dnf install -y dnf-plugins-core epel-release
  dnf config-manager --set-enabled crb
  dnf copr enable winonaoctober/MateDesktop-EL10 -y
  dnf groupinstall -y "MATE-Desktop"
  echo "SUCCESS: MATE installed from fork"
'
```

## Maintenance

### Scheduled Rebuilds (Recommended)

Set up a GitHub Action that runs weekly to rebuild all SCM packages.
This ensures we pick up any bugfix/security commits pushed to the `f43`
branch by Fedora maintainers:

```yaml
# .github/workflows/copr-rebuild.yml
name: COPR Weekly Rebuild
on:
  schedule:
    - cron: '0 2 * * 1'  # Monday 02:00 UTC
  workflow_dispatch:

jobs:
  rebuild:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install copr-cli
        run: pip install copr-cli
      - name: Configure copr-cli
        run: |
          mkdir -p ~/.config
          echo "${{ secrets.COPR_CONFIG }}" > ~/.config/copr
      - name: Rebuild all SCM packages
        run: ./copr-fork/rebuild-all.sh
```

### When a Build Fails

1. Check if the `f43` branch spec requires a dependency not in EL10
2. Try `f42` branch as fallback, then `f41`
3. If all fail, check `copr-fork/forks/README.md` for known EL10 patches and create a GitHub fork
4. When `f43` reaches EOL (~Dec 2026), bump default to `f44` and re-test all packages

### Monitoring Builds

Check the COPR monitor page for build status:
- https://copr.fedorainfracloud.org/coprs/winonaoctober/MateDesktop-EL10/monitor/

## Files in This Directory

| File | Purpose |
|---|---|
| `README.md` | This documentation |
| `setup-copr-fork.sh` | One-time setup: creates all packages in your COPR project |
| `rebuild-all.sh` | Triggers rebuild of all SCM packages (skips deprecated packages where `auto_rebuild: false`) |
| `rebuild-failed.sh` | Detect and rebuild failed packages in dependency order |
| `download-srpms.sh` | Downloads SRPMs from COPR build results |
| `migrate-to-forks.sh` | Upload→SCM migration script (✅ completed 2026-03-13) |
| `migrate-to-forks-curl.sh` | curl-based migration (without copr-cli, for Windows) |
| `packages.json` | Machine-readable package inventory with branch mappings |
| `forks/` | Patch documentation and reference materials for GitHub fork repos |

> **Note:** Several packages in `packages.json` are marked `"auto_rebuild": false` —
> these are deprecated packages (e.g. `dnfdragora`, the `libyui-*` family,
> `python-manatools`, `mintmenu`) that are excluded from the image build. Both `rebuild-all.sh`
> and `rebuild-failed.sh` skip these packages during automated rebuilds. They remain
> in the inventory for reference but will not be rebuilt unless explicitly requested
> with `--package`.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Upstream Fedora drops MATE from distgit | Low (years) | 🔴 Critical | We have all specs + SRPMs, can self-host |
| f43 spec needs dep not in EL10 | Low | 🟡 Medium | Fall back to f42/f41 for that package |
| f43 reaches EOL (Dec 2026) | Certain | 🟢 Low | Bump to f44, MATE specs are stable across releases |
| EL10 major rebase breaks builds | Low | 🟡 Medium | Adjust branch per package, test after rebase |
| New MATE release needs newer deps | Medium | 🟡 Medium | Stay on current version, don't chase upstream |
| Fedora drops MATE entirely | Low (years) | 🔴 Critical | We have complete inventory (`packages.json`) + all specs and SRPMs |