# Enable hardened build, as the udev part runs with privilege.
%global _hardened_build 1

%global username OpenPrinting

# Querencia Linux: Force GUI build on all RHEL versions
# Original f43 spec disables GUI and applet on RHEL > 8
# We remove those conditionals so the full GUI is built for EL10

Summary: A printer administration tool
Name: system-config-printer
Version: 1.5.18
Release: 16.querencia1%{?dist}
License: GPL-2.0-or-later
URL: https://github.com/%{username}/%{name}
Source0: %{url}/releases/download/%{version}/%{name}-%{version}.tar.xz

# all upstream patches, remove with new release
Patch0001: 0001-Fix-debugprint-in-options.py-fixes-291.patch
Patch0002: 0001-udev-Fix-exit-value-when-device-is-already-handled.patch


# needed for macro AM_GNU_GETTEXT in configure.ac
BuildRequires: autoconf-archive
# uses CUPS API functions
BuildRequires: cups-devel >= 1.2
# we install a desktop file
BuildRequires: desktop-file-utils >= 0.2.92
# gcc is no longer in buildroot by default
# gcc is needed for udev-configure-printer.c
BuildRequires: gcc
# for translations
BuildRequires: gettext-devel
# for autosetup
BuildRequires: git-core
# for translations
BuildRequires: intltool
# automatic printer setup tool, which uses udev, is only for USB printers
# we need libusb API to communicate
BuildRequires: libusb1-devel
# uses make
BuildRequires: make
# GNOME library for GUI
BuildRequires: pkgconfig(glib-2.0)
# for python3 API
BuildRequires: python3-devel
# uses distutils
BuildRequires: python3-setuptools
# for automatic USB printer setup tool - udev-configure-printer
BuildRequires: systemd
BuildRequires: systemd-devel
# for generating manual
BuildRequires: xmlto


# for dBUS support in scp-dbus-service
Requires: dbus-x11
# for desktop file
Requires: desktop-file-utils >= 0.2.92
# for system notifications
Requires: desktop-notification-daemon
# for GUI, the app is written in gtk3
Requires: gtk3%{?_isa}
# for GUI to prevent warning during the startup
Requires: libcanberra-gtk3
# for notifications
Requires: libnotify%{?_isa}
# for GUI
Requires: python3-cairo%{?_isa}
# for dBUS python API
Requires: python3-dbus%{?_isa}
# the app can adjust firewalld, so we need firewall API in Python
Requires: python3-firewall
# for GUI
Requires: python3-gobject%{?_isa}
# runtime systemd requires for udev-configure-printer service
%{?systemd_requires}
# we use classes define in our library
Requires: system-config-printer-libs = %{version}-%{release}

%description
system-config-printer is a graphical user interface that allows
the user to configure a CUPS print server.

%package libs
Summary: Libraries and shared code for printer administration tool
# PackageKit can bring you a popup window if some package in the repo provides a driver
# for your printer
Recommends: PackageKit
Recommends: PackageKit-glib

# for GUI
Requires: gobject-introspection
# written in GTK3
Requires: gtk3
# for notifications
Requires: libnotify
# s-c-p classes uses Python CUPS API
Requires: python3-cups >= 1.9.60
# the libs subpackage contains scp-dbus-service, so we need dBUS API in Python here
Requires: python3-dbus
# for GUI
Requires: python3-gobject

# s-c-p has a plug-in support for Samba, if the relevant package is installed
Suggests: python3-smbc
BuildArch: noarch

%description libs
The common code used by both the graphical and non-graphical parts of
the configuration tool.

# Querencia Linux: Always build the applet subpackage (removed RHEL conditional)
%package applet
Summary: Print job notification applet
Requires: %{name}-libs

%description applet
Print job notification applet.

%package udev
Summary: Rules for udev for automatic configuration of USB printers
Requires: system-config-printer-libs = %{version}-%{release}

%description udev
The udev rules and helper programs for automatically configuring USB
printers.

%prep
%autosetup -S git
# workaround https://github.com/pypa/setuptools/issues/3143
sed -i 's/setup.py install --prefix=$(DESTDIR)$(prefix)/setup.py install --root $(DESTDIR) --prefix=$(prefix)/' Makefile*

%build
%configure --with-udev-rules
%make_build

%install
%make_install

%{__mkdir_p} %buildroot%{_localstatedir}/run/udev-configure-printer
touch %buildroot%{_localstatedir}/run/udev-configure-printer/usb-uris

# Manually invoke the python byte compile macro for each path that
# needs byte compilation
%py_byte_compile %{__python3} %{buildroot}/%{_datadir}/system-config-printer

