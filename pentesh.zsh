#  ███████████                       █████              █████████  █████   █████
# ░░███░░░░░███                     ░░███              ███░░░░░███░░███   ░░███ 
#  ░███    ░███  ██████  ████████   ███████    ██████ ░███    ░░░  ░███    ░███ 
#  ░██████████  ███░░███░░███░░███ ░░░███░    ███░░███░░█████████  ░███████████ 
#  ░███░░░░░░  ░███████  ░███ ░███   ░███    ░███████  ░░░░░░░░███ ░███░░░░░███ 
#  ░███        ░███░░░   ░███ ░███   ░███ ███░███░░░   ███    ░███ ░███    ░███ 
#  █████       ░░██████  ████ █████  ░░█████ ░░██████ ░░█████████  █████   █████
# ░░░░░         ░░░░░░  ░░░░ ░░░░░    ░░░░░   ░░░░░░   ░░░░░░░░░  ░░░░░   ░░░░░ 


# """""""""""""""""""""" Hacking Differently. - Niborg """""""""""""""""""""" #

# === Environment Setup ===
ENV_NAME=".pentesh_env"
ENV_PATH="$HOME"
ENV_LOG="$ENV_PATH/$ENV_NAME.log"

AUTO_LOAD_ENV=true
SHOW_SENSITIVE=false
AUTO_CHANGE_ATTACKER_IP=true

PENTESH_ENV_VARS=(INTERFACE ATTACKER_IP TARGET DOMAIN DOMAIN_SID DC_IP DC_HOST AD_CS AD_USER PASSWORD NT_HASH)

autoload -Uz add-zsh-hook

# === Environment Identification ===
detect_environment() {
  if [[ -d "/.exegol" ]]; then
    PENTESH_ENVIRONMENT="exegol"
  elif [ -f /etc/os-release ] && grep -qiE "ID=kali|PRETTY_NAME=.*Kali" /etc/os-release; then
    PENTESH_ENVIRONMENT="kali"
  elif command -v lsb_release &>/dev/null && lsb_release -is 2>/dev/null | grep -qi "kali"; then
    PENTESH_ENVIRONMENT="kali"
  else
    PENTESH_ENVIRONMENT="unknown"
  fi
}
detect_environment

# === Log and save changed variables ===
log_changed_var() {
  local attacker_ip_old=""
  local attacker_ip_changed=false

  local var
  for var in "${PENTESH_ENV_VARS[@]}"; do
    local new_value="${(P)var}"
    local old_value="$(grep "${var}" "$ENV_LOG" 2>/dev/null | tail -n 1 | cut -d "'" -f 4)"

    if [[ "$new_value" != "$old_value" ]]; then

      if [[ "$var" == "INTERFACE" && -n "$INTERFACE" && "$AUTO_CHANGE_ATTACKER_IP" == true ]] && ip link show "$INTERFACE" &>/dev/null; then
        attacker_ip_old="$ATTACKER_IP"
        ATTACKER_IP="$(ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d'/' -f1 | head -n1)"

        if [[ "$ATTACKER_IP" != "$attacker_ip_old" ]]; then
          attacker_ip_changed=true
        else
          ATTACKER_IP="$attacker_ip_old"
        fi
      fi

      echo "[$(date +'%Y-%m-%d %H:%M:%S')] $var changed from '$(print -r -- "$old_value")' to '$(print -r -- "$new_value")'" >> "$ENV_LOG"

      if [[ "$attacker_ip_changed" == true ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ATTACKER_IP changed from '$(print -r -- "$attacker_ip_old")' to '$(print -r -- "$ATTACKER_IP")'" >> "$ENV_LOG"
        attacker_ip_changed=false
      fi
    fi
  done
}

# Run check after every command prompt returns
add-zsh-hook precmd log_changed_var

# === Show current values ===
show_pentesh_env() {
  local var
  for var in "${PENTESH_ENV_VARS[@]}"; do
    printf "%-12s : %s\n" "$var" "${(P)var}"
  done
  printf "%-12s : %s\n" "AUTO_CHANGE_ATTACKER_IP" "${AUTO_CHANGE_ATTACKER_IP}"
  printf "%-12s : %s\n" "SHOW_SENSITIVE" "${SHOW_SENSITIVE}"
}

# === Initialize environment with defaults ===
init_pentesh_env() {
  TARGET= DOMAIN= DOMAIN_SID= DC_IP= DC_HOST= AD_CS= AD_USER= PASSWORD= NT_HASH=

  # Try to set the default interface
  INTERFACE="$(ip route | awk '/^default/ {print $5}' | head -n1)"

  if [[ -z "$INTERFACE" || ! $(ip link show "$INTERFACE" 2>/dev/null) ]]; then
    echo "⚠️  Warning: Could not detect a default network interface; falling back to \"lo\"" >&2
    INTERFACE="lo"  # fallback to loopback
  fi
  if [[ ! $(ip link show "$INTERFACE" 2>/dev/null) ]]; then
    INTERFACE=
  fi
  if [[ -n "$INTERFACE" && "$AUTO_CHANGE_ATTACKER_IP" == true ]] && ip link show "$INTERFACE" &>/dev/null; then
    ATTACKER_IP="$(ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d'/' -f1 | head -n1)"
  fi
}

# === Save pentesh_env ===
save_pentesh_env() {
  local default_path="$ENV_PATH/$ENV_NAME"
  local filename="${1:-$default_path}"

  # If the given filename is a directory, append $ENV_NAME
  if [[ -d "$filename" ]]; then
    filename="$filename/$ENV_NAME"
  fi

  for var in "${PENTESH_ENV_VARS[@]}"; do
    print -r -- "export $var='${(P)var}'"
  done > "$filename"
  print -r -- "export AUTO_CHANGE_ATTACKER_IP='${AUTO_CHANGE_ATTACKER_IP}'" >> "$filename"
  print -r -- "export SHOW_SENSITIVE='${SHOW_SENSITIVE}'" >> "$filename"

  echo "PenteSH Environment saved in '${filename}'"
}

# === Delete pentesh_env ===
delete_pentesh_env() {
  local env_file="$ENV_PATH/$ENV_NAME"

  if [[ -f "$env_file" ]]; then
    rm -f "$env_file" && echo "✅ PenteSH environment deleted: $env_file"
  fi
}

# === Load pentesh_env ===
load_pentesh_env() {
  local env_file="$ENV_PATH/$ENV_NAME"

  if [[ -f "$env_file" ]]; then
    if ! source "$env_file"; then
      echo "❌ Failed to source the PenteSH environment from '$env_file'." >&2
      return 1
    fi
    echo "PenteSH Environment successfully loaded from '$env_file'"
  else
    return 1
  fi
}

# === Show pentesh_env logs ===
show_pentesh_env_logs() {
  if [[ -f "$ENV_LOG" ]]; then
    cat "$ENV_LOG"
  fi
}

# === Clean pentesh_env logs ===
clean_pentesh_env_logs() {
  if [[ -f "$ENV_LOG" ]]; then
    cp "$ENV_LOG" "$ENV_LOG.bak.$(date +%s)" && : > "$ENV_LOG"
  fi
}

# === Help Function ===
show_pentesh_help() {
  echo "\
Usage: penv-<command>
  penv              Show current environment
  penv-reset        Reset all environment variables
  penv-save         Save current environment to file
  penv-del          Delete saved environment
  penv-load         Load environment from file
  penv-log          Show environment change log
  penv-log-clean    Clean environment change log
  penv-help         Show this help message"
}

# === Prompt Enhancer ===
internal_pentesh_prompt() {
  local parts=()

  if [[ "$PENTESH_ENVIRONMENT" == "kali" ]]; then
    [[ -n "${AD_USER}" ]] && parts+=(" %F{yellow}[${AD_USER}%f")
    if [[ -n "${AD_USER}" || -n "${DOMAIN}" ]]; then
      if [[ -n "${AD_USER}" && -z "${DOMAIN}" ]]; then
        parts+=("%F{yellow}@]%f")
      elif [[ -n "${DOMAIN}" && -z "${AD_USER}" ]]; then
        parts+=(" %F{yellow}[@%f")
      else
        parts+=("%F{yellow}@%f")
      fi
    fi
    [[ -n "${DOMAIN}" ]]     && parts+=("%F{yellow}${DOMAIN}]%f")
  fi
  [[ -n "${ATTACKER_IP}" ]]  && parts+=(" %F{green}[💻 ATTACKER_IP=${ATTACKER_IP}]%f")
  [[ -n "${TARGET}" ]]       && parts+=(" %F{cyan}[🎯 TARGET=${TARGET}]%f")
  [[ -n "${DC_IP}" ]]        && parts+=(" %F{red}[🏰 DC_IP=${DC_IP}]%f")
  [[ -n "${DC_HOST}" ]]      && parts+=(" %F{green}[🏠 DC_HOST=${DC_HOST}]%f")
  [[ -n "${AD_CS}" ]]        && parts+=(" %F{yellow}[📜 AD_CS=${AD_CS}]%f")
  if [[ -n "${PASSWORD}" ]]; then
    if [[ "$SHOW_SENSITIVE" == true ]]; then
      parts+=(" %F{blue}[🔑 PASSWORD=${PASSWORD}]%f")
    else
      parts+=(" %F{blue}[PASSWORD]%f")
    fi
  fi

  if [[ -n "${NT_HASH}" ]]; then
    if [[ "$SHOW_SENSITIVE" == true ]]; then
      parts+=(" %F{blue}[🔐 NT_HASH=${NT_HASH}]%f")
    else
      parts+=(" %F{blue}[NT_HASH]%f")
    fi
  fi

  [[ -n "${INTERFACE}" ]]    && parts+=(" %F{214}[INTERFACE]%f")
  [[ -n "${DOMAIN_SID}" ]]   && parts+=(" %F{magenta}[DOMAIN_SID]%f")

  if (( ${#parts[@]} )); then
    print -n "${(j::)parts} "
  fi
}

# === Custom Prompt Hook ===
if [[ -o interactive ]]; then
  [[ $AUTO_LOAD_ENV == true ]] && load_pentesh_env || init_pentesh_env

  if [[ "$PENTESH_ENVIRONMENT" == "exegol" ]]; then
    # === Overwrite Exegol's shell prompt ===
    update_prompt() {
      if [[ ! -z "${USER}" || ! -z "${DOMAIN}" ]]; then
        DB_PROMPT="%{$fg[white]%}[%{$fg[yellow]%}${USER}@${DOMAIN}%{$fg[white]%}]%{$reset_color%}"
      fi

      PROMPT="$LOGGING$DB_PROMPT$TIME_%{$FX[bold]$FG[013]%} $EXEGOL_HOSTNAME %{$fg_bold[blue]%}%(!.%1~.%c)$(internal_pentesh_prompt)
%{$fg_bold[blue]%}$(prompt_char)%{$reset_color%} "
    }
    update_prompt
  elif [[ "$PENTESH_ENVIRONMENT" == "kali" ]]; then
    PROMPT=$'%F{%(#.blue.green)}┌──${debian_chroot:+($debian_chroot)─}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{%(#.red.blue)}%n'㉿$'%m%b%F{%(#.blue.green)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.green)}]$(internal_pentesh_prompt)\n%F{%(#.blue.green)}└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
  fi
fi

# === Aliases functions ===
alias penv="show_pentesh_env"
alias penv-reset="init_pentesh_env"
alias penv-save="save_pentesh_env"
alias penv-del="delete_pentesh_env"
alias penv-load="load_pentesh_env"
alias penv-log="show_pentesh_env_logs"
alias penv-log-clean="clean_pentesh_env_logs"
alias penv-help="show_pentesh_help"

# === Completion ===
_pentesh_completions() {
  compadd penv penv-reset penv-save penv-del penv-load penv-log penv-log-clean penv-help
}
compdef _pentesh_completions penv penv-reset penv-save penv-del penv-load penv-log penv-log-clean penv-help
