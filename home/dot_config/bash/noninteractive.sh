# Sourced by non-interactive bash via BASH_ENV.
# Sources the persistent SSH agent env so tools (jj, git) can sign commits
# without needing SSH_AUTH_SOCK inherited from an interactive shell.
SSH_ENV="${HOME}/.ssh/agent.env"
if [[ -f "${SSH_ENV}" ]]; then
    # shellcheck disable=SC1090
    . "${SSH_ENV}" >/dev/null 2>&1
fi