%find_lang system-config-printer

# Querencia Linux: Removed the entire "if rhel > 8 then rm -rf GUI files" block
# All GUI files are now kept in the buildroot for EL10

%files libs -f system-config-printer.lang
%doc ChangeLog NEWS ABOUT-NLS AUTHORS ChangeLog-OLD
%license COPYING
%config(noreplace) %{_sysconfdir}/dbus-1/system.d/com.redhat.NewPrinterNotification.conf
%config(noreplace) %{_sysconfdir}/dbus-1/system.d/com.redhat.PrinterDriversInstaller.conf
%{_datadir}/dbus-1/interfaces/*.xml
%{_datadir}/dbus-1/services/*.service
%{_bindir}/scp-dbus-service
%dir %{_datadir}/%{name}
%{_datadir}/%{name}/__pycache__/*
%exclude %{_datadir}/%{name}/__pycache__/check-device-ids*
%exclude %{_datadir}/%{name}/__pycache__/HIG*
%exclude %{_datadir}/%{name}/__pycache__/SearchCriterion*
%exclude %{_datadir}/%{name}/__pycache__/serversettings*
%exclude %{_datadir}/%{name}/__pycache__/system-config-printer*
%exclude %{_datadir}/%{name}/__pycache__/ToolbarSearchEntry*
%exclude %{_datadir}/%{name}/__pycache__/userdefault*
%exclude %{_datadir}/%{name}/__pycache__/install-printerdriver*
%exclude %{_datadir}/%{name}/__pycache__/applet*
%{_datadir}/%{name}/asyncconn.py*
%{_datadir}/%{name}/asyncipp.py*
%{_datadir}/%{name}/asyncpk1.py*
%{_datadir}/%{name}/authconn.py*
%{_datadir}/%{name}/config.py*
%{_datadir}/%{name}/cupspk.py*
%{_datadir}/%{name}/debug.py*
%{_datadir}/%{name}/dnssdresolve.py*
%{_datadir}/%{name}/errordialogs.py*
%{_datadir}/%{name}/firewallsettings.py*
%{_datadir}/%{name}/gtkinklevel.py*
%{_datadir}/%{name}/gui.py*
%{_datadir}/%{name}/installpackage.py*
%{_datadir}/%{name}/jobviewer.py*
%{_datadir}/%{name}/killtimer.py*
%{_datadir}/%{name}/monitor.py*
%{_datadir}/%{name}/newprinter.py*
%{_datadir}/%{name}/options.py*
%{_datadir}/%{name}/optionwidgets.py*
%{_datadir}/%{name}/OpenPrintingRequest.py*
%{_datadir}/%{name}/PhysicalDevice.py*
%{_datadir}/%{name}/ppdcache.py*
%{_datadir}/%{name}/ppdippstr.py*
%{_datadir}/%{name}/ppdsloader.py*
%{_datadir}/%{name}/printerproperties.py*
%{_datadir}/%{name}/probe_printer.py*
%{_datadir}/%{name}/pysmb.py*
%{_datadir}/%{name}/scp-dbus-service.py*
%{_datadir}/%{name}/smburi.py*
%{_datadir}/%{name}/statereason.py*
%{_datadir}/%{name}/timedops.py*
%dir %{_datadir}/%{name}/__pycache__
%dir %{_datadir}/%{name}/xml
%{_datadir}/%{name}/xml/*.rng
%dir %{_sysconfdir}/cupshelpers
%config(noreplace) %{_sysconfdir}/cupshelpers/preferreddrivers.xml
%{python3_sitelib}/cupshelpers
%{python3_sitelib}/*.egg-info/

# Querencia Linux: Always build applet (removed RHEL conditional)
%files applet
%{_bindir}/%{name}-applet
%{_datadir}/%{name}/__pycache__/applet*
%{_datadir}/%{name}/applet.py*
%{_sysconfdir}/xdg/autostart/print-applet.desktop
%{_mandir}/man1/%{name}-applet.1*

%files udev
%{_prefix}/lib/udev/rules.d/*.rules
%{_prefix}/lib/udev/udev-*-printer
%ghost %dir %{_localstatedir}/run/udev-configure-printer
%ghost %verify(not md5 size mtime) %config(noreplace,missingok) %attr(0644,root,root) %{_localstatedir}/run/udev-configure-printer/usb-uris
%{_unitdir}/configure-printer@.service

# Querencia Linux: Always build main GUI package (removed RHEL conditional)
%files
%doc ChangeLog NEWS ABOUT-NLS AUTHORS ChangeLog-OLD
%license COPYING
%{_bindir}/%{name}
%{_bindir}/install-printerdriver
%{_datadir}/%{name}/__pycache__/check-device-ids*
%{_datadir}/%{name}/__pycache__/HIG*
%{_datadir}/%{name}/__pycache__/SearchCriterion*
%{_datadir}/%{name}/__pycache__/serversettings*
%{_datadir}/%{name}/__pycache__/system-config-printer*
%{_datadir}/%{name}/__pycache__/ToolbarSearchEntry*
%{_datadir}/%{name}/__pycache__/userdefault*
%{_datadir}/%{name}/__pycache__/install-printerdriver*
%{_datadir}/%{name}/check-device-ids.py*
%{_datadir}/%{name}/HIG.py*
%{_datadir}/%{name}/SearchCriterion.py*
%{_datadir}/%{name}/serversettings.py*
%{_datadir}/%{name}/system-config-printer.py*
%{_datadir}/%{name}/ToolbarSearchEntry.py*
%{_datadir}/%{name}/userdefault.py*
%{_datadir}/%{name}/troubleshoot
%{_datadir}/%{name}/icons
%{_datadir}/%{name}/install-printerdriver.py*
%dir %{_datadir}/%{name}/xml/__pycache__
%{_datadir}/%{name}/xml/__pycache__/*
%{_datadir}/%{name}/xml/validate.py*
%dir %{_datadir}/%{name}/ui
%{_datadir}/%{name}/ui/*.ui
%{_datadir}/applications/system-config-printer.desktop
%{_datadir}/metainfo/%{name}.appdata.xml
%{_mandir}/man1/%{name}.1*

%post
%{_bindir}/rm -f /var/cache/foomatic/foomatic.pickle
exit 0

%changelog
* Fri Mar 13 2026 Querencia Linux <querencia@endegelaende.github.io> - 1.5.18-16.querencia1
- Enable full GUI build on EL10 (remove RHEL>8 conditionals)
- Always build -applet subpackage
- Keep all GUI files in install (remove rm -rf block)

* Fri Sep 19 2025 Python Maint <python-maint@redhat.com> - 1.5.18-16
- Rebuilt for Python 3.14.0rc3 bytecode

* Fri Aug 15 2025 Python Maint <python-maint@redhat.com> - 1.5.18-15
- Rebuilt for Python 3.14.0rc2 bytecode

* Fri Jul 25 2025 Fedora Release Engineering <releng@fedoraproject.org> - 1.5.18-14
- Rebuilt for https://fedoraproject.org/wiki/Fedora_43_Mass_Rebuild

* Mon Jun 02 2025 Python Maint <python-maint@redhat.com> - 1.5.18-13
- Rebuilt for Python 3.14

* Sun Jan 19 2025 Fedora Release Engineering <releng@fedoraproject.org> - 1.5.18-12
- Rebuilt for https://fedoraproject.org/wiki/Fedora_42_Mass_Rebuild

* Sat Jul 20 2024 Fedora Release Engineering <releng@fedoraproject.org> - 1.5.18-11
- Rebuilt for https://fedoraproject.org/wiki/Fedora_41_Mass_Rebuild

* Fri Jun 07 2024 Python Maint <python-maint@redhat.com> - 1.5.18-10
- Rebuilt for Python 3.13

* Wed Mar 20 2024 Zdenek Dohnal <zdohnal@redhat.com> - 1.5.18-9
- fix possible udev service failure if USB device is already handled

* Thu Feb 22 2024 Zdenek Dohnal <zdohnal@redhat.com> - 1.5.18-8
- get rid of dependency on pycurl (we use urllib from python3)

* Tue Jan 23 2024 Zdenek Dohnal <zdohnal@redhat.com> - 1.5.18-7
- 2259526 - FTBFS s-c-p due missing distutils

* Thu Nov 23 2023 Zdenek Dohnal <zdohnal@redhat.com> - 1.5.18-6
- SPDX migration

* Sat Jul 22 2023 Fedora Release Engineering <releng@fedoraproject.org> - 1.5.18-5
- Rebuilt for https://fedoraproject.org/wiki/Fedora_39_Mass_Rebuild

* Tue Jun 13 2023 Python Maint <python-maint@redhat.com> - 1.5.18-4
- Rebuilt for Python 3.12

* Tue Mar 14 2023 Zdenek Dohnal <zdohnal@redhat.com> - 1.5.18-3
- 2178027 - fix crash in options.py

* Sat Jan 21 2023 Fedora Release Engineering <releng@fedoraproject.org> - 1.5.18-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_38_Mass_Rebuild

* Tue Sep 06 2022 Zdenek Dohnal <zdohnal@redhat.com> - 1.5.18-1
- 1.5.18
