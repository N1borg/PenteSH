#~/.exegol/my-resources/setup/zsh/zshrc.zsh - Shared Zsh profile for Exegol pentest containers

# === Environment Path ===
ENV_PATH="$HOME/.zshenv"
ENV_LOG="$HOME/.zshenv.log"

# === Environment Identification ===
export IS_EXEGOL=false
export IS_KALI=false

# Check if in Exegol or Kali environment
if [[ -d "/.exegol" ]]; then
  export IS_EXEGOL=true
elif [ -f /etc/os-release ] && grep -qi "^ID=kali" /etc/os-release; then
  export IS_KALI=true
elif command -v lsb_release &>/dev/null && lsb_release -is 2>/dev/null | grep -qi "kali"; then
  export IS_KALI=true
fi

autoload -Uz add-zsh-hook

# === Save environment ===
save_pentest_env() {
  for var1 in INTERFACE ATTACKER_IP TARGET DOMAIN DOMAIN_SID DC_IP DC_HOST ADUSER PASSWORD NT_HASH; do
    local value="${(P)var1}"
    local entry="export ${var1}=\"${value}\""

    if grep -q "^export ${var1}=" "$ENV_PATH" 2>/dev/null; then
      sed -i "s|^export ${var1}=.*|$entry|" "$ENV_PATH"
    elif grep -q "^${var1}=" "$ENV_PATH" 2>/dev/null; then
      sed -i "s|^${var1}=.*|$entry|" "$ENV_PATH"
    else
      echo "$entry" >> "$ENV_PATH"
    fi
  done
}

# Log and save if tracked variable has changed
log_and_save_if_tracked_var_changed() {
  local attacker_ip_old=""
  local attacker_ip_changed=false

  for var2 in INTERFACE ATTACKER_IP TARGET DOMAIN DOMAIN_SID DC_IP DC_HOST ADUSER PASSWORD NT_HASH; do
    local new_value="${(P)var2}"
    local old_value="$(grep "${var2}=" "$ENV_PATH" 2>/dev/null | cut -d= -f2- | tr -d '"')"

    if [[ "$new_value" != "$old_value" ]]; then

      if [[ "$var2" == "INTERFACE" && -n "$INTERFACE" ]] && ip link show "$INTERFACE" &>/dev/null; then
        attacker_ip_old="$ATTACKER_IP"
        ATTACKER_IP="$(ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d'/' -f1 | head -n1)"

        if [[ "$ATTACKER_IP" != "$attacker_ip_old" ]]; then
          attacker_ip_changed=true
        else
          ATTACKER_IP="$attacker_ip_old"
        fi
      fi

      save_pentest_env
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] $var2 changed from '${old_value}' to '${new_value}'" >> "$ENV_LOG"
      echo "🔄 Auto-saved & logged: $var2='$new_value'"

      if [[ "$attacker_ip_changed" == true ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ATTACKER_IP changed from '${attacker_ip_old}' to '${ATTACKER_IP}'" >> "$ENV_LOG"
        echo "🔄 Auto-saved & logged: ATTACKER_IP='$ATTACKER_IP'"
        attacker_ip_changed=false
      fi
    fi
  done
}

# Run check after every command prompt returns
add-zsh-hook precmd log_and_save_if_tracked_var_changed

# === Initialize environment with defaults ===
init_pentest_env() {
  TARGET= DOMAIN= DOMAIN_SID= DC_IP= DC_HOST= ADUSER= PASSWORD= NT_HASH=

  # Try to set the default interface
  INTERFACE="$(ip route | awk '/^default/ {print $5}' | head -n1)"

  if [[ -z "$INTERFACE" || ! $(ip link show "$INTERFACE" 2>/dev/null) ]]; then
    echo "⚠️  Warning: Could not detect a default network interface; falling back to \"lo\"" >&2
    INTERFACE="lo"  # fallback to loopback to avoid breaking dependent logic
  fi

  # Set the IP of the interface
  if [[ -n "$INTERFACE" ]] && ip link show "$INTERFACE" &>/dev/null; then
    ATTACKER_IP="$(ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d'/' -f1 | head -n1)"
  else
    ATTACKER_IP=""
  fi

  save_pentest_env
}

# === Show current values ===
show_pentest_env() {
  for var3 in INTERFACE ATTACKER_IP TARGET DOMAIN DOMAIN_SID DC_IP DC_HOST ADUSER PASSWORD NT_HASH; do
    printf "%-12s : %s\n" "$var3" "${(P)var3}"
  done
}

# === Show pentest_env logs ===
show_pentest_env_logs() {
  [[ -f "$ENV_LOG" ]] && cat "$ENV_LOG"
}

# === Clean pentest_env logs ===
clean_pentest_env_logs() {
  echo "" > "$ENV_LOG"
}

# === Prompt Enhancer ===
internal_pentest_prompt() {
  local parts=()

  if [[ "$IS_KALI" == true ]]; then
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
  # Init the env
  [[ -f "$ENV_PATH" ]] || init_pentest_env

  if [[ "$IS_EXEGOL" == true ]]; then
    # === Overwrite Exegol's shell prompt ===
    update_prompt() {
      DB_PROMPT=""

      if [[ ! -z "${USER}" ]]; then
        DB_PROMPT="%{$fg[white]%}[%{$fg[yellow]%}${USER}%{$fg[white]%}]%{$reset_color%}"
      fi

      if [[ ! -z "${DOMAIN}" && ! -z "${USER}" ]]; then
        DB_PROMPT="%{$fg[white]%}[%{$fg[yellow]%}${USER}@${DOMAIN}%{$fg[white]%}]%{$reset_color%}"
      fi

      PROMPT="$LOGGING$DB_PROMPT$TIME_%{$FX[bold]$FG[013]%} $EXEGOL_HOSTNAME %{$fg_bold[blue]%}%(!.%1~.%c)$(internal_pentest_prompt)
%{$fg_bold[blue]%}$(prompt_char)%{$reset_color%} "
    }
    update_prompt
  elif [[ "$IS_KALI" == true ]]; then
    PROMPT=$'%F{%(#.blue.green)}┌──${debian_chroot:+($debian_chroot)─}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{%(#.red.blue)}%n'㉿$'%m%b%F{%(#.blue.green)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.green)}]$(internal_pentest_prompt)\n%F{%(#.blue.green)}└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
  fi
fi

# === Save on exit ===
add-zsh-hook zshexit save_pentest_env
