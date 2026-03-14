# Micromamba shell integration -- Querencia Linux
# The 'base' environment is created on first login by querencia-first-boot.
# It activates automatically so users can install packages right away:
#   micromamba install ripgrep bat fd-find
#
# Guard: this script uses bash-specific features (micromamba shell hook --shell bash).
# Skip silently if running in a non-bash shell (dash, sh, zsh without compat).
[ -z "$BASH_VERSION" ] && return 0 2>/dev/null || true

export MAMBA_ROOT_PREFIX="${HOME}/micromamba"
if [ -x /usr/bin/micromamba ]; then
    eval "$(/usr/bin/micromamba shell hook --shell bash)"
    # Auto-activate base environment if it exists
    if [ -d "${MAMBA_ROOT_PREFIX}/envs/base" ]; then
        micromamba activate base 2>/dev/null
    fi
    # Convenience aliases
    alias mamba='micromamba'
    alias conda='micromamba'
fi
