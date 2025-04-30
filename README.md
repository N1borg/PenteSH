# Exegol & Kali Zsh Pentest Environment Manager

This repository provides a shared Zsh configuration to seamlessly manage, persist, and auto-log key pentesting environment variables across Exegol and Kali Linux systems.

## 🎯 Purpose

- ✅ Detects and identifies whether you're running inside **Exegol** or **Kali Linux**.
- ✅ Automatically manages variables like `INTERFACE`, `ATTACKER_IP`, `TARGET`, `DOMAIN`, `DC_IP`, etc.
- ✅ Updates `ATTACKER_IP` dynamically if your interface changes.
- ✅ Logs every change to tracked variables in a persistent `.zshenv.log` file.
- ✅ Enhances your Zsh prompt with contextual information.
- ✅ Auto-saves the pentest session state on each command and on shell exit.

---

## 🧠 Tracked Variables

| Variable       | Description                         |
|----------------|-------------------------------------|
| `INTERFACE`    | Network interface used for attacks  |
| `ATTACKER_IP`  | Attacker's IP bound to `INTERFACE` |
| `TARGET`       | Target hostname or IP               |
| `DOMAIN`       | Target AD domain                    |
| `DOMAIN_SID`   | SID of the target domain            |
| `DC_IP`        | Domain controller IP                |
| `DC_HOST`      | Domain controller hostname          |
| `ADUSER`       | AD username                         |
| `PASSWORD`     | AD password                         |
| `NT_HASH`      | NTLM hash of the user               |

---

## 📁 File Structure

~/.exegol/my-resources/setup/zsh/zshrc.zsh


| File | Purpose |
|------|---------|
| `.zshenv` | Stores persistent environment variables |
| `.zshenv.log` | Logs all changes to tracked variables |

---

## 🔧 Features

- **Auto-detection** of environment (`IS_KALI`, `IS_EXEGOL`)
- **Smart prompt** that displays AD context, IPs, and more
- **Automatic IP updates** when network interface changes
- **Persistent session saving** on every prompt return (`precmd`)
- **Change tracking** for audit/debug use

---

## 🚀 Usage

1. **Clone or copy** the `zshrc.zsh` to:
   ```bash
   ~/.exegol/my-resources/setup/zsh/zshrc.zsh

2. Ensure your `.zshrc` sources this file:

```bash
source ~/.exegol/my-resources/setup/zsh/zshrc.zsh
```

Optional:

```bash
if [ -f "$HOME/.exegol/my-resources/setup/zsh/zshrc" ]; then
    source "$HOME/.exegol/my-resources/setup/zsh/zshrc"
    if [ -f "$HOME/.exegol/my-resources/setup/zsh/aliases" ]; then
        source "$HOME/.exegol/my-resources/setup/zsh/aliases"
    fi
fi
```

3. On first run, it will initialize default values for tracked variables.

## 📝 Logging Example

```
[2025-04-30 16:23:10] DOMAIN changed from '' to 'corp.local'
[2025-04-30 16:23:10] ATTACKER_IP changed from '192.168.1.10' to '192.168.1.201'
🔄 Auto-saved & logged: DOMAIN='corp.local'
🔄 Auto-saved & logged: ATTACKER_IP='192.168.1.201'
```

## 📦 Integrates Well With

- Exegol
- Kali Linux
- AD enumeration and exploitation workflows
- Tools like crackmapexec, rpcclient, impacket, and more

## 📌 Todo / Ideas

- Option for local AND global variable through terminals

