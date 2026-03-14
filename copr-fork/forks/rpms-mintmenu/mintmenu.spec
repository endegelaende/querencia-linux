%global GIT_HASH d1723f967f53305a2b7800e828273c96a6272a2a

Name:          mintmenu
Version:       6.2.2
Release:       1%{?dist}.querencia1
Summary:       Friendly menu for MATE Desktop from LinuxMint project
License:       GPL-2.0
URL:           https://github.com/linuxmint/mintmenu
Source0:       https://github.com/linuxmint/mintmenu/archive/%{GIT_HASH}.zip
Source1:       Rocky_Logo.svg
Source2:       com.linuxmint.mintmenu.gschema.xml

BuildArch:     noarch

BuildRequires: unzip

Requires: python3-cairo >= 1.25
Requires: python3-configobj >= 5
Requires: python3-pyxdg >= 0.27
Requires: python3-setproctitle >= 1.3
Requires: python3-xapp >= 2.4
Requires: python3-unidecode >= 1.3
Requires: python3-xlib >= 0.33

Requires: cairo-gobject >= 1.18.2
Requires: xdg-utils >= 1.2
Requires: glib2 >= 2.80
Requires: mate-menus

%description
Friendly advanced menu for MATE Desktop from LinuxMint project

%prep
# needs manual prep due to awkward git/zip clone distribution mechanism
unzip %{SOURCE0}
mv -f mintmenu-%{GIT_HASH} mintmenu

pushd mintmenu
%autopatch -p1
popd

# Brand with any distro .svg logo and text:
cp -f %{SOURCE1} ./mintmenu/usr/share/pixmaps/mintmenu.svg
cp -f %{SOURCE2} ./mintmenu/usr/share/glib-2.0/schemas/

# Ensure mintmenu python shebangs are for v3:
# (probably should be a patch, but I'm in a hurry)
sed -i 's|^#!/usr/bin/python$|#!/usr/bin/python3|' ./mintmenu/usr/lib/linuxmint/mintMenu/*.py

%build
echo "No build step"


%install
# /usr/bin :
%{__install} -m 0755 mintmenu/usr/bin/mintmenu -D -t %{buildroot}/usr/bin/

# /usr/lib installation:
%{__install} -d -m 0755 %{buildroot}/usr/lib/linuxmint/mintMenu/{plugins,search_engines}
%{__install} -m 0755 mintmenu/usr/lib/linuxmint/mintMenu/*.* -D -t %{buildroot}/usr/lib/linuxmint/mintMenu/
%{__install} -m 0755 mintmenu/usr/lib/linuxmint/mintMenu/plugins/*.* -D -t %{buildroot}/usr/lib/linuxmint/mintMenu/plugins/
%{__install} -m 0644 mintmenu/usr/lib/linuxmint/mintMenu/search_engines/*.* -D -t %{buildroot}/usr/lib/linuxmint/mintMenu/search_engines/

# /usr/share installation:
%{__install} -d -m 0755 %{buildroot}/usr/share/dbus-1/services
%{__install} -m 0644 mintmenu/usr/share/dbus-1/services/*  -D -t %{buildroot}/usr/share/dbus-1/services/

%{__install} -d -m 0755 %{buildroot}/usr/share/glib-2.0/schemas
%{__install} -m 0644 mintmenu/usr/share/glib-2.0/schemas/*  -D -t %{buildroot}/usr/share/glib-2.0/schemas/

%{__install} -d -m 0755 %{buildroot}/usr/share/icons/hicolor/scalable/categories
%{__install} -m 0644 mintmenu/usr/share/icons/hicolor/scalable/categories/*  -D -t %{buildroot}/usr/share/icons/hicolor/scalable/categories/

%{__install} -d -m 0755 %{buildroot}/usr/share/linuxmint/mintmenu
%{__install} -m 0644 mintmenu/usr/share/linuxmint/mintmenu/*  -D -t %{buildroot}/usr/share/linuxmint/mintmenu/

%{__install} -d -m 0755 %{buildroot}/usr/share/man/man1
%{__install} -m 0644 mintmenu/usr/share/man/man1/*  -D -t %{buildroot}/usr/share/man/man1/

%{__install} -d -m 0755 %{buildroot}/usr/share/mate-panel/applets
%{__install} -m 0644 mintmenu/usr/share/mate-panel/applets/*  -D -t %{buildroot}/usr/share/mate-panel/applets/

%{__install} -d -m 0755 %{buildroot}/usr/share/pixmaps
%{__install} -m 0644 mintmenu/usr/share/pixmaps/*  -D -t %{buildroot}/usr/share/pixmaps/


%posttrans
# Pulled from Debian postinst, need to refresh glib schemas and compile modules w/ python:
glib-compile-schemas /usr/share/glib-2.0/schemas
python3 -m compileall -qf /usr/lib/linuxmint/mintMenu/


%files
%{_bindir}/mintmenu
%doc /usr/share/man/man1/mintmenu.1.gz

/usr/share/linuxmint/mintmenu/*
/usr/share/mate-panel/applets/org.mate.panel.MintMenuApplet.mate-panel-applet
/usr/share/dbus-1/services/org.mate.panel.applet.MintMenuAppletFactory.service
/usr/share/icons/hicolor/scalable/categories/mintmenu-all-applications-symbolic.svg
/usr/share/glib-2.0/schemas/*.xml
/usr/share/pixmaps/mintmenu.svg
/usr/lib/linuxmint/mintMenu/*.*
/usr/lib/linuxmint/mintMenu/plugins/*.py
/usr/lib/linuxmint/mintMenu/search_engines/*.*


%changelog
* Fri Mar 13 2026 Querencia Linux <querencia@endegelaende.github.io> - 6.2.2-1.querencia1
- Forked from skip77 for Querencia Linux supply-chain independence
- Added .copr/Makefile for COPR make_srpm builds
* Sat Aug 30 2025 Skip Grube <skip@rockylinux.org> - 6.2.2-1
- Initial release, ported to Rocky10 from LinuxMint Github
