# rpms-system-config-printer (EL10 Fork)

> Fork of `src.fedoraproject.org/rpms/system-config-printer` branch `f43`
> for use with Querencia Linux / winonaoctober COPR.

## Problem

The upstream Fedora spec has RHEL conditionals that **strip the GUI** on RHEL > 8:

```
%if 0%{?rhel} > 8
rm -rf %{buildroot}%{_bindir}/%{name} \
       %{buildroot}%{_bindir}/install-printerdriver \
       ... (all GUI files)
%endif
```

And conditionals that skip building the main `%files` and `%files applet` sections:

```
%if 0%{?rhel} <= 8 || 0%{?fedora}
%files
...
%endif

%if 0%{?rhel} <= 8 || 0%{?fedora}
%files applet
...
%endif
```

This means on EL10 only `-libs` and `-udev` subpackages are produced —
the actual printer configuration GUI is gone.

## Fix

Branch `f43-el10` removes/adjusts these RHEL conditionals so the GUI
is built and shipped on EL10:

1. **Remove** the `%if 0%{?rhel} > 8` block in `%install` that deletes GUI files
2. **Remove** the `%if 0%{?rhel} <= 8 || 0%{?fedora}` guards around `%files applet`
3. **Remove** the `%if 0%{?rhel} <= 8 || 0%{?fedora}` guards around `%files` and `%post`

The patch is minimal — only the conditionals change, no functional code is modified.

## COPR Integration

Once this fork exists on GitHub, configure in COPR as:

```bash
copr-cli edit-package-scm winonaoctober/MateDesktop-EL10 \
    --name system-config-printer \
    --clone-url https://github.com/endegelaende/rpms-system-config-printer.git \
    --committish f43-el10 \
    --method make_srpm

copr-cli build-package winonaoctober/MateDesktop-EL10 \
    --name system-config-printer
```

## Upstream Sync

To pull in upstream updates:

```bash
git remote add upstream https://src.fedoraproject.org/rpms/system-config-printer.git
git fetch upstream f43
git rebase upstream/f43
# Re-apply the conditional removal if needed (should be clean)
git push origin f43-el10 --force-with-lease
```

## Files Changed

Only `system-config-printer.spec` is modified from upstream `f43`.

See `system-config-printer.spec.patch` for the exact diff.