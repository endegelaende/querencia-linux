# rpms-qadwaitadecorations (f43-el10 fork)

> Fork of `src.fedoraproject.org/rpms/qadwaitadecorations` for EL10 compatibility.

## Problem

The upstream f43 spec disables Qt5 on RHEL ≥ 10:

```
%bcond qt5 %[%{undefined rhel} || 0%{?rhel} < 10]
```

This causes the package to produce no Qt5 subpackage on EL10, which is the only
subpackage we actually need (Qt6 is not available on EL10).

## Fix

One-line change in the spec file:

```diff
-%bcond qt5 %[%{undefined rhel} || 0%{?rhel} < 10]
+%bcond_without qt5
```

`%bcond_without qt5` unconditionally enables the `qt5` bcond (it can still be
overridden with `--without qt5` at build time if needed).

## Branch

- **Branch:** `f43-el10`
- **Base:** `f43` from `src.fedoraproject.org/rpms/qadwaitadecorations.git`

## COPR Integration

```bash
copr-cli edit-package-scm winonaoctober/MateDesktop-EL10 \
  --name qadwaitadecorations \
  --clone-url https://github.com/endegelaende/rpms-qadwaitadecorations.git \
  --committish f43-el10 \
  --method make_srpm

copr-cli build-package winonaoctober/MateDesktop-EL10 --name qadwaitadecorations
```

## Maintenance

When upstream bumps the version on the `f43` branch:

1. `git fetch upstream f43`
2. `git rebase upstream/f43` (or cherry-pick)
3. Re-apply the one-line bcond fix if it got overwritten
4. Push to `f43-el10`
5. COPR auto-rebuild will pick it up

## Upstream

- **Upstream repo:** https://src.fedoraproject.org/rpms/qadwaitadecorations
- **Upstream branch:** `f43`
- **Project:** https://github.com/FedoraQt/QAdwaitaDecorations