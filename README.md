# Einetic WP Fleet

Einetic WP Fleet is a lightweight server agent for managing multiple WordPress sites across VPS environments (Ubuntu, CloudPanel, generic LEMP/LAMP).

It provides centralized operations like:

* site discovery
* fixing WordPress core
* backup & restore
* auto-login link generation
* site create/delete/rename
* automation via API + background service

This project is designed for infrastructure automation and fleet-scale WordPress operations.

---

## 🧭 Architecture Overview

Each VPS runs a background agent:

```
einetic-wp-fleet.service
```

The agent:

* starts at boot
* restarts automatically if stopped
* exposes internal API
* executes site operations using wp-cli + Linux commands

All operations are handled via modular utility scripts.

---

## 📁 Project Structure

```
agent/
   install.sh
   agent.sh
   config.env

util/
   fleet-list-sites.sh
   fleet-fix-site.sh
   fleet-backup-site.sh
   fleet-login-link.sh
   fleet-create-site.sh
   fleet-delete-site.sh
   fleet-rename-site.sh
   fleet-restore-site.sh

service/
   einetic-wp-fleet.service

logs/
tmp/
```

---

## ⚙️ Requirements

* Ubuntu 22/24 LTS
* Root access
* Internet access
* WordPress sites (CloudPanel or generic)
* wp-cli (auto-installed if missing)

---

## 🚀 Installation

Run on a fresh VPS:

```
curl -s https://raw.githubusercontent.com/Einetic/wordpress.einetic.com/main/agent/install.sh | bash
```

This will:

1. Install dependencies
2. Install wp-cli
3. Clone Einetic WP Fleet
4. Configure system service
5. Enable auto start
6. Start agent

---

## 🧪 Verify Installation

Check service status:

```
systemctl status einetic-wp-fleet
```

Check logs:

```
journalctl -u einetic-wp-fleet -f
```

---

## 🔐 Configuration

Config file:

```
/opt/einetic-wp-fleet/agent/config.env
```

Example:

```
SERVER_API_KEY=change-this
PORT=8081
NODE_NAME=my-vps-01
```

Never commit this file to repository.

---

## 🧠 Supported Operations (planned)

* List all WordPress sites
* Fix corrupted WordPress
* Backup site
* Restore site
* Create site
* Delete site
* Rename site
* Generate auto-login link
* Plugin/theme install
* Security scan

---

## 🧩 Utility Design Rule

Every util script:

* works standalone
* accepts domain/path
* outputs structured result
* no dependency on agent
* reusable via SSH or API

---

## 📡 Agent Execution Model

Agent runs as system service:

```
systemd → agent → util scripts → wp-cli/linux
```

Future model includes:

* central fleet control
* task orchestration
* malware monitoring
* update automation

---

## 🛡️ Security Notes

Do NOT commit:

* config.env
* API keys
* credentials
* backup paths
* server IP mappings

Agent must:

* validate input
* require API key
* avoid arbitrary shell execution

---

## 📦 WordPress Bundles

WordPress core, plugins, themes, and backups are NOT stored in this repo.

They are distributed via:

```
wordpress.einetic.com/dist/
```

---

## 🧱 Roadmap

Phase 1:

* installer
* site detection
* fix + backup utilities

Phase 2:

* remote API
* fleet orchestration
* auto updates

Phase 3:

* malware monitoring daemon
* plugin vulnerability scanner
* central dashboard

---

## 📄 License

To be decided (MIT / Apache 2.0 recommended).

---

## 🤝 Contribution

Internal infra-first project.
External contributions allowed after core stabilization.