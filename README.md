Here is a **short, clean, production-ready README** matching the tool you actually built.
I simplified it and put **copy-paste execution first**, then features.

---

# Einetic WP Fleet

**Einetic WP Fleet** is a lightweight CLI tool to manage multiple WordPress installations on a single server.

It works on:

* Hostinger shared hosting
* VPS servers
* CloudPanel servers
* Generic LAMP / LEMP environments

The tool automatically discovers WordPress installations and provides utilities to **verify, repair, update, and secure WordPress sites** using **wp-cli**.

---

# Quick Start (Copy-Paste)

Install directly on a server:

```bash
curl -s https://raw.githubusercontent.com/Einetic/wordpress.einetic.com/master/scripts/install.sh | bash
```

Go to the installation directory:

```bash
cd ~/einetic-wp-fleet
```

Run the tool:

```bash
./agent/agent.sh
```

---

# If Scripts Fail (Windows Users)

If the repo was edited on Windows you may need to fix line endings.

Run once:

```bash
sed -i 's/\r$//' agent/*.sh
sed -i 's/\r$//' util/*.sh
sed -i 's/\r$//' scripts/*.sh
```

Make scripts executable:

```bash
chmod +x agent/*.sh
chmod +x util/*.sh
chmod +x scripts/*.sh
```

Then run:

```bash
./agent/agent.sh
```

Note: The agent automatically fixes permissions on every run.

---

# Features

## WordPress Verification

* Verify WordPress core integrity
* Verify plugins checksum
* Verify themes checksum
* Verify database integrity

## WordPress Repair

* Reinstall WordPress core
* Reinstall all plugins
* Reinstall all themes
* Update WordPress
* Full WordPress repair

## Database Utilities

* Database check
* Database optimization

## Security Utilities

* Regenerate WordPress salts
* List administrator users
* Create new administrator
* Delete administrator
* Reset administrator password

## Bulk Operations

Run actions across **all WordPress sites on the server**:

* Core verification
* Plugin verification
* Theme verification
* Database verification
* Core repair
* Plugin reinstall
* Theme reinstall
* WordPress update
* Database optimization
* Salt regeneration
* Full WordPress repair

## Fleet Management

* Automatic WordPress site discovery
* Works with Hostinger and CloudPanel structures
* Daily automatic update check
* Manual update option in menu

---

# Supported WordPress Locations

Hostinger structure:

```
/home/<user>/domains/<domain>/public_html
```

CloudPanel structure:

```
/home/<user>/htdocs/<domain>
```

---

# Updating the Tool

Update from the menu:

```
Update Fleet
```

Or manually:

```bash
cd ~/einetic-wp-fleet
git pull
```

---

# Project Structure

```
agent/
    agent.sh
    config.sample.env

util/
    list-sites.sh
    reinstall-core.sh
    reinstall-plugins.sh
    reinstall-themes.sh
    update-wordpress.sh
    fix-wordpress.sh
    core.sh

scripts/
    install.sh
    update.sh
```

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

MIT (recommended)

---

If you want, I can also give you a **much better README used by professional GitHub projects** that adds:

* screenshots
* feature comparison table
* architecture diagram
* badges
* install statistics

It will make your repo look **10× more professional**.