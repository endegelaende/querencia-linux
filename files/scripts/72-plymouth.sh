#!/usr/bin/env bash
# Querencia Linux -- Plymouth Boot Splash
# Uses pre-rendered PNG splash image (querencia1.png) directly.
# No SVG conversion or ImageMagick needed — simpler and more reliable.
set -xeuo pipefail

# Install Plymouth and the script plugin (allows custom splash screens)
dnf install -y plymouth plymouth-system-theme
dnf install -y plymouth-plugin-two-step || true
dnf install -y plymouth-plugin-script || true

# ---- Create Querencia Plymouth Theme -----------------------------------------
THEME_DIR="/usr/share/plymouth/themes/querencia"
mkdir -p "${THEME_DIR}"

# Copy pre-rendered splash image from build context (mounted at /ctx)
# querencia1.png = 1920x1080, black background, centered logo with frame
SPLASH_SRC="/ctx/assets/querencia1.png"

if [ -f "${SPLASH_SRC}" ]; then
    cp "${SPLASH_SRC}" "${THEME_DIR}/splash.png"
    echo "Splash image copied from build context."
else
    echo "WARNING: ${SPLASH_SRC} not found — Plymouth theme will have no splash image."
fi

# Also copy querencia2.png as watermark (dark variant, logo bottom-left)
if [ -f "/ctx/assets/querencia2.png" ]; then
    cp "/ctx/assets/querencia2.png" "${THEME_DIR}/watermark.png"
fi

# ---- Desktop & Login Wallpapers ----------------------------------------------
# Copy all wallpaper PNGs to /usr/share/backgrounds/querencia/ so they are
# available as desktop wallpaper (MATE/dconf) and LightDM greeter background.
WALLPAPER_DIR="/usr/share/backgrounds/querencia"
mkdir -p "${WALLPAPER_DIR}"

for png in /ctx/assets/querencia*.png; do
    [ -f "$png" ] && cp "$png" "${WALLPAPER_DIR}/$(basename "$png")"
done

# querencia3.png = light variant with arches → default desktop wallpaper
# querencia2.png = dark variant, logo bottom-left → LightDM greeter background
# querencia1.png = black with centered logo → Plymouth boot splash

echo "Wallpapers installed to ${WALLPAPER_DIR}/"

# ---- Plymouth Script (shows full-screen splash image) ------------------------
cat > "${THEME_DIR}/querencia.script" <<'PLYSCRIPT'
# Querencia Linux -- Plymouth boot splash script
# Displays a full-screen centered splash image on a black background.
# Handles password prompts (LUKS) and boot messages gracefully.

# ---- Background & Splash Image -----------------------------------------------

Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

