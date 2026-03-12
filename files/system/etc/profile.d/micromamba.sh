# Micromamba shell integration
export MAMBA_ROOT_PREFIX="${HOME}/micromamba"
if [ -x /usr/local/bin/micromamba ]; then
    eval "$(/usr/local/bin/micromamba shell hook --shell bash)"
fi
# Convenience aliases
alias mamba='micromamba'
alias conda='micromamba'
