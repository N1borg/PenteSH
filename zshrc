#~/.exegol/my-resources/setup/zsh/zshrc.zsh - Shared Zsh profile for Exegol pentest containers

# === Environment Log Path ===
ENV_NAME=".pentest_env"
ENV_PATH="$HOME"
ENV_LOG="$ENV_PATH/$ENV_NAME.log"

# === Environment Identification ===
is_exegol=false
is_kali=false

# Check if in Exegol or Kali environment
if [[ -d "/.exegol" ]]; then
  is_exegol=true
elif [ -f /etc/os-release ] && grep -qi "^ID=kali" /etc/os-release; then
  is_kali=true
elif command -v lsb_release &>/dev/null && lsb_release -is 2>/dev/null | grep -qi "kali"; then
  is_kali=true
fi

autoload -Uz add-zsh-hook

# === Log and save changed variables ===
log_changed_var() {
  local attacker_ip_old=""
  local attacker_ip_changed=false

  local var
  for var in INTERFACE ATTACKER_IP TARGET DOMAIN DOMAIN_SID DC_IP DC_HOST ADUSER PASSWORD NT_HASH; do
    local new_value="${(P)var}"
    local old_value="$(grep "${var}" "$ENV_LOG" 2>/dev/null | tail -n 1 | cut -d "'" -f 4)"

    if [[ "$new_value" != "$old_value" ]]; then

      if [[ "$var" == "INTERFACE" && -n "$INTERFACE" ]] && ip link show "$INTERFACE" &>/dev/null; then
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

# === Show current values ===
show_pentest_env() {
  local var
  for var in INTERFACE ATTACKER_IP TARGET DOMAIN DOMAIN_SID DC_IP DC_HOST ADUSER PASSWORD NT_HASH; do
    printf "%-12s : %s\n" "$var" "${(P)var}"
  done
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

  if [[ "$is_kali" == true ]]; then
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
  [[ -n "${INTERFACE}" ]]    && parts+=(" %F{214}[INTERFACE]%f")
  [[ -n "${DOMAIN_SID}" ]]   && parts+=(" %F{magenta}[DOMAIN_SID]%f")
  [[ -n "${PASSWORD}" ]]     && parts+=(" %F{cyan}[PASSWORD]%f")
  [[ -n "${NT_HASH}" ]]      && parts+=(" %F{blue}[NT_HASH]%f")

  if (( ${#parts[@]} )); then
    print -n "${(j::)parts} "
  fi
}

# === Custom Prompt Hook ===
if [[ -o interactive ]]; then
  init_pentest_env

  if [[ "$is_exegol" == true ]]; then
    # === Overwrite Exegol's shell prompt ===
    update_prompt() {
      DB_PROMPT=""

      if [[ -n "${USER}" ]]; then
        DB_PROMPT="%{$fg[white]%}[%{$fg[yellow]%}${USER}%{$fg[white]%}]%{$reset_color%}"
      fi

      if [[ -n "${DOMAIN}" && -n "${USER}" ]]; then
        DB_PROMPT="%{$fg[white]%}[%{$fg[yellow]%}${USER}@${DOMAIN}%{$fg[white]%}]%{$reset_color%}"
      fi

      PROMPT="$LOGGING$DB_PROMPT$TIME_%{$FX[bold]$FG[013]%} $EXEGOL_HOSTNAME %{$fg_bold[blue]%}%(!.%1~.%c)$(internal_pentest_prompt)
%{$fg_bold[blue]%}$(prompt_char)%{$reset_color%} "
    }
    update_prompt
  elif [[ "$is_kali" == true ]]; then
    PROMPT=$'%F{%(#.blue.green)}┌──${debian_chroot:+($debian_chroot)─}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{%(#.red.blue)}%n'㉿$'%m%b%F{%(#.blue.green)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.green)}]$(internal_pentest_prompt)\n%F{%(#.blue.green)}└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
  fi
fi
