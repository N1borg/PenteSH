#~/.exegol/my-resources/setup/zsh/zshrc.zsh - Shared Zsh profile for Exegol pentest containers

# === Environment Setup ===
ENV_NAME=".pentest_env"
ENV_PATH="$HOME"
ENV_LOG="$ENV_PATH/$ENV_NAME.log"

AUTO_LOAD_ENV=true
SHOW_SENSITIVE=false
AUTO_CHANGE_ATTACKER_IP=true

PENTEST_ENV_VARS=(INTERFACE ATTACKER_IP TARGET DOMAIN DOMAIN_SID DC_IP DC_HOST ADUSER PASSWORD NT_HASH)

autoload -Uz add-zsh-hook

# === Environment Identification ===
detect_environment() {
  if [[ -d "/.exegol" ]]; then
    PENTEST_ENVIRONMENT="exegol"
  elif [ -f /etc/os-release ] && grep -qi "^ID=kali" /etc/os-release; then
    PENTEST_ENVIRONMENT="kali"
  elif command -v lsb_release &>/dev/null && lsb_release -is 2>/dev/null | grep -qi "kali"; then
    PENTEST_ENVIRONMENT="kali"
  else
    PENTEST_ENVIRONMENT="unknown"
  fi
}
detect_environment

# === Log and save changed variables ===
log_changed_var() {
  local attacker_ip_old=""
  local attacker_ip_changed=false

  local var
  for var in "${PENTEST_ENV_VARS[@]}"; do
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

      echo "[$(date +'%Y-%m-%d %H:%M:%S')] $var changed from '${old_value}' to '${new_value}'" >> "$ENV_LOG"

      if [[ "$attacker_ip_changed" == true ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ATTACKER_IP changed from '${attacker_ip_old}' to '${ATTACKER_IP}'" >> "$ENV_LOG"
        attacker_ip_changed=false
      fi
    fi
  done
}

# Run check after every command prompt returns
add-zsh-hook precmd log_changed_var

# === Initialize environment with defaults ===
init_pentest_env() {
  TARGET= DOMAIN= DOMAIN_SID= DC_IP= DC_HOST= ADUSER= PASSWORD= NT_HASH=

  # Try to set the default interface
  INTERFACE="$(ip route | awk '/^default/ {print $5}' | head -n1)"

  if [[ -z "$INTERFACE" || ! $(ip link show "$INTERFACE" 2>/dev/null) ]]; then
    echo "⚠️  Warning: Could not detect a default network interface; falling back to \"lo\"" >&2
    INTERFACE="lo"  # fallback to loopback
  fi
  if [[ ! $(ip link show "$INTERFACE" 2>/dev/null) ]]; then
    INTERFACE=
  fi
}

# === Save pentest_env ===
save_pentest_env() {
  for var in "${PENTEST_ENV_VARS[@]}"; do
    echo "export $var='${(P)var}'"
  done > "$ENV_PATH/$ENV_NAME"
  echo "export AUTO_CHANGE_ATTACKER_IP='${AUTO_CHANGE_ATTACKER_IP}'" >> "$ENV_PATH/$ENV_NAME"
  echo "export SHOW_SENSITIVE='${SHOW_SENSITIVE}'" >> "$ENV_PATH/$ENV_NAME"

  echo "Pentest Environment saved in '${ENV_PATH}/${ENV_NAME}'"
}

# === Load pentest_env ===
load_pentest_env() {
  local env_file="$ENV_PATH/$ENV_NAME"

  if [[ -f "$env_file" ]]; then
    if ! source "$env_file"; then
      echo "❌ Failed to source the pentest environment from '$env_file'." >&2
      return 1
    fi
  else
    echo "⚠️  Pentest Environment file not found: '$env_file'" >&2
    return 1
  fi
}

# === Show current values ===
show_pentest_env() {
  local var
  for var in "${PENTEST_ENV_VARS[@]}"; do
    printf "%-12s : %s\n" "$var" "${(P)var}"
  done
  printf "%-12s : %s\n" "AUTO_CHANGE_ATTACKER_IP" "${AUTO_CHANGE_ATTACKER_IP}"
  printf "%-12s : %s\n" "SHOW_SENSITIVE" "${SHOW_SENSITIVE}"
}

# === Show pentest_env logs ===
show_pentest_env_logs() {
  [[ -f "$ENV_LOG" ]] && cat "$ENV_LOG"
}

# === Clean pentest_env logs ===
clean_pentest_env_logs() {
  cp "$ENV_LOG" "$ENV_LOG.bak.$(date +%s)" && : > "$ENV_LOG"
}

# === Prompt Enhancer ===
internal_pentest_prompt() {
  local parts=()

  if [[ "$PENTEST_ENVIRONMENT" == "kali" ]]; then
    [[ -n "${ADUSER}" ]] && parts+=(" %F{yellow}[${ADUSER}%f")
    if [[ -n "${ADUSER}" || -n "${DOMAIN}" ]]; then
      if [[ -n "${ADUSER}" && -z "${DOMAIN}" ]]; then
        parts+=("%F{yellow}@]%f")
      elif [[ -n "${DOMAIN}" && -z "${ADUSER}" ]]; then
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
  [[ $AUTO_LOAD_ENV == true ]] && load_pentest_env || init_pentest_env

  if [[ "$PENTEST_ENVIRONMENT" == "exegol" ]]; then
    # === Overwrite Exegol's shell prompt ===
    update_prompt() {
      if [[ -n "${USER}" ]]; then
        DB_PROMPT="%{$fg[white]%}[%{$fg[yellow]%}${USER}%{$fg[white]%}]%{$reset_color%}"
      elif [[ -n "${DOMAIN}" && -n "${USER}" ]]; then
        DB_PROMPT="%{$fg[white]%}[%{$fg[yellow]%}${USER}@${DOMAIN}%{$fg[white]%}]%{$reset_color%}"
      fi

      PROMPT="$LOGGING$DB_PROMPT$TIME_%{$FX[bold]$FG[013]%} $EXEGOL_HOSTNAME %{$fg_bold[blue]%}%(!.%1~.%c)$(internal_pentest_prompt)
%{$fg_bold[blue]%}$(prompt_char)%{$reset_color%} "
    }
    update_prompt
  elif [[ "$PENTEST_ENVIRONMENT" == "kali" ]]; then
    PROMPT=$'%F{%(#.blue.green)}┌──${debian_chroot:+($debian_chroot)─}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{%(#.red.blue)}%n'㉿$'%m%b%F{%(#.blue.green)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.green)}]$(internal_pentest_prompt)\n%F{%(#.blue.green)}└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
  fi
fi
