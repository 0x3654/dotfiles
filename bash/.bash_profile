# ~/.bash_profile: sourced by bash for login shells.

[[ -r ~/.bashrc ]] && . ~/.bashrc

# Homebrew bash completion (macOS, requires bash 4.1+)
if [[ "$(uname -s)" == "Darwin" ]] && type brew &>/dev/null; then
    HOMEBREW_PREFIX="$(brew --prefix)"
    if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
        source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
    fi
fi

# ── macOS helpers ─────────────────────────────────────────────────────────────

if [[ "$(uname -s)" == "Darwin" ]]; then
    function p  { ping -a $1 | awk '{ gsub("time=",""); gsub("icmp_seq=",""); print $5 ": " $7 " " $8 }'; }
    function pi { ping -a $1 | awk '{ gsub("time=",""); gsub("icmp_seq=",""); print "ip " $4 " " $5 ": " $7 " " $8 }'; }

    function tp() {
        gping -n 1 -b 15 --clear \
            google.ru -c red \
            google.ge -c red \
            google.com -c light-red \
            es.0x3654.com -c magenta \
            ru2.0x3654.com -c magenta \
            ae.0x3654.com -c magenta \
            ae2.0x3654.com -c magenta \
            us2.0x3654.com -c magenta
    }

    function tpl() {
        gping -n 2 -b 15 --clear \
            10.0.1.10 -c green \
            10.0.1.51 -c red \
            10.0.1.56 -c magenta \
            192.168.192.1 -c yellow \
            micro -c red \
            nano -c red
    }
fi
