# Einetic WP Fleet

**Einetic WP Fleet** is a lightweight CLI tool for managing multiple WordPress installations on a server.

It is designed for environments such as:

* Hostinger shared hosting
* VPS servers
* CloudPanel based servers
* Generic LEMP/LAMP setups

The tool discovers WordPress installations and allows quick operations like fixing WordPress core, reinstalling plugins/themes, backups, and administrative utilities using **wp-cli**.

---

# Core Philosophy

Einetic WP Fleet is built with three principles:

* **Simple bash utilities**
* **Platform-agnostic WordPress operations**
* **Automation-ready architecture**

Each operation is implemented as a standalone script so it can be used:

* from the CLI agent
* via SSH
* in automation scripts
* by future APIs

---

# Project Structure

```
agent/
    agent.sh
    config.sample.env

core/
    detect-platform.sh
    env.sh
    logger.sh

util/
    find-sites.sh
    list-sites.sh
    get-site-path.sh
    backup-site.sh
    fix-site.sh
    login-link.sh
    reinstall-core.sh
    reinstall-plugins.sh
    reinstall-themes.sh
    update-wordpress.sh
    wp-cli.sh

scripts/
    install.sh
    update.sh

service/
    einetic-wp-fleet.service

logs/
tmp/
```

---

# Requirements

Server requirements:

* Linux server
* Bash
* wp-cli installed
* WordPress sites available on the server

Typical WordPress paths supported:

Hostinger:

```
/home/<user>/domains/<domain>/public_html
```

CloudPanel:

```
/home/<user>/htdocs/<domain>
```

---

# Installation

Install the tool using:

```
curl -s https://raw.githubusercontent.com/Einetic/wordpress.einetic.com/master/scripts/install.sh | bash
```

This will:

1. Clone the repository
2. Create working directories
3. Prepare the tool environment

Default install location:

```
~/einetic-wp-fleet
```

or on root servers:

```
/opt/einetic-wp-fleet
```

---

# Running the Tool

Go to the installation directory:

```
cd ~/einetic-wp-fleet
```

Before running for the first time you may need to ensure:

### 1️⃣ Shell scripts use LF line endings

If you developed on Windows run:

```
sed -i 's/\r$//' agent/*.sh
sed -i 's/\r$//' util/*.sh
sed -i 's/\r$//' scripts/*.sh
```

### 2️⃣ Make scripts executable

```
chmod +x agent/*.sh
chmod +x util/*.sh
chmod +x scripts/*.sh
```

### 3️⃣ Run the agent

```
./agent/agent.sh
```

The tool will:

1. discover WordPress sites
2. display a numbered list
3. allow selecting a site
4. execute management utilities

---

# Updating the Tool

To update the installed version:

```
bash scripts/update.sh
```

or manually:

```
git pull
```

---

# Development Notes (Windows)

If developing on Windows:

Create `.gitattributes` to enforce Linux line endings:

```
*.sh text eol=lf
```

This prevents CRLF issues when running scripts on Linux servers.

---

# Utility Script Design Rules

Every utility script should:

* work independently
* accept a WordPress path
* produce clear output
* rely on wp-cli where possible

Example usage:

```
bash util/update-wordpress.sh /path/to/site
```

---

# Future Roadmap

### Phase 1

* WordPress repair utilities
* improved site discovery
* platform detection

### Phase 2

* background fleet agent
* remote command execution
* centralized management

### Phase 3

* malware monitoring
* vulnerability scanning
* automatic repair

---

# Security Notes

Never commit:

```
.env files
API keys
server credentials
backup archives
```

---

# License

License to be decided (MIT recommended).

--- 