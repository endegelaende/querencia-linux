#!/usr/bin/python3
# -*- coding: utf-8 -*-
# =============================================================================
# Querencia Linux — Welcome Center
# "Where Linux Feels at Home"
#
# Inspired by Linux Mint's mintwelcome, completely rewritten for
# Querencia Linux — an atomic/immutable desktop based on AlmaLinux 10
# with MATE Desktop.
#
# Dependencies: Python 3, GTK 3.0 (gi), no external packages.
# =============================================================================

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")

import json
import os
import platform
import subprocess
import sys

from gi.repository import Gdk, Gio, GLib, Gtk, Pango

# =============================================================================
# Constants
# =============================================================================

APP_ID = "org.querencia.welcome"
APP_TITLE = "Welcome to Querencia Linux"
WINDOW_WIDTH = 850
WINDOW_HEIGHT = 550

TERRACOTTA = "#C75230"
TERRACOTTA_DARK = "#A33D1E"
TERRACOTTA_LIGHT = "#F4BDAD"
TERRACOTTA_BG = "#FDF0EC"

CONFIG_DIR = os.path.expanduser("~/.config/querencia-welcome")
NORUN_FLAG = os.path.join(CONFIG_DIR, "norun.flag")
OS_RELEASE_PATH = "/usr/lib/os-release"
IMAGE_INFO_PATH = "/usr/share/querencia/image-info.json"

# =============================================================================
# CSS
# =============================================================================

CSS = f"""
/* Terracotta accent for suggested-action buttons */
button.suggested-action {{
    background-image: none;
    background-color: {TERRACOTTA};
    color: #FFFFFF;
    border: none;
    border-radius: 5px;
    padding: 8px 20px;
    font-weight: bold;
}}
button.suggested-action:hover {{
    background-color: {TERRACOTTA_DARK};
}}
button.suggested-action:active {{
    background-color: #8C2E14;
}}

/* Welcome title */
.welcome-title {{
    color: {TERRACOTTA};
}}

/* Subtitle */
.welcome-subtitle {{
    color: #6B5B4D;
}}

/* Section heading inside pages */
.section-heading {{
    color: {TERRACOTTA};
    font-weight: bold;
}}

/* Version badge */
.version-badge {{
    background-color: {TERRACOTTA_BG};
    border: 1px solid {TERRACOTTA_LIGHT};
    border-radius: 12px;
    padding: 4px 14px;
    color: {TERRACOTTA};
    font-size: 0.9em;
}}

/* Card-style frames */
.card-frame {{
    background-color: @theme_bg_color;
    border: 1px solid alpha(@theme_fg_color, 0.12);
    border-radius: 8px;
    padding: 12px;
}}

/* Info grid labels */
.info-key {{
    font-weight: bold;
    color: #6B5B4D;
}}
.info-value {{
    color: @theme_fg_color;
}}

/* Sidebar styling — terracotta highlight for selected row */
.sidebar-listbox row:selected {{
    background-color: {TERRACOTTA};
    color: #FFFFFF;
}}
.sidebar-listbox row:selected label {{
    color: #FFFFFF;
}}
.sidebar-listbox row:selected image {{
    color: #FFFFFF;
}}
.sidebar-listbox row {{
    padding: 10px 14px;
    border-radius: 0;
}}
.sidebar-listbox {{
    background-color: @theme_bg_color;
}}

/* Note box */
.note-box {{
    background-color: {TERRACOTTA_BG};
    border: 1px solid {TERRACOTTA_LIGHT};
    border-radius: 6px;
    padding: 12px;
}}
.note-box label {{
    color: {TERRACOTTA_DARK};
}}

/* ujust command row */
.ujust-row {{
    border: 1px solid alpha(@theme_fg_color, 0.08);
    border-radius: 6px;
    padding: 6px 12px;
}}
.ujust-row:hover {{
    background-color: alpha({TERRACOTTA}, 0.06);
}}

/* Link-style buttons */
.link-row {{
    border: 1px solid alpha(@theme_fg_color, 0.08);
    border-radius: 6px;
    padding: 8px 14px;
}}
.link-row:hover {{
    background-color: alpha({TERRACOTTA}, 0.06);
}}

/* Software method cards */
.method-card {{
    background-color: @theme_bg_color;
    border: 1px solid alpha(@theme_fg_color, 0.12);
    border-radius: 8px;
    padding: 16px;
}}

/* Bottom toolbar */
.bottom-toolbar {{
    border-top: 1px solid alpha(@theme_fg_color, 0.12);
    padding: 8px 16px;
}}
"""


