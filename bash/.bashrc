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
    export PATH="$PATH:$HOME/.darkbloom/bin"
elif command -v brew &>/dev/null; then
    eval "$(brew shellenv)"
fi

# ── mcfly (shell history) ─────────────────────────────────────────────────────

command -v mcfly &>/dev/null && eval "$(mcfly init bash)"

# ── NVM ───────────────────────────────────────────────────────────────────────

if [[ "$OS" == "Darwin" ]] then
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
fi

# ── Ansible ───────────────────────────────────────────────────────────────────

if [[ "$OS" == "Darwin" ]] then
export ANSIBLE_HOME="$HOME/.ansible"
alias ansible-lint='ANSIBLE_HOME=$HOME/.ansible ansible-lint'
fi

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
            # CONFIG_DIR: lazydocker в scratch-образе без HOME не видит XDG-пути,
            # поэтому монтируем в /config и указываем его явно (app_config.go:528)
            -v "$HOME/code/config/lazydocker:/config"
            -e CONFIG_DIR=/config
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

    # Патченый lazydocker (ветка selected-line-contrast в ~/code/lazydocker,
    # фикс контраста выбранной строки, jesseduffield/lazydocker#543).
    # Образ ленивый: не пересобирается сам. Пересборка после правок ветки:
    #   (cd ~/code/lazydocker && git checkout selected-line-contrast && \
    #    sed 's/FROM scratch/FROM alpine:3.20\nRUN apk add --no-cache openssh-client/' Dockerfile | \
    #    docker buildx build --platform linux/arm64 -t lazydocker-patched:latest -f - .)
    lzdp() {
        local context="${1:-desktop-linux}"
        if ! docker image inspect lazydocker-patched:latest &>/dev/null; then
            echo "Нет образа lazydocker-patched:latest — собери (рецепт в комментарии выше функции)" >&2
            return 1
        fi
        if ! docker context inspect "$context" >/dev/null 2>&1; then
            echo "Error: Docker context '$context' not found" >&2
            docker context ls >&2
            return 1
        fi
        local docker_host
        docker_host=$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}')
        echo "Starting lazydocker (patched) for: $context ($docker_host)"
        docker rm -f "lazydocker-patched-$context" 2>/dev/null || true
        local docker_args=(
            --rm -it
            --name "lazydocker-patched-$context"
            --label "com.centurylinklabs.watchtower.enable=false"
            -v "$HOME/code/config/lazydocker:/config"
            -e CONFIG_DIR=/config
            -v ~/.docker:/root/.docker:ro
            --tmpfs /tmp
        )
        if [[ "$docker_host" == ssh://* ]]; then
            docker_args+=(-v ~/.ssh:/root/.ssh:ro -e DOCKER_HOST="$docker_host")
        else
            docker_args+=(-v "${docker_host#unix://}:/var/run/docker.sock" -e DOCKER_HOST="unix:///var/run/docker.sock")
        fi
        docker run "${docker_args[@]}" lazydocker-patched:latest
    }

    # lazydocker с reverse-темой (инверсная выбранная строка) на отдельном конфиге —
    # общий ~/code/config/lazydocker не трогается. Образ тот же патченый:
    # reverse-guard рендерит его идентично оригиналу (легаси-путь).
    lzdr() {
        local context="${1:-desktop-linux}"
        local cfg_dir="$HOME/code/config/lazydocker-reverse"
        if [ ! -f "$cfg_dir/config.yml" ]; then
            mkdir -p "$cfg_dir"
            printf 'gui:\n  theme:\n    selectedLineBgColor:\n      - reverse\n' > "$cfg_dir/config.yml"
            echo "Создан $cfg_dir/config.yml (reverse-тема)"
        fi
        if ! docker image inspect lazydocker-patched:latest &>/dev/null; then
            echo "Нет образа lazydocker-patched:latest — собери (рецепт над lzdp)" >&2
            return 1
        fi
        if ! docker context inspect "$context" >/dev/null 2>&1; then
            echo "Error: Docker context '$context' not found" >&2
            docker context ls >&2
            return 1
        fi
        local docker_host
        docker_host=$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}')
        echo "Starting lazydocker (reverse) for: $context ($docker_host)"
        docker rm -f "lazydocker-reverse-$context" 2>/dev/null || true
        local docker_args=(
            --rm -it
            --name "lazydocker-reverse-$context"
            --label "com.centurylinklabs.watchtower.enable=false"
            -v "$cfg_dir:/config"
            -e CONFIG_DIR=/config
            -v ~/.docker:/root/.docker:ro
            --tmpfs /tmp
        )
        if [[ "$docker_host" == ssh://* ]]; then
            docker_args+=(-v ~/.ssh:/root/.ssh:ro -e DOCKER_HOST="$docker_host")
        else
            docker_args+=(-v "${docker_host#unix://}:/var/run/docker.sock" -e DOCKER_HOST="unix:///var/run/docker.sock")
        fi
        docker run "${docker_args[@]}" lazydocker-patched:latest
    }

    tweets() {
        ssh us2 "ls -lt /server/dumbtests/tweet_data/ | tail -n +2 | awk '{print \$6, \$7, \$8, \$9}' | sed 's/.json//'"
    }
    tweets-watch() {
        ssh -t us2 "watch -n 5 'ls -lt /server/dumbtests/tweet_data/ | tail -n +2 | awk \"{print \\\$6, \\\$7, \\\$8, \\\$9}\" | sed \"s/.json//\"'"
    }

    dbs() {
        # DARKBLOOM_NO_UPDATE_CHECK: без update-баннера status не пишет в stdout
        # через FileHandle и не падает SIGABRT'ом при обрыве пайпа (краш-диалоги
        # "quit unexpectedly" 2026-08-25, UpdateBanner.printBanner -> writeData:)
        DARKBLOOM_NO_UPDATE_CHECK=1 ~/.darkbloom/bin/darkbloom status | awk '
        function trim(s){gsub(/^ +| +$/,"",s);return s}
        /^Provider:/         {sub(/^Provider: */,""); p=$0}
        /^Daemon:/           {sub(/^Daemon: */,""); d=$0}
        /^Trust:/            {sub(/^Trust: */,""); t=$0; if((getline L)>0){n=trim(L); sub(/^→ */,"",n)}}
        /^Requests served:/  {split($0,Q,"|"); r=trim(Q[1]); sub(/^Requests served: */,"",r); k=trim(Q[2]); sub(/^tokens: */,"",k)}
        /^ +[^ ].*: kv=/     {if(c<3){L=$0; sub(/^ +/,"",L); split(L,A,": kv="); mods[++c]=A[1]"  (kv="A[2]")"}}
        END{
          print "● " p " · " t " · " d
          if(n!="") print "  " n
          if(c>0){print "Models:"; for(i=1;i<=c;i++) print "  " mods[i]} else print "Models: none loaded"
          print "Traffic: " r " req | " k " tokens"
        }'
    }
    dbsw() {
        local n="${1:-10}"
        while true; do
            clear
            dbs
            printf '\n\033[2m── refresh %ss · ^C to exit ──\033[0m\n' "$n"
            sleep "$n"
        done
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

# ── LM Studio proxy ──────────────────────────────────────────────────────────

alias lm-proxy='uvx --from "litellm[proxy]" litellm --config ~/.claude/litellm_config.yaml --port 4000'

# ── local overrides ───────────────────────────────────────────────────────────

[ -f ~/.bash_aliases ] && . ~/.bash_aliases

alias lz1c='cd "/Users/m/1c RAS" && ./lazy1c'
