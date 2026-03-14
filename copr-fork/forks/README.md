# COPR Fork Spec Patches

This directory contains documentation and reference materials for our GitHub fork repos.
All forks live under `github.com/endegelaende/` and are registered in COPR as SCM packages
with `make_srpm` build method.

## Strategy

We fork directly from **Fedora distgit** (`src.fedoraproject.org/rpms/`), apply minimal
EL10-specific patches, and let COPR build from our GitHub forks.

Each fork repo contains:
- The upstream Fedora spec (with minimal changes)
- All patches from Fedora distgit
- A `.copr/Makefile` that downloads the source tarball and runs `rpmbuild -bs`
- The `sources` file (SHA512 hashes from Fedora distgit)

## Why `make_srpm` (not `rpkg`)

COPR's `rpkg` method generates its own `rpkg.conf` that derives the lookaside URL from the
git remote. For GitHub repos this produces an invalid URL → 404. Any `.rpkg.conf` in the
repo is **ignored** (COPR overwrites it).

Solution: `.copr/Makefile` with `make_srpm` method — fetches the tarball directly via `curl`
from the correct source (Fedora lookaside, pub.mate-desktop.org, freedesktop.org, etc.)
and builds the SRPM with `rpmbuild -bs`.

## Known Gotcha: Conditional Patches

If a `Patch0:` tag is inside `%if 0%{?rhel}` and the SRPM is built in a **Fedora chroot**
(where `%{?rhel}` is not set), the patch is **not included** in the SRPM. When EL10 mock
then tries to build, the patch file is missing → `Bad file: ... No such file or directory`.

**Fix:** Always make `Patch:` tags unconditional. Only the `%patch` application may be conditional.

## All 6 Forks

### `rpms-system-config-printer`

- **Upstream:** `src.fedoraproject.org/rpms/system-config-printer` (branch `f43`)
- **Fork:** `github.com/endegelaende/rpms-system-config-printer` (branch `f43-el10`)
- **Build method:** `make_srpm` — source from Fedora lookaside
- **Problem:** `%if 0%{?rhel} > 8` block deletes all GUI files; three conditionals disable `%package applet`, `%files`, `%post` on RHEL > 8
- **Fix:** Remove the deletion block and all three RHEL conditionals → full GUI built for EL10
- **Release:** `16%{?dist}.querencia1`

### `rpms-qadwaitadecorations`

- **Upstream:** `src.fedoraproject.org/rpms/qadwaitadecorations` (branch `f43`)
- **Fork:** `github.com/endegelaende/rpms-qadwaitadecorations` (branch `f43-el10`)
- **Build method:** `make_srpm` — source from Fedora lookaside
- **Problem:** `%bcond qt5 %[%{undefined rhel} || 0%{?rhel} < 10]` disables Qt5 on RHEL ≥ 10
- **Fix:** Replace with `%bcond_without qt5` → Qt5 always built
- **Release:** `2%{?dist}.querencia1`

### `rpms-lightdm`

- **Upstream:** `src.fedoraproject.org/rpms/lightdm` (branch `f43`)
- **Fork:** `github.com/endegelaende/rpms-lightdm` (branch `f43-el10`)
- **Build method:** `make_srpm` — source from Fedora lookaside
- **Problem 1:** `Requires: lightdm-greeter = 1.2` creates circular dep (lightdm ↔ lightdm-gtk-greeter)
- **Fix 1:** Comment out the greeter dependency (bootstrap)
- **Problem 2:** Fedora f43 switched to `pam_lastlog2.so` which EL10 doesn't have
- **Fix 2:** Use `pam_lastlog.so` in `lightdm.pam`
- **Problem 3:** `%autorelease` not supported in COPR make_srpm
- **Fix 3:** Replace with `Release: 1%{?dist}.querencia1`

### `rpms-mate-settings-daemon`

- **Upstream:** `src.fedoraproject.org/rpms/mate-settings-daemon` (branch `f43`)
- **Fork:** `github.com/endegelaende/rpms-mate-settings-daemon` (branch `f43-el10`)
- **Build method:** `make_srpm` — source from pub.mate-desktop.org
- **Problem:** `Patch0:` was inside `%if 0%{?rhel}` → not included in SRPM when built in Fedora chroot
- **Fix:** Made `Patch0:` unconditional (the patch itself is harmless on Fedora)
- **Note:** Zero functional spec changes needed — the Fedora f43 spec already has the RHEL xrdb patch
- **Release:** `1%{?dist}.querencia1`

### `rpms-xorg-x11-drv-qxl`

- **Upstream:** `src.fedoraproject.org/rpms/xorg-x11-drv-qxl` (branch `f43`)
- **Fork:** `github.com/endegelaende/rpms-xorg-x11-drv-qxl` (branch `f43-el10`)
- **Build method:** `make_srpm` — source from xorg.freedesktop.org
- **Problem:** `spice-server-devel` not available on EL10 → Xspice subpackage can't build
- **Fix:** Add `%if 0%{?rhel} > 8` / `%define with_xspice 0` / `%endif` after existing `with_xspice` definition
- **Also:** `http` → `https` for Source0 URL
- **Release:** `1%{?dist}.querencia1`

