# PenteSH

**PenteSH** is a portable, Exegol- and Kali-compatible Zsh configuration that helps you manage and persist your pentesting environment seamlessly — all from your terminal.

Track critical context like `ATTACKER_IP`, `TARGET`, and `DOMAIN`, with automatic updates, persistent storage, and a smart prompt overlay.

## 🎯 Purpose

- ✅ Detects and identifies whether you're running inside **Exegol** or **Kali Linux**.
- ✅ Automatically manages variables like `INTERFACE`, `ATTACKER_IP`, `TARGET`, `DOMAIN`, `DC_IP`, etc.
- ✅ Updates `ATTACKER_IP` dynamically if your interface changes.
- ✅ Logs every change to tracked variables in a persistent `.zshenv.log` file.
- ✅ Enhances your Zsh prompt with contextual information.
- ✅ Auto-saves the pentest session state on each command and on shell exit.
- ✅ Loads and saves the environment automatically with fallbacks if needed.

---

## 🧠 Tracked Variables

| Variable       | Description                         |
|----------------|-------------------------------------|
| `INTERFACE`    | Network interface used for attacks  |
| `ATTACKER_IP`  | Attacker's IP bound to `INTERFACE`  |
| `TARGET`       | Target hostname or IP               |
| `DOMAIN`       | Target AD domain                    |
| `DOMAIN_SID`   | SID of the target domain            |
| `DC_IP`        | Domain controller IP                |
| `DC_HOST`      | Domain controller hostname          |
| `ADUSER`       | AD username                         |
| `PASSWORD`     | AD password                         |
| `NT_HASH`      | NTLM hash of the user               |

---

## 🔧 Features

- **Auto-detection** of environment (`kali`, `exegol`)
- **Smart prompt** that displays AD context, IPs, and more
- **Automatic IP updates** when network interface changes
- **Persistent session saving** on every prompt return (`precmd`)
- **Change tracking** for audit/debug use
- **Auto-load and auto-save environment** with fallbacks

---

## 🚀 Usage

### 1. **Direct Source Integration**

To seamlessly integrate this configuration with your system, source the `zshrc` directly into your default `.zshrc`.

First, clone or copy the configuration file to your desired path:

```bash
mkdir -p ~/.pentesh && cp ./zshrc.zsh ~/.pentesh/zshrc.zsh
```

**Bonus**: You can copy the configuration directly in the exegol 'my-resources' to use it **both in Exegol AND in Kali Linux** since Exegol automatically sources this file:

```bash
cp ./zshrc.zsh ~/.exegol/my-resources/setup/zsh/zshrc
```

### 2. Ensure your `.zshrc` sources this file:

- Kali only:

```bash
echo 'source "~/.pentesh/zshrc.zsh"' >> ~/.zshrc
```

- Exegol:

```bash
echo 'source "~/.exegol/my-resources/setup/zsh/zshrc"' >> ~/.zshrc
```

**Optional** - source the aliases for shorter commands:

```bash
cp ./aliases.zsh ~/.exegol/my-resources/setup/zsh/aliases && echo 'source "$HOME/.exegol/my-resources/setup/zsh/aliases"' >> ~/.zshrc
```

### 3. On the first run, the script will initialize default values for the tracked variables, such as `ATTACKER_IP`, `TARGET`, etc.

## 🧰 Configuration

You can customize the behavior of the environment manager by adjusting the following settings in the `zshrc.zsh` file:

### 1. Boolean Variables

- `AUTO_LOAD_ENV`
    - **Type**: Boolean (`true` / `false`)
    - **Default**: `true`
    - **Description**: When set to `true`, the script will attempt to load the pentesting environment automatically from the specified file (`$ENV_PATH/$ENV_NAME`) during shell startup. If the file doesn't exist, it initializes a new default environment.
- `SHOW_SENSITIVE`
    - **Type**: Boolean (`true` / `false`)
    - **Default**: `false`
    - **Description**: Controls whether sensitive values like `PASSWORD` and `NT_HASH` are displayed in the prompt. If set to `false`, sensitive values are not displayed.
- `AUTO_CHANGE_ATTACKER_IP`
    - **Type**: Boolean (`true` / `false`)
    - **Default**: `false`
    - **Description**: If enabled, the `ATTACKER_IP` will be automatically updated whenever the `INTERFACE` value is changed (e.g., on VPN toggle or network switch). Otherwise, it remains static unless changed manually

### 2. Environment Path Setup

- `ENV_NAME`
    - **Type**: String (Directory Path)
    - **Default**: `.pentest_env`
    - **Description**: The name of your pentesting environment file.
- `ENV_PATH`
    - **Type**: String (Directory Path)
    - **Default**: `$HOME`
    - **Description**: The directory where your pentesting environment and log files are stored.
- `ENV_LOG`
    - **Type**: String (Directory Path)
    - **Default**: `$ENV_PATH/$ENV_NAME.log`
    - **Description**: The path of your pentesting environment log file.

## 📝 Logging Example

```log
[2025-04-30 16:23:10] DOMAIN changed from '' to 'corp.local'
[2025-05-02 07:51:11] INTERFACE changed from 'docker0' to 'eth0'
[2025-05-02 07:51:11] ATTACKER_IP changed from '172.17.0.1' to '192.168.1.129'
```

## 🛠️ Pentest Environment Example

```bash
export INTERFACE='eth0'
export ATTACKER_IP='192.168.56.101'
export TARGET='192.168.56.110'
export DOMAIN='corp.local'
export DOMAIN_SID='S-1-5-21-123456789-987654321-1112131415'
export DC_IP='192.168.56.10'
export DC_HOST='dc01.corp.local'
export ADUSER='administrator'
export PASSWORD='P@ssw0rd!'
export NT_HASH=''
export AUTO_CHANGE_ATTACKER_IP='true'
export SHOW_SENSITIVE='true'
export AUTO_LOAD_ENV='true'
```
