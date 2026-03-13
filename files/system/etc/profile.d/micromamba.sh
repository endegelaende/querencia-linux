# Micromamba shell integration -- Querencia Linux
# The 'base' environment is created on first login by querencia-first-boot.
# It activates automatically so users can install packages right away:
#   micromamba install ripgrep bat fd-find
export MAMBA_ROOT_PREFIX="${HOME}/micromamba"
if [ -x /usr/local/bin/micromamba ]; then
    eval "$(/usr/local/bin/micromamba shell hook --shell bash)"
    # Auto-activate base environment if it exists
    if [ -d "${MAMBA_ROOT_PREFIX}/envs/base" ]; then
        micromamba activate base 2>/dev/null
    fi
fi
# Convenience aliases
alias mamba='micromamba'
alias conda='micromamba'