# =============================================================================
# System info helpers
# =============================================================================


def read_os_release():
    """Parse /usr/lib/os-release into a dict."""
    data = {}
    try:
        with open(OS_RELEASE_PATH, "r") as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    key, _, value = line.partition("=")
                    # Strip surrounding quotes
                    value = value.strip().strip('"').strip("'")
                    data[key] = value
    except Exception:
        pass
    return data


def read_image_info():
    """Read /usr/share/querencia/image-info.json."""
    try:
        with open(IMAGE_INFO_PATH, "r") as f:
            return json.load(f)
    except Exception:
        return {}


def get_pretty_name():
    os_rel = read_os_release()
    return os_rel.get("PRETTY_NAME", "Querencia Linux")


def get_gpu_variant():
    info = read_image_info()
    return info.get("gpu-variant", "Unknown")


def get_image_ref():
    info = read_image_info()
    return info.get("image-ref", "Unknown")


def get_build_date():
    info = read_image_info()
    return info.get("build-date", "Unknown")


def get_kernel():
    try:
        return platform.release()
    except Exception:
        return "Unknown"


def get_arch():
    try:
        return platform.machine()
    except Exception:
        return "Unknown"


def collect_system_info_text():
    """Return a multi-line string with all system info for clipboard copy."""
    lines = [
        f"OS: {get_pretty_name()}",
        f"GPU Variant: {get_gpu_variant()}",
        f"Desktop: MATE",
        f"Base: AlmaLinux 10",
        f"Image: {get_image_ref()}",
        f"Build Date: {get_build_date()}",
        f"Kernel: {get_kernel()}",
        f"Architecture: {get_arch()}",
    ]
    return "\n".join(lines)


# =============================================================================
# Launcher helpers
# =============================================================================


def launch_command(cmd, shell=False):
    """Launch a command in the background. cmd is a list or string."""
    try:
        if shell:
            subprocess.Popen(cmd, shell=True)
        else:
            subprocess.Popen(cmd)
    except Exception as e:
        dialog = Gtk.MessageDialog(
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text="Failed to launch command",
        )
        dialog.format_secondary_text(str(e))
        dialog.run()
        dialog.destroy()


def open_url(url):
    """Open a URL with xdg-open."""
    launch_command(["xdg-open", url])


def run_ujust_in_terminal(recipe):
    """Run a ujust command inside mate-terminal."""
    launch_command(
        [
            "mate-terminal",
            "-e",
            f"bash -c 'ujust {recipe}; echo; read -r -p \"Press Enter to close...\"'",
        ]
    )


# =============================================================================
# Widget factory helpers
# =============================================================================


def make_label(text, wrap=True, xalign=0.0, selectable=False, markup=False):
    label = Gtk.Label()
    if markup:
        label.set_markup(text)
    else:
        label.set_text(text)
    label.set_xalign(xalign)
    label.set_yalign(0.0)
    if wrap:
        label.set_line_wrap(True)
        label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
        label.set_max_width_chars(70)
    label.set_selectable(selectable)
    return label


def make_heading(text, scale=1.2):
    label = Gtk.Label()
    label.set_markup(f"<b>{GLib.markup_escape_text(text)}</b>")
    label.set_xalign(0.0)
    attrs = Pango.AttrList()
    attrs.insert(Pango.attr_scale_new(scale))
    label.set_attributes(attrs)
    label.get_style_context().add_class("section-heading")
    return label


def make_icon_button(label_text, icon_name, style_class=None, tooltip=None):
    btn = Gtk.Button()
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
    if icon_name:
        img = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.BUTTON)
        box.pack_start(img, False, False, 0)
    lbl = Gtk.Label(label=label_text)
    box.pack_start(lbl, False, False, 0)
    btn.add(box)
    if style_class:
        btn.get_style_context().add_class(style_class)
    if tooltip:
        btn.set_tooltip_text(tooltip)
    return btn


# =============================================================================
# Page builders
# =============================================================================


def build_welcome_page(stack):
    """Page 1: Welcome."""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    page.set_border_width(24)
    page.set_valign(Gtk.Align.START)

    # Title
    title = Gtk.Label()
    title.set_markup(f"<b>Welcome to Querencia Linux</b>")
    title.set_xalign(0.0)
    attrs = Pango.AttrList()
    attrs.insert(Pango.attr_scale_new(1.6))
    title.set_attributes(attrs)
    title.get_style_context().add_class("welcome-title")
    page.pack_start(title, False, False, 0)

    # Subtitle
    subtitle = Gtk.Label()
    subtitle.set_markup("<i>Where Linux Feels at Home</i>")
    subtitle.set_xalign(0.0)
    attrs2 = Pango.AttrList()
    attrs2.insert(Pango.attr_scale_new(1.1))
    subtitle.set_attributes(attrs2)
    subtitle.get_style_context().add_class("welcome-subtitle")
    page.pack_start(subtitle, False, False, 0)

    # Separator
    page.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4
    )

    # Description
    desc = make_label(
        "Querencia Linux is an atomic, immutable desktop built on AlmaLinux 10 "
        "with the MATE Desktop. Your system updates itself as a whole image — "
        "safe, reliable, and always rollback-ready."
    )
    page.pack_start(desc, False, False, 0)

    # Version badge
    pretty = get_pretty_name()
    gpu = get_gpu_variant()
    badge_text = pretty
    if gpu and gpu != "Unknown":
        badge_text = f"{pretty}"  # GPU is already in PRETTY_NAME

    badge_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
    badge_label = Gtk.Label()
    badge_label.set_text(badge_text)
    badge_label.get_style_context().add_class("version-badge")
    badge_box.pack_start(badge_label, False, False, 0)
    page.pack_start(badge_box, False, False, 4)

    # Spacer
    page.pack_start(Gtk.Box(), True, True, 0)

    # "Let's get started!" button
    btn = Gtk.Button(label="Let's get started!")
    btn.get_style_context().add_class("suggested-action")
    btn.set_halign(Gtk.Align.START)
    btn.set_size_request(200, -1)
    btn.connect("clicked", lambda _: stack.set_visible_child_name("first-steps"))
    page.pack_start(btn, False, False, 0)

    return page


def _make_first_step_row(icon_name, title, description, callback):
    """Build a single first-step item row."""
    frame = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
    frame.get_style_context().add_class("card-frame")
    frame.set_border_width(4)

    # Icon
    icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.DIALOG)
    icon.set_pixel_size(40)
    icon.set_valign(Gtk.Align.CENTER)
    frame.pack_start(icon, False, False, 0)

    # Text box
    text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    text_box.set_valign(Gtk.Align.CENTER)

    title_label = Gtk.Label()
    title_label.set_markup(f"<b>{GLib.markup_escape_text(title)}</b>")
    title_label.set_xalign(0.0)
    text_box.pack_start(title_label, False, False, 0)

    desc_label = make_label(description)
    desc_label.set_line_wrap(True)
    desc_label.set_max_width_chars(55)
    text_box.pack_start(desc_label, False, False, 0)

    frame.pack_start(text_box, True, True, 0)

    # Open button
    btn = Gtk.Button(label="Open")
    btn.set_valign(Gtk.Align.CENTER)
    btn.connect("clicked", callback)
    frame.pack_start(btn, False, False, 0)

    return frame


def build_first_steps_page():
    """Page 2: First Steps."""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    page.set_border_width(24)
    page.set_valign(Gtk.Align.START)

    heading = make_heading("First Steps", 1.3)
    page.pack_start(heading, False, False, 0)

    desc = make_label(
        'Get familiar with your new system. Click "Open" to launch each tool.'
    )
    page.pack_start(desc, False, False, 0)

    page.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 2
    )

    # Scrollable area for the items
    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

    items_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)

    # Appearance
    items_box.pack_start(
        _make_first_step_row(
            "preferences-desktop-theme-symbolic",
            "Appearance",
            "Customize your desktop theme, icons, and fonts. Querencia comes "
            "pre-configured with the BlueMenta theme.",
            lambda _: launch_command(["mate-appearance-properties"]),
        ),
        False,
        False,
        0,
    )

    # App Store (Warehouse)
    def _open_warehouse(_btn):
        try:
            subprocess.Popen(["flatpak", "run", "io.github.flattool.Warehouse"])
        except Exception:
            dialog = Gtk.MessageDialog(
                message_type=Gtk.MessageType.INFO,
                buttons=Gtk.ButtonsType.OK,
                text="Warehouse not found",
            )
            dialog.format_secondary_text(
                "Warehouse doesn't appear to be installed yet. "
                "It will be set up automatically on first boot, or you can run:\n\n"
                "flatpak install flathub io.github.flattool.Warehouse"
            )
            dialog.run()
            dialog.destroy()

    items_box.pack_start(
        _make_first_step_row(
            "system-software-install-symbolic",
            "App Store",
            "Browse and install apps from Flathub using Warehouse. On an atomic "
            "system, all desktop apps come as Flatpaks.",
            _open_warehouse,
        ),
        False,
        False,
        0,
    )

    # System Settings
    items_box.pack_start(
        _make_first_step_row(
            "preferences-system-symbolic",
            "System Settings",
            "Configure displays, keyboard, mouse, network, and more.",
            lambda _: launch_command(["mate-control-center"]),
        ),
        False,
        False,
        0,
    )

    # Firewall
    items_box.pack_start(
        _make_first_step_row(
            "security-high-symbolic",
            "Firewall",
            "Your firewall is enabled by default. Open this tool to manage "
            "rules and permissions.",
            lambda _: launch_command(["firewall-config"]),
        ),
        False,
        False,
        0,
    )

    # Updates
    items_box.pack_start(
        _make_first_step_row(
            "software-update-available-symbolic",
            "Updates",
            "Querencia updates automatically every 6 hours. You can also update "
            "manually using the terminal. Updates are safe — you can always roll back.",
            lambda _: run_ujust_in_terminal("update"),
        ),
        False,
        False,
        0,
    )

    scroll.add(items_box)
    page.pack_start(scroll, True, True, 0)

    return page


def _make_method_card(icon_name, title, tag, description, example_cmd=None):
    """Build a software installation method card."""
    frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    frame.get_style_context().add_class("method-card")

    # Header row
    header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR)
    header.pack_start(icon, False, False, 0)

    title_label = Gtk.Label()
    title_label.set_markup(f"<b>{GLib.markup_escape_text(title)}</b>")
    title_label.set_xalign(0.0)
    header.pack_start(title_label, True, True, 0)

    if tag:
        tag_label = Gtk.Label()
        tag_label.set_markup(f"<small><i>{GLib.markup_escape_text(tag)}</i></small>")
        tag_label.get_style_context().add_class("version-badge")
        header.pack_start(tag_label, False, False, 0)

    frame.pack_start(header, False, False, 0)

    # Description
    desc = make_label(description)
    frame.pack_start(desc, False, False, 0)

    # Example command
    if example_cmd:
        cmd_label = Gtk.Label()
        cmd_label.set_markup(
            f"<tt><small>{GLib.markup_escape_text(example_cmd)}</small></tt>"
        )
        cmd_label.set_xalign(0.0)
        cmd_label.set_selectable(True)
        frame.pack_start(cmd_label, False, False, 0)

    return frame


def build_software_page():
    """Page 3: Installing Software."""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    page.set_border_width(24)
    page.set_valign(Gtk.Align.START)

    heading = make_heading("Installing Software", 1.3)
    page.pack_start(heading, False, False, 0)

    desc = make_label(
        "Querencia Linux is an atomic system. Software is installed through "
        "three methods, each suited for different use cases."
    )
    page.pack_start(desc, False, False, 0)

    page.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 2
    )

    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

    cards_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)

    # Flatpak
    cards_box.pack_start(
        _make_method_card(
            "system-software-install-symbolic",
            "Flatpak",
            "recommended",
            "Desktop apps like LibreOffice, VLC, and GIMP come from Flathub. "
            "Open Warehouse to browse, or install from the terminal.",
            "flatpak install flathub org.example.App",
        ),
        False,
        False,
        0,
    )

    # Micromamba
    cards_box.pack_start(
        _make_method_card(
            "utilities-terminal-symbolic",
            "Micromamba",
            "CLI tools",
            "CLI tools and developer packages. Works like conda but faster. "
            "Pre-installed — just run commands in your terminal.",
            "micromamba install ripgrep bat fd-find",
        ),
        False,
        False,
        0,
    )

    # Distrobox
    cards_box.pack_start(
        _make_method_card(
            "computer-symbolic",
            "Distrobox",
            "containers",
            "Need a full mutable Linux environment? Distrobox gives you a "
            "disposable container with dnf or apt. Perfect for development.",
            "distrobox create --name dev --image fedora:latest",
        ),
        False,
        False,
        0,
    )

    scroll.add(cards_box)
    page.pack_start(scroll, True, True, 0)

    # Note box
    note_frame = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    note_frame.get_style_context().add_class("note-box")
    note_icon = Gtk.Image.new_from_icon_name(
        "dialog-information-symbolic", Gtk.IconSize.MENU
    )
    note_frame.pack_start(note_icon, False, False, 0)
    note_label = make_label(
        "This is an atomic system — <tt>dnf install</tt> on the host is not available. "
        "This is by design for reliability.",
        markup=True,
    )
    note_frame.pack_start(note_label, True, True, 0)
    page.pack_start(note_frame, False, False, 4)

    return page


def build_sysinfo_page():
    """Page 4: System Info."""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    page.set_border_width(24)
    page.set_valign(Gtk.Align.START)

    heading = make_heading("System Information", 1.3)
    page.pack_start(heading, False, False, 0)

    page.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 2
    )

    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

    content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)

    # Info grid
    grid = Gtk.Grid()
    grid.set_column_spacing(16)
    grid.set_row_spacing(8)

    info_items = [
        ("OS", get_pretty_name()),
        ("GPU Variant", get_gpu_variant()),
        ("Desktop", "MATE"),
        ("Base", "AlmaLinux 10"),
        ("Image", get_image_ref()),
        ("Build Date", get_build_date()),
        ("Kernel", get_kernel()),
        ("Architecture", get_arch()),
    ]

    for row_idx, (key, value) in enumerate(info_items):
        key_label = Gtk.Label(label=f"{key}:")
        key_label.set_xalign(1.0)
        key_label.get_style_context().add_class("info-key")
        grid.attach(key_label, 0, row_idx, 1, 1)

        val_label = Gtk.Label(label=value)
        val_label.set_xalign(0.0)
        val_label.set_selectable(True)
        val_label.set_line_wrap(True)
        val_label.set_max_width_chars(50)
        val_label.get_style_context().add_class("info-value")
        grid.attach(val_label, 1, row_idx, 1, 1)

    content_box.pack_start(grid, False, False, 0)

    # Buttons row
    btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

    copy_btn = make_icon_button("Copy System Info", "edit-copy-symbolic")
    copy_btn.connect("clicked", _on_copy_sysinfo)
    btn_box.pack_start(copy_btn, False, False, 0)

    term_btn = make_icon_button("Open Terminal", "utilities-terminal-symbolic")
    term_btn.connect("clicked", lambda _: launch_command(["mate-terminal"]))
    btn_box.pack_start(term_btn, False, False, 0)

    content_box.pack_start(btn_box, False, False, 0)

    # ujust quick commands
    content_box.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4
    )

    ujust_heading = make_heading("Quick Commands (ujust)", 1.1)
    content_box.pack_start(ujust_heading, False, False, 0)

    ujust_desc = make_label("Click any command to run it in a terminal window.")
    content_box.pack_start(ujust_desc, False, False, 0)

    ujust_commands = [
        ("ujust status", "Show image status", "status"),
        ("ujust update", "Update system", "update"),
        ("ujust rollback", "Roll back to previous image", "rollback"),
        ("ujust info", "System info (fastfetch)", "info"),
    ]

    for cmd_text, cmd_desc, recipe in ujust_commands:
        row = Gtk.Button()
        row.set_relief(Gtk.ReliefStyle.NONE)
        row.get_style_context().add_class("ujust-row")

        row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        cmd_label = Gtk.Label()
        cmd_label.set_markup(f"<tt><b>{GLib.markup_escape_text(cmd_text)}</b></tt>")
        cmd_label.set_xalign(0.0)
        row_box.pack_start(cmd_label, False, False, 0)

        dash_label = Gtk.Label(label="—")
        row_box.pack_start(dash_label, False, False, 0)

        desc_label = Gtk.Label(label=cmd_desc)
        desc_label.set_xalign(0.0)
        row_box.pack_start(desc_label, True, True, 0)

        run_icon = Gtk.Image.new_from_icon_name(
            "media-playback-start-symbolic", Gtk.IconSize.MENU
        )
        row_box.pack_start(run_icon, False, False, 0)

        row.add(row_box)
        row.connect("clicked", lambda _btn, r=recipe: run_ujust_in_terminal(r))
        content_box.pack_start(row, False, False, 0)

    scroll.add(content_box)
    page.pack_start(scroll, True, True, 0)

    return page


def _on_copy_sysinfo(_btn):
    """Copy system info to clipboard."""
    text = collect_system_info_text()
    clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    clipboard.set_text(text, -1)
    clipboard.store()


def _make_link_row(icon_name, title, description, url):
    """Build a clickable link row."""
    row = Gtk.Button()
    row.set_relief(Gtk.ReliefStyle.NONE)
    row.get_style_context().add_class("link-row")

    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

    icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR)
    icon.set_pixel_size(24)
    box.pack_start(icon, False, False, 0)

    text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    title_label = Gtk.Label()
    title_label.set_markup(f"<b>{GLib.markup_escape_text(title)}</b>")
    title_label.set_xalign(0.0)
    text_box.pack_start(title_label, False, False, 0)

    desc_label = Gtk.Label()
    desc_label.set_markup(f"<small>{GLib.markup_escape_text(description)}</small>")
    desc_label.set_xalign(0.0)
    desc_label.set_line_wrap(True)
    desc_label.set_max_width_chars(50)
    text_box.pack_start(desc_label, False, False, 0)
    box.pack_start(text_box, True, True, 0)

    arrow = Gtk.Image.new_from_icon_name("go-next-symbolic", Gtk.IconSize.MENU)
    box.pack_start(arrow, False, False, 0)

    row.add(box)
    row.connect("clicked", lambda _: open_url(url))
    return row


def build_help_page():
    """Page 5: Help & Links."""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    page.set_border_width(24)
    page.set_valign(Gtk.Align.START)

    heading = make_heading("Help & Links", 1.3)
    page.pack_start(heading, False, False, 0)

    desc = make_label(
        "Querencia Linux is open source. Contributions, bug reports, "
        "and feedback are welcome!"
    )
    page.pack_start(desc, False, False, 0)

    page.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 2
    )

    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

    links_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)

    links_box.pack_start(
        _make_link_row(
            "web-browser-symbolic",
            "Website",
            "querencialinux.org — Project homepage and documentation",
            "https://querencialinux.org",
        ),
        False,
        False,
        0,
    )

    links_box.pack_start(
        _make_link_row(
            "text-x-script-symbolic",
            "GitHub",
            "Source code, build scripts, and configuration",
            "https://github.com/endegelaende/querencia-linux",
        ),
        False,
        False,
        0,
    )

    links_box.pack_start(
        _make_link_row(
            "computer-symbolic",
            "AlmaLinux",
            "The enterprise Linux distribution Querencia is built on",
            "https://almalinux.org",
        ),
        False,
        False,
        0,
    )

    links_box.pack_start(
        _make_link_row(
            "dialog-warning-symbolic",
            "Report a Bug",
            "Found an issue? Let us know on GitHub Issues",
            "https://github.com/endegelaende/querencia-linux/issues",
        ),
        False,
        False,
        0,
    )

    # Extra spacing then a community note
    links_box.pack_start(Gtk.Box(), False, False, 4)

    community_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    community_frame.get_style_context().add_class("card-frame")

    community_heading = Gtk.Label()
    community_heading.set_markup("<b>About Querencia Linux</b>")
    community_heading.set_xalign(0.0)
    community_frame.pack_start(community_heading, False, False, 0)

    community_text = make_label(
        "Querencia (Spanish: keh-REN-see-ah) means a place where one feels "
        "safe, a place from which one's strength of character is drawn — "
        "a place where you feel at home.\n\n"
        "This project aims to make Linux feel like that place. "
        "Built on the rock-solid foundation of AlmaLinux, with the familiarity "
        "of the MATE Desktop, and the safety of atomic updates."
    )
    community_frame.pack_start(community_text, False, False, 0)

    links_box.pack_start(community_frame, False, False, 0)

    scroll.add(links_box)
    page.pack_start(scroll, True, True, 0)

    return page


# =============================================================================
# Sidebar
# =============================================================================

PAGES = [
    ("welcome", "Welcome", "go-home-symbolic"),
    ("first-steps", "First Steps", "dialog-information-symbolic"),
    ("software", "Installing Software", "system-software-install-symbolic"),
    ("sysinfo", "System Info", "computer-symbolic"),
    ("help", "Help & Links", "help-browser-symbolic"),
]


def build_sidebar(stack):
    """Build a ListBox sidebar that switches the stack."""
    listbox = Gtk.ListBox()
    listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
    listbox.get_style_context().add_class("sidebar-listbox")

    for page_id, page_label, icon_name in PAGES:
        row = Gtk.ListBoxRow()
        row.page_id = page_id

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        box.set_border_width(4)

        icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.MENU)
        box.pack_start(icon, False, False, 0)

        label = Gtk.Label(label=page_label)
        label.set_xalign(0.0)
        box.pack_start(label, True, True, 0)

        row.add(box)
        listbox.add(row)

    def on_row_selected(_lb, row):
        if row is not None:
            stack.set_visible_child_name(row.page_id)

    listbox.connect("row-selected", on_row_selected)

    return listbox


# =============================================================================
# Main Window
# =============================================================================


class WelcomeWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title=APP_TITLE)
        self.set_default_size(WINDOW_WIDTH, WINDOW_HEIGHT)
        self.set_position(Gtk.WindowPosition.CENTER)

        # Load CSS
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(CSS.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        # HeaderBar
        header = Gtk.HeaderBar()
        header.set_show_close_button(True)
        header.set_title(APP_TITLE)
        header.set_subtitle("Where Linux Feels at Home")
        self.set_titlebar(header)

        # Main layout: vertical box containing content + bottom toolbar
        main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        # Content area: sidebar | stack
        content_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)

        # Stack (pages)
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_UP_DOWN)
        self.stack.set_transition_duration(200)

        # Add pages
        self.stack.add_named(build_welcome_page(self.stack), "welcome")
        self.stack.add_named(build_first_steps_page(), "first-steps")
        self.stack.add_named(build_software_page(), "software")
        self.stack.add_named(build_sysinfo_page(), "sysinfo")
        self.stack.add_named(build_help_page(), "help")

        # Sidebar
        sidebar_scroll = Gtk.ScrolledWindow()
        sidebar_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        sidebar_scroll.set_size_request(180, -1)

        self.sidebar = build_sidebar(self.stack)
        sidebar_scroll.add(self.sidebar)

        # Separator between sidebar and content
        sep = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)

        content_hbox.pack_start(sidebar_scroll, False, False, 0)
        content_hbox.pack_start(sep, False, False, 0)
        content_hbox.pack_start(self.stack, True, True, 0)

        main_vbox.pack_start(content_hbox, True, True, 0)

        # Bottom toolbar with "Show at startup" checkbox
        bottom_sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        main_vbox.pack_start(bottom_sep, False, False, 0)

        bottom_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        bottom_bar.get_style_context().add_class("bottom-toolbar")
        bottom_bar.set_border_width(6)

        self.startup_check = Gtk.CheckButton(label="Show this dialog at startup")
        self.startup_check.set_active(not os.path.exists(NORUN_FLAG))
        self.startup_check.connect("toggled", self._on_startup_toggled)
        bottom_bar.pack_start(self.startup_check, False, False, 0)

        main_vbox.pack_start(bottom_bar, False, False, 0)

        self.add(main_vbox)

        # Select first sidebar row
        first_row = self.sidebar.get_row_at_index(0)
        if first_row:
            self.sidebar.select_row(first_row)

        # Sync sidebar when stack changes (e.g. from "Let's get started" button)
        self.stack.connect("notify::visible-child-name", self._on_stack_changed)

    def _on_startup_toggled(self, check):
        """Handle the 'show at startup' checkbox."""
        if check.get_active():
            # Remove the flag file (show at startup)
            try:
                if os.path.exists(NORUN_FLAG):
                    os.remove(NORUN_FLAG)
            except Exception:
                pass
        else:
            # Create the flag file (don't show at startup)
            try:
                os.makedirs(CONFIG_DIR, exist_ok=True)
                with open(NORUN_FLAG, "w") as f:
                    f.write("1\n")
            except Exception:
                pass

    def _on_stack_changed(self, stack, _pspec):
        """Keep sidebar selection in sync when the stack page changes."""
        name = stack.get_visible_child_name()
        for idx, (page_id, _, _) in enumerate(PAGES):
            if page_id == name:
                row = self.sidebar.get_row_at_index(idx)
                if row:
                    self.sidebar.select_row(row)
                break


# =============================================================================
# Application
# =============================================================================


class WelcomeApp(Gtk.Application):
    def __init__(self):
        super().__init__(
            application_id=APP_ID,
            flags=Gio.ApplicationFlags.FLAGS_NONE,
        )
        self.window = None

    def do_activate(self):
        if not self.window:
            self.window = WelcomeWindow(self)
        self.window.show_all()
        self.window.present()

    def do_startup(self):
        Gtk.Application.do_startup(self)


# =============================================================================
# Entry point
# =============================================================================


def main():
    # If --norun-check is passed, exit silently if the norun flag exists.
    # This allows autostart entries to check without showing the window.
    if "--norun-check" in sys.argv:
        if os.path.exists(NORUN_FLAG):
            sys.exit(0)

    app = WelcomeApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