splash_image = Image("splash.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
image_width = splash_image.GetWidth();
image_height = splash_image.GetHeight();

# Scale to fit (contain mode) — full logo always visible
scale_x = screen_width / image_width;
scale_y = screen_height / image_height;

if (scale_x < scale_y)
    scale = scale_x;
else
    scale = scale_y;

scaled_width = Math.Int(image_width * scale);
scaled_height = Math.Int(image_height * scale);
pos_x = Math.Int((screen_width - scaled_width) / 2);
pos_y = Math.Int((screen_height - scaled_height) / 2);

scaled_image = splash_image.Scale(scaled_width, scaled_height);
splash_sprite = Sprite(scaled_image);
splash_sprite.SetPosition(pos_x, pos_y, 0);

# ---- Progress indicator (subtle pulsing dot) ---------------------------------


# Draw a small #C75230 dot for the activity indicator
dot_image = Image.Text(".", 0.78, 0.32, 0.19);  # #C75230 as RGB fractions
dot_sprite = Sprite(dot_image);
dot_sprite.SetPosition(screen_width / 2 - 4, screen_height * 0.85, 10);
dot_sprite.SetOpacity(0);

pulse_direction = 1;
pulse_opacity = 0;

fun refresh_callback ()
{
    global.pulse_opacity += global.pulse_direction * 0.02;
    if (global.pulse_opacity > 1)
    {
        global.pulse_opacity = 1;
        global.pulse_direction = -1;
    }
    if (global.pulse_opacity < 0)
    {
        global.pulse_opacity = 0;
        global.pulse_direction = 1;
    }
    dot_sprite.SetOpacity(global.pulse_opacity);
}

Plymouth.SetRefreshFunction(refresh_callback);

# ---- Password prompt (for LUKS encrypted disks) -----------------------------

# State for password dialog
password_label_sprite = Sprite();
password_entry_sprite = Sprite();
bullet_string = "";

fun display_password_callback (prompt, bullets)
{
    global.bullet_string = "";
    for (i = 0; i < bullets; i++)
        global.bullet_string += "●";

    # Prompt label (e.g., "Enter passphrase for disk ...")
    prompt_image = Image.Text(prompt, 0.78, 0.32, 0.19);  # #C75230
    password_label_sprite.SetImage(prompt_image);
    label_width = prompt_image.GetWidth();
    password_label_sprite.SetPosition(
        screen_width / 2 - label_width / 2,
        screen_height * 0.65,
        100
    );

    # Bullet display (password dots)
    if (global.bullet_string != "")
    {
        bullet_image = Image.Text(global.bullet_string, 0.97, 0.97, 0.95);  # light gray
        password_entry_sprite.SetImage(bullet_image);
        bullet_width = bullet_image.GetWidth();
        password_entry_sprite.SetPosition(
            screen_width / 2 - bullet_width / 2,
            screen_height * 0.70,
            100
        );
    }
    else
    {
        # No bullets yet — show a subtle cursor line
        cursor_image = Image.Text("_", 0.53, 0.53, 0.50);  # gray
        password_entry_sprite.SetImage(cursor_image);
        cursor_width = cursor_image.GetWidth();
        password_entry_sprite.SetPosition(
            screen_width / 2 - cursor_width / 2,
            screen_height * 0.70,
            100
        );
    }
}

Plymouth.SetDisplayPasswordFunction(display_password_callback);

# ---- Normal boot prompt (rare, but handle it) --------------------------------

fun display_normal_callback ()
{
    # Nothing special needed — splash stays visible
}

Plymouth.SetDisplayNormalFunction(display_normal_callback);

# ---- Message display (fsck, boot status, etc.) -------------------------------

message_sprites = [];
message_count = 0;

fun message_callback (text)
{
    # Show boot messages near the bottom of the screen in a subtle gray
    if (text == "")
        return;

    msg_image = Image.Text(text, 0.53, 0.53, 0.50);  # #888888 gray
    msg_sprite = Sprite(msg_image);
    msg_width = msg_image.GetWidth();
    msg_sprite.SetPosition(
        screen_width / 2 - msg_width / 2,
        screen_height * 0.92 + message_count * 18,
        50
    );

    # Keep track of messages (show last 3 max)
    if (global.message_count >= 3)
    {
        global.message_sprites[global.message_count - 3].SetOpacity(0);
    }
    global.message_sprites[global.message_count] = msg_sprite;
    global.message_count++;
}

Plymouth.SetMessageFunction(message_callback);

# ---- Boot progress -----------------------------------------------------------

fun boot_progress_callback (duration, progress)
{
    # We could use this to fade in the splash or animate progress
    # For now, the pulsing dot provides activity feedback
}

Plymouth.SetBootProgressFunction(boot_progress_callback);

# ---- Quit callback -----------------------------------------------------------

fun quit_callback ()
{
    # Fade out could be added here, but Plymouth handles transitions
}

Plymouth.SetQuitFunction(quit_callback);
PLYSCRIPT

# ---- Theme descriptor (script plugin) ----------------------------------------
cat > "${THEME_DIR}/querencia.plymouth" <<'PLYMOUTH'
[Plymouth Theme]
Name=Querencia Linux
Description=Querencia Linux boot splash — "Where Linux Feels at Home"
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/querencia
ScriptFile=/usr/share/plymouth/themes/querencia/querencia.script
PLYMOUTH

# ---- Fallback: if script plugin is not available, use two-step ---------------
if ! rpm -q plymouth-plugin-script &>/dev/null; then
    echo "plymouth-plugin-script not available, falling back to two-step theme"

    # For two-step, use the full splash as the logo — it will be centered
    if [ -f "${THEME_DIR}/splash.png" ]; then
        cp "${THEME_DIR}/splash.png" "${THEME_DIR}/logo.png"
    fi

    cat > "${THEME_DIR}/querencia.plymouth" <<'PLYMOUTH'
[Plymouth Theme]
Name=Querencia Linux
Description=Querencia Linux boot splash — "Where Linux Feels at Home"
ModuleName=two-step

[two-step]
ImageDir=/usr/share/plymouth/themes/querencia
HorizontalAlignment=.5
VerticalAlignment=.5
Transition=none
TransitionDuration=0.0
BackgroundStartColor=0x000000
BackgroundEndColor=0x000000
PLYMOUTH

    # Symlink spinner frames from the built-in spinner theme
    SPINNER_SRC="/usr/share/plymouth/themes/spinner"
    if [ -d "${SPINNER_SRC}" ]; then
        for f in "${SPINNER_SRC}"/throbber-*.png; do
            [ -f "$f" ] && ln -sf "$f" "${THEME_DIR}/$(basename "$f")"
        done
        for f in "${SPINNER_SRC}"/animation-*.png "${SPINNER_SRC}"/lock.png; do
            [ -f "$f" ] && ln -sf "$f" "${THEME_DIR}/$(basename "$f")"
        done
    fi
fi

# ---- Set as default theme ----------------------------------------------------
plymouth-set-default-theme querencia 2>/dev/null || true

# Note: dracut --force is NOT needed here. bootc regenerates the initramfs
# at deploy time and will automatically include the Plymouth theme since
# it's installed in /usr/share/plymouth/themes/ and set as default.

echo "Plymouth theme 'querencia' installed and set as default."
