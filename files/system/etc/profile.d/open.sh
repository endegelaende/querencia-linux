# xdg-open alias — macOS-like "open" command
# Backgrounds the process and redirects stderr so GTK warnings don't pollute the terminal.
# stdout is kept so xdg-open errors (e.g. "file not found") are still visible.
open() { xdg-open "$@" 2>/dev/null & }
