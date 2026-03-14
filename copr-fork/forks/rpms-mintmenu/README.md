# rpms-mintmenu

## Overview

- **Package:** mintmenu
- **Version:** 6.2.2
- **Upstream:** https://github.com/linuxmint/mintmenu
- **Source:** Community RPM spec for Rocky 10 (no Fedora upstream)
- **Fork:** https://github.com/endegelaende/rpms-mintmenu (branch `r10`)

## Special Case — No Fedora Upstream

Unlike our other 5 forks (all based on Fedora distgit), mintmenu has
**no usable Fedora upstream**. The Fedora distgit at `src.fedoraproject.org/rpms/mintmenu` contains
only a `dead.package` file with the message "Obsoleted by mate-menu".

The RPM spec was originally written from scratch for Rocky Linux 10. We forked it with clean
git history as the base for Querencia.

## Changes from Original

- Release bumped to `1%{?dist}.querencia1`
- Added `.copr/Makefile` for COPR `make_srpm` builds
- Clean git history (no inherited upstream commits)
- **TODO:** Rebrand `Rocky_Logo.svg` to Querencia logo

## Build Method

This package uses COPR's `make_srpm` method (not rpkg), because the spec fetches source directly
from GitHub via a zip archive URL:

```
Source0: https://github.com/linuxmint/mintmenu/archive/%{GIT_HASH}.zip
```

The `.copr/Makefile` downloads this zip and runs `rpmbuild -bs` to produce the SRPM.

## Branding

The spec installs `Rocky_Logo.svg` as `Source1` into `/usr/share/pixmaps/mintmenu.svg`. This is
the menu button icon. To rebrand for Querencia:

1. Replace `Rocky_Logo.svg` with a Querencia-branded SVG in the repo
2. Update `Source1:` in the spec if the filename changes
3. The Querencia logo SVG is available at `assets/querencia-logo.svg` in the main repo

For now, `Rocky_Logo.svg` is kept as-is to maintain functionality.

## COPR Registration

```bash
# Add as make_srpm package (NOT rpkg — there's no rpkg.conf that works with our setup)
curl -X POST "https://copr.fedorainfracloud.org/api_3/package/add/winonaoctober/MateDesktop-EL10/make_srpm" \
  -u "$COPR_LOGIN:$COPR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "package_name": "mintmenu",
    "clone_url": "https://github.com/endegelaende/rpms-mintmenu.git",
    "committish": "r10",
    "auto_rebuild": true
  }'

# Or via copr-cli:
copr-cli add-package-scm winonaoctober/MateDesktop-EL10 \
  --name mintmenu \
  --clone-url https://github.com/endegelaende/rpms-mintmenu.git \
  --committish r10 \
  --method make_srpm

# Trigger initial build:
copr-cli build-package winonaoctober/MateDesktop-EL10 --name mintmenu
```

## Updating

Since upstream (linuxmint/mintmenu) rarely releases new versions, updates are infrequent.
To update:

1. Check https://github.com/linuxmint/mintmenu for new commits/tags
2. Update `%global GIT_HASH` in the spec to the new commit
3. Update `GIT_HASH` in `.copr/Makefile` to match
4. Bump `Version:` if there's a new tag, or bump the querencia release number
5. Add a changelog entry
6. Commit and push to `r10`

## Dependencies

mintmenu requires several Python packages that must be available in the build target:

- `python3-xapp` (from our COPR)
- `python3-xlib`, `python3-cairo`, `python3-configobj`, `python3-pyxdg`
- `python3-setproctitle`, `python3-unidecode`
- `mate-menus` (from our COPR)