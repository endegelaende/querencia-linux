#!/usr/bin/env bash
# Querencia Linux -- Multimedia Codecs (RPM Fusion)
# GStreamer + FFmpeg -- full H.264, H.265, AAC, VP9, AV1 support
set -xeuo pipefail

# Core GStreamer plugins (available in base repos)
dnf install -y \
    gstreamer1-plugins-base \
    gstreamer1-plugins-good \
    gstreamer1-plugins-bad-free

# Extended codecs from RPM Fusion (names vary across EL versions)
dnf install -y gstreamer1-plugins-ugly || true
dnf install -y gstreamer1-plugins-good-extras || true
dnf install -y gstreamer1-plugins-bad-freeworld || true
dnf install -y gstreamer1-plugin-openh264 || true
dnf install -y gstreamer1-libav || true
dnf install -y ffmpeg || true
dnf install -y ffmpeg-libs || true
dnf install -y x264-libs || true
dnf install -y x265-libs || true

# Fallback: if full ffmpeg was not available, try the restricted variant
rpm -q ffmpeg >/dev/null 2>&1 || dnf install -y ffmpeg-free || true