### ~~`rpms-mintmenu`~~ — DEPRECATED

> **Not installed in the Querencia Linux image.** Package remains in COPR with `auto_rebuild: false` for reference only.

- **Upstream:** `github.com/linuxmint/mintmenu` (no Fedora distgit — `dead.package` "Obsoleted by mate-menu")
- **Original packaging:** Community RPM spec for Rocky 10 (no Fedora upstream)
- **Fork:** `github.com/endegelaende/rpms-mintmenu` (branch `r10`)
- **Build method:** `make_srpm` — source zip from linuxmint/mintmenu GitHub
- **Note:** This is a special case — the RPM spec was originally written for Rocky 10 (no Fedora upstream exists). We forked with clean git history.
- **Release:** `1%{?dist}.querencia1`

## How to Create a New Fork

```bash
# 1. Clone from Fedora distgit
cd /tmp
git clone https://src.fedoraproject.org/rpms/PACKAGE.git rpms-PACKAGE
cd rpms-PACKAGE
git config user.name "endegelaende"
git config user.email "endegelaende@users.noreply.github.com"

# 2. Create branch from f43
git checkout origin/f43 -b f43-el10

# 3. Apply EL10 patches to spec
#    - Replace %autorelease → Release: 1%{?dist}.querencia1
#    - Replace %autochangelog → static changelog entry
#    - Apply any EL10-specific changes
#    - Make conditional Patch: tags unconditional

# 4. Create .copr/Makefile
mkdir -p .copr
cat > .copr/Makefile << 'EOF'
.PHONY: srpm

TARBALL_URL = https://UPSTREAM_URL/PACKAGE-VERSION.tar.xz
TARBALL = PACKAGE-VERSION.tar.xz

srpm:
	curl -fsSL -o $(TARBALL) "$(TARBALL_URL)"
	rpmbuild -bs PACKAGE.spec \
		--define "_sourcedir $$(pwd)" \
		--define "_specdir $$(pwd)" \
		--define "_srcrpmdir $(outdir)" \
		--define "dist %{nil}"
EOF

# 5. Commit and create GitHub repo
git add -A
git commit -m "el10: DESCRIPTION OF CHANGES"
gh repo create endegelaende/rpms-PACKAGE --public
git remote add github https://github.com/endegelaende/rpms-PACKAGE.git
git push github f43-el10

# 6. Register in COPR (on Build-VM: ssh stephan@192.168.1.165)
copr-cli add-package-scm winonaoctober/MateDesktop-EL10 \
  --name PACKAGE \
  --clone-url https://github.com/endegelaende/rpms-PACKAGE.git \
  --commit f43-el10 \
  --method make_srpm
copr-cli build-package winonaoctober/MateDesktop-EL10 --name PACKAGE
```

## Syncing with Upstream

To pull in Fedora f43 updates (for all forks except mintmenu):

```bash
cd rpms-PACKAGE
git fetch origin   # origin = src.fedoraproject.org
git checkout f43-el10
git rebase origin/f43
# Re-apply EL10 patches if conflicts arise
# Update .copr/Makefile tarball URL/version if Source0 changed
git push github f43-el10 --force-with-lease
# Trigger COPR rebuild
```

For mintmenu (no Fedora upstream) — **DEPRECATED, no updates needed**:

```bash
# Check for new commits at https://github.com/linuxmint/mintmenu
cd rpms-mintmenu
git checkout r10
# Update GIT_HASH in spec + .copr/Makefile
# Update sources file (new SHA512)
# Bump Version/Release, add changelog entry
git commit -am "update: mintmenu NEW_VERSION"
git push github r10
```

## Summary

| Fork | Upstream | Branch | Source | Status |
|---|---|---|---|---|
| `rpms-system-config-printer` | Fedora f43 | `f43-el10` | Fedora lookaside | ✅ Active |
| `rpms-qadwaitadecorations` | Fedora f43 | `f43-el10` | Fedora lookaside | ✅ Active |
| `rpms-lightdm` | Fedora f43 | `f43-el10` | Fedora lookaside | ✅ Active |
| `rpms-mate-settings-daemon` | Fedora f43 | `f43-el10` | pub.mate-desktop.org | ✅ Active |
| `rpms-xorg-x11-drv-qxl` | Fedora f43 | `f43-el10` | xorg.freedesktop.org | ✅ Active |
| ~~`rpms-mintmenu`~~ | ~~linuxmint/mintmenu~~ | ~~`r10`~~ | ~~github.com/linuxmint~~ | ⛔ Deprecated |

**5 active forks are under our control on GitHub.** No external runtime dependencies.
All 11 remaining upload packages are dead/stable/deprecated and never need updating.