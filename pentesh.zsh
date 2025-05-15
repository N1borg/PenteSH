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
PENTESH_ENV_PATH="$HOME/.pentesh_env"
PENTESH_ENV_LOG_PATH="$PENTESH_ENV_PATH.log"

PENTESH_AUTO_LOAD_ENV=true
PENTESH_SHOW_SENSITIVE=false
PENTESH_AUTO_CHANGE_ATTACKER_IP=true

# Define structured metadata: VAR COLOR EMOJI SENSITIVE
PENTESH_ENV_VARS=(
  "AD_USER|||"
  "DOMAIN|||"
  "ATTACKER_IP|green|💻|false"
  "TARGET|cyan|🎯|false"
  "DC_IP|red|🏰|false"
  "DC_HOST|green|🏠|false"
  "AD_CS|yellow|📜|false"
  "PASSWORD|blue|🔑|true"
  "NT_HASH|blue|🔐|true"
  "INTERFACE|214||false"
  "DOMAIN_SID|magenta||false"
)

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
  local entry var

  for entry in "${PENTESH_ENV_VARS[@]}"; do
    IFS='|' read -r var _ <<< "$entry"

    local new_value="${(P)var}"
    local old_value="$(grep "${var}" "$PENTESH_ENV_LOG_PATH" 2>/dev/null | tail -n 1 | cut -d "'" -f 4)"

    if [[ "$new_value" != "$old_value" ]]; then

      if [[ "$var" == "INTERFACE" && -n "$INTERFACE" && "$PENTESH_AUTO_CHANGE_ATTACKER_IP" == true ]] && ip link show "$INTERFACE" &>/dev/null; then
        attacker_ip_old="$ATTACKER_IP"
        ATTACKER_IP="$(ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d'/' -f1 | head -n1)"

        if [[ "$ATTACKER_IP" != "$attacker_ip_old" ]]; then
          attacker_ip_changed=true
        else
          ATTACKER_IP="$attacker_ip_old"
        fi
      fi

      echo "[$(date +'%Y-%m-%d %H:%M:%S')] $var changed from '$(print -r -- "$old_value")' to '$(print -r -- "$new_value")'" >> "$PENTESH_ENV_LOG_PATH"

      if [[ "$attacker_ip_changed" == true ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ATTACKER_IP changed from '$(print -r -- "$attacker_ip_old")' to '$(print -r -- "$ATTACKER_IP")'" >> "$PENTESH_ENV_LOG_PATH"
        attacker_ip_changed=false
      fi
    fi
  done
}

# Run check after every command prompt returns
add-zsh-hook precmd log_changed_var

# === Show current values ===
show_pentesh_env() {
  printf "%-12s : %s\n" "PENTESH_ENV_PATH" "${PENTESH_ENV_PATH}"
  printf "%-12s : %s\n" "PENTESH_ENV_LOG_PATH" "${PENTESH_ENV_LOG_PATH}"
  printf "%-12s : %s\n" "PENTESH_AUTO_LOAD_ENV" "${PENTESH_AUTO_LOAD_ENV}"
  printf "%-12s : %s\n" "PENTESH_SHOW_SENSITIVE" "${PENTESH_SHOW_SENSITIVE}"
  printf "%-12s : %s\n" "PENTESH_AUTO_CHANGE_ATTACKER_IP" "${PENTESH_AUTO_CHANGE_ATTACKER_IP}"
  local entry var
  for entry in "${PENTESH_ENV_VARS[@]}"; do
    IFS='|' read -r var _ <<< "$entry"

    printf "%-12s : %s\n" "$var" "${(P)var}"
  done
}

# === Initialize environment with defaults ===
init_pentesh_env() {
  # Unset all variables defined in the metadata
  local entry var
  for entry in "${PENTESH_ENV_VARS[@]}"; do
    IFS='|' read -r var _ <<< "$entry"
    unset $var
  done

  # Try to set the default interface
  INTERFACE="$(ip route | awk '/^default/ {print $5}' | head -n1)"
  # Fallback to loopback interface if no default interface
  if [[ -z "$INTERFACE" || ! $(ip link show "$INTERFACE" 2>/dev/null) ]]; then
    echo "⚠️  Warning: Could not detect a default network interface; falling back to \"lo\"" >&2
    INTERFACE="lo"
  fi
  # Fallback to no interface if no loopback interface
  if [[ ! $(ip link show "$INTERFACE" 2>/dev/null) ]]; then
    INTERFACE=
  fi

  # Set ATTACKER_IP if PENTESH_AUTO_CHANGE_ATTACKER_IP is true
  if [[ -n "$INTERFACE" && "$PENTESH_AUTO_CHANGE_ATTACKER_IP" == true ]] && ip link show "$INTERFACE" &>/dev/null; then
    ATTACKER_IP="$(ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d'/' -f1 | head -n1)"
  fi
}

# === Save pentesh_env ===
save_pentesh_env() {
  local filename="${1:-$PENTESH_ENV_PATH}"
  # If the given filename is a directory, create ".pentesh_env" file
  if [[ -d "$filename" ]]; then
    filename="$filename/.pentesh_env"
  fi
  local entry var
  for entry in "${PENTESH_ENV_VARS[@]}"; do
    IFS='|' read -r var _ <<< "$entry"

    echo "export $var='${(P)var}'"
  done > "$filename"
  echo "export PENTESH_ENV_PATH='${PENTESH_ENV_PATH}'" >> "$filename"
  echo "export PENTESH_ENV_LOG_PATH='${PENTESH_ENV_LOG_PATH}'" >> "$filename"
  echo "export PENTESH_AUTO_LOAD_ENV='${PENTESH_AUTO_LOAD_ENV}'" >> "$filename"
  echo "export PENTESH_SHOW_SENSITIVE='${PENTESH_SHOW_SENSITIVE}'" >> "$filename"
  echo "export PENTESH_AUTO_CHANGE_ATTACKER_IP='${PENTESH_AUTO_CHANGE_ATTACKER_IP}'" >> "$filename"
  echo "PenteSH Environment saved in '${filename}'"
}

# === Delete pentesh_env ===
delete_pentesh_env() {
  local filename="${1:-$PENTESH_ENV_PATH}"
  if [[ -f "$filename" ]]; then
    rm -f "$filename" && echo "✅ PenteSH environment deleted: $filename"
  fi
}

# === Load pentesh_env ===
load_pentesh_env() {
  local filename="${1:-$PENTESH_ENV_PATH}"
  if [[ -f "$filename" ]]; then
    if ! source "$filename"; then
      echo "❌ Failed to source the PenteSH environment from '$filename'." >&2
      return 1
    fi
    echo "PenteSH Environment successfully loaded from '$filename'"
  else
    return 1
  fi
}

# === Show pentesh_env logs ===
show_pentesh_env_logs() {
  local filename="${1:-$PENTESH_ENV_LOG_PATH}"
  if [[ -f "$filename" ]]; then
    cat "$filename"
  fi
}

# === Clean pentesh_env logs ===
clean_pentesh_env_logs() {
  local filename="${1:-$PENTESH_ENV_LOG_PATH}"
  if [[ -f "$filename" ]]; then
    cp "$filename" "$filename.bak.$(date +%s)" && : > "$filename"
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

  # Display variables if set, emoji if set and values if emoji AND !$PENTESH_SHOW_SENSITIVE if $sensitive
  local entry var color emoji sensitive label value
  local -a fields
  for entry in "${PENTESH_ENV_VARS[@]}"; do
    IFS='|' read -r var color emoji sensitive <<< "$entry"

    value="${(P)var}"
    [[ -z "$value" ]] && continue
    [[ -z "$sensitive" ]] && continue

    if [[ -n "$emoji" ]]; then
      if [[ "$sensitive" == "true" && "$PENTESH_SHOW_SENSITIVE" != "true" ]]; then
        label="${emoji} ${var}"
      else
        label="${emoji} ${var}=${value}"
      fi
    else
      label="${var}"
    fi

    parts+=(" %F{$color}[${label}]%f")
  done

  if (( ${#parts[@]} )); then
    print -n "${(j::)parts} "
  fi
}

# === Custom Prompt Hook ===
if [[ -o interactive ]]; then
  [[ $PENTESH_AUTO_LOAD_ENV == true ]] && load_pentesh_env || init_pentesh_env

  if [[ "$PENTESH_ENVIRONMENT" == "exegol" ]]; then
    # === Overwrite Exegol's shell prompt ===
    update_prompt() {
      if [[ ! -z "${USER:-${AD_USER}}" || ! -z "${DOMAIN}" ]]; then
        DB_PROMPT="%{$fg[white]%}[%{$fg[yellow]%}${USER:-${AD_USER}}@${DOMAIN}%{$fg[white]%}]%{$reset_color%}"
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
