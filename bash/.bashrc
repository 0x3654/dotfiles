OS="$(uname -s)"

# Ghostty shell integration (macOS only)
if [[ "$OS" == "Darwin" ]] && [ -f /Applications/Ghostty.app/Contents/Resources/ghostty/shell-integration/bash/ghostty.bash ]; then
    . /Applications/Ghostty.app/Contents/Resources/ghostty/shell-integration/bash/ghostty.bash
fi

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

complete -W "\`grep -oE '^[a-zA-Z0-9_.-]+:([^=]|$)' Makefile | sed 's/[^a-zA-Z0-9_.-]*$//'\`" make

# ── PATH ──────────────────────────────────────────────────────────────────────

export PATH=/usr/local/bin:$PATH
export PATH="$HOME/.local/bin:$PATH"

if [[ "$OS" == "Darwin" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    export PATH="$PATH:$HOME/.lmstudio/bin"
    export PATH="$PATH:$HOME/.opencode/bin"
elif command -v brew &>/dev/null; then
    eval "$(brew shellenv)"
fi

# ── mcfly (shell history) ─────────────────────────────────────────────────────

command -v mcfly &>/dev/null && eval "$(mcfly init bash)"

# ── NVM ───────────────────────────────────────────────────────────────────────

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ── Ansible ───────────────────────────────────────────────────────────────────

export ANSIBLE_HOME="$HOME/.ansible"
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault
alias ansible-lint='ANSIBLE_HOME=$HOME/.ansible ansible-lint'

# ── ls ────────────────────────────────────────────────────────────────────────

if [[ "$OS" == "Darwin" ]] && command -v eza &>/dev/null; then
    alias ls='eza --icons=always --long --header --group-directories-first --git --group'
    alias la='eza --icons=always --long --header --group-directories-first --git --group --all'
else
    alias ls='ls --color=always -lh --group-directories-first'
    alias la='ls --color=always -lha --group-directories-first'
fi

# ── grc colors ────────────────────────────────────────────────────────────────

alias grep='grep --color=always'
alias diff='diff --color=always'
alias dir='dir --color=always'
alias dmesg='dmesg --color=always'

if command -v grc &>/dev/null; then
    alias cat="grc --colour=auto cat"
    alias dig="grc --colour=auto dig"
    alias gcc="grc --colour=auto gcc"
    alias g++="grc --colour=auto g++"
    alias head="grc --colour=auto head"
    alias log="grc --colour=auto log"
    alias mount="grc --colour=auto mount"
    alias mtr="grc --colour=auto mtr"
    alias netstat="grc --colour=auto netstat"
    alias ping="grc --colour=auto ping"
    alias ps="grc --colour=auto ps"
    alias traceroute="grc --colour=auto traceroute"
    alias zcat="grc --colour=auto zcat"
    alias zgrep="grc --colour=auto zgrep"
fi

# ── duf ───────────────────────────────────────────────────────────────────────

if command -v duf &>/dev/null; then
    if [[ "$OS" == "Darwin" ]]; then
        alias duf="duf --style ascii --output mountpoint,size,used,avail,usage,type / /Volumes/*torrent*"
    else
        alias duf="duf --only-mp /,/mnt/*"
    fi
    alias lduf="while true; do duf; sleep 1; done"
fi

# ── macOS-specific ────────────────────────────────────────────────────────────

if [[ "$OS" == "Darwin" ]]; then
    alias mtop='TERM=xterm-256color sudo mactop'

    lzd() {
        local context="${1:-desktop-linux}"
        local no_update="${2:-}"
        local force_build="${3:-}"
        local image="lazydocker-custom:latest"
        local src_dir="$HOME/code/lazydocker"

        if ! docker context inspect "$context" >/dev/null 2>&1; then
            # Check if SSH host alias exists in ~/.ssh/config
            if ssh -G "$context" >/dev/null 2>&1; then
                echo "Docker context '$context' not found, but SSH host '$context' exists."
                read -r -p "Create Docker context for ssh://$context? [y/N] " answer
                if [[ "$answer" =~ ^[Yy]$ ]]; then
                    docker context create "$context" --docker "host=ssh://$context"
                    echo "Context '$context' created."
                else
                    return 1
                fi
            else
                echo "Error: Docker context '$context' not found" >&2
                echo "Available contexts:" >&2
                docker context ls >&2
                return 1
            fi
        fi

        local docker_host
        docker_host=$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}')

        echo "Starting lazydocker for: $context ($docker_host)"

        if [ "$context" = "desktop-linux" ]; then
            docker rm -f lazydocker 2>/dev/null || true
        else
            docker rm -f "lazydocker-$context" 2>/dev/null || true
        fi

        local is_remote=false
        [[ "$docker_host" == ssh://* ]] && is_remote=true

        if ! docker image inspect "$image" &>/dev/null || [ "$force_build" = "--force-build" ]; then
            echo "Building lazydocker image..."
            if [ ! -d "$src_dir" ]; then
                echo "Cloning lazydocker repository..."
                git clone https://github.com/jesseduffield/lazydocker.git "$src_dir"
            fi
            (cd "$src_dir" && \
                sed 's/FROM scratch/FROM alpine:3.20\nRUN apk add --no-cache openssh-client/' Dockerfile | \
                docker buildx build --platform linux/arm64 -t "$image" -f - "$src_dir")
        elif [ "$no_update" != "--no-update" ] && [ -d "$src_dir" ]; then
            echo "Checking for lazydocker updates..."
            (cd "$src_dir" && git fetch --quiet)
            local local_head remote_head
            local_head=$(cd "$src_dir" && git rev-parse HEAD)
            remote_head=$(cd "$src_dir" && git rev-parse @{u})
            if [ "$local_head" != "$remote_head" ]; then
                echo "Updates available, rebuilding..."
                (cd "$src_dir" && git pull && \
                    sed 's/FROM scratch/FROM alpine:3.20\nRUN apk add --no-cache openssh-client/' Dockerfile | \
                    docker buildx build --platform linux/arm64 -t "$image" -f - "$src_dir")
            else
                echo "Already up to date"
            fi
        fi

        local container_name
        [ "$context" = "desktop-linux" ] && container_name="lazydocker" || container_name="lazydocker-$context"

        local docker_args=(
            --rm -it
            --name "$container_name"
            --label "com.centurylinklabs.watchtower.enable=false"
            -v "$HOME/code/config:/.config/jesseduffield/lazydocker"
            -v ~/.docker:/root/.docker:ro
            --tmpfs /tmp
        )

        if [ "$is_remote" = true ]; then
            docker_args+=(-v ~/.ssh:/root/.ssh:ro -e DOCKER_HOST="$docker_host")
        else
            local socket_path="${docker_host#unix://}"
            docker_args+=(-v "$socket_path:/var/run/docker.sock" -e DOCKER_HOST="unix:///var/run/docker.sock")
        fi

        docker run "${docker_args[@]}" "$image"
        echo "Closed lazydocker for: $context"
    }

    tweets() {
        ssh us2 "ls -lt /server/dumbtests/tweet_data/ | tail -n +2 | awk '{print \$6, \$7, \$8, \$9}' | sed 's/.json//'"
    }
    tweets-watch() {
        ssh -t us2 "watch -n 5 'ls -lt /server/dumbtests/tweet_data/ | tail -n +2 | awk \"{print \\\$6, \\\$7, \\\$8, \\\$9}\" | sed \"s/.json//\"'"
    }
fi

# ── Linux-specific ────────────────────────────────────────────────────────────

if [[ "$OS" == "Linux" ]]; then
    alias service='sudo service'
    alias watch="sudo watch -c -d -n 1"
    alias wservice="sudo watch -t -c -d -n 1 SYSTEMD_COLORS=1 service"

    [ -x /usr/bin/dircolors ] && eval "$(dircolors -b)"

    if ! shopt -oq posix; then
        [ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion \
        || [ -f /etc/bash_completion ] && . /etc/bash_completion
    fi

    [ -f "$HOME/.config/broot/launcher/bash/br" ] && source "$HOME/.config/broot/launcher/bash/br"

    command -v pipx &>/dev/null && alias nvitop="pipx run nvitop"
fi

# ── history ───────────────────────────────────────────────────────────────────

HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s checkwinsize

# ── prompt ────────────────────────────────────────────────────────────────────

INPUT_COLOR="\[\033[0m\]"
DIR_COLOR="\[\033[0;33m\]"
HOST_COLOR="\[\033[0;36m\]"
USER_NAME="\[\033[0;32m\]\u"
SYMBOL="\[\033[0;32m\]$"

if [[ ${EUID} == 0 ]]; then
    USER_NAME="\[\033[0;31m\]\u"
    SYMBOL="\[\033[0;31m\]#"
fi

if [[ "$OS" == "Darwin" ]]; then
    PS1="$USER_NAME $DIR_COLOR\w $SYMBOL $INPUT_COLOR"
else
    PS1="$USER_NAME $HOST_COLOR\h $DIR_COLOR:\w $SYMBOL $INPUT_COLOR"
fi

case "$TERM" in
xterm*|rxvt*) PS1="\[\e]0;\u@\h: \w\a\]$PS1" ;;
esac

# ── local overrides ───────────────────────────────────────────────────────────

[ -f ~/.bash_aliases ] && . ~/.bash_aliases
