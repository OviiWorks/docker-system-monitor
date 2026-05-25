# 🐳 Docker & Server Monitor

A lightweight Bash script that monitors:

* 🟢 Docker container status (running, exited, restarting)
* ⚠️ System health (CPU, RAM, Disk usage)
* 📦 Daily package updates (APT)

It sends notifications to **Discord** via a webhook, so you always know the state of your server in real-time.

---

## 📌 Features

* Sends Discord alerts when:

  * A Docker container changes state (running → exited, exited → running, restarting, etc.)
  * CPU, RAM, or Disk usage exceed defined thresholds
  * Daily package updates are available
* Tracks container state in a temporary file so you only get notified on changes (not every run)
* Easy setup with configurable options in `config.env`

---

## ⚙️ Installation

Clone the repository:

```bash
git clone https://github.com/OviiWorks/docker-monitor.git
cd docker-monitor
```

Make the script executable:

```bash
chmod +x docker_monitor.sh
```

---

## 🔧 Configuration

Copy the example config file:

```bash
cp config.env.example config.env
```

Edit `config.env` and set your values:

```bash
# === DISCORD WEBHOOK ===
DISCORD_WEBHOOK="https://discord.com/api/webhooks/XXXX/XXXX"

# === THRESHOLDS ===
CPU_THRESHOLD=90
RAM_THRESHOLD=90
DISK_THRESHOLD=90
DISK_PARTITION="/dev/sda1"

# === FILE PATHS ===
STATE_FILE="/var/tmp/docker_monitor_state.txt"
LOG_FILE="/var/tmp/docker_monitor.log"
```

⚠️ **Never commit `config.env`** — it contains secrets (your webhook URL).
We provide `.gitignore` to protect it.

---

## 🚀 Usage

### Run manually

```bash
./docker_monitor.sh
```

### Daily updates check

```bash
./docker_monitor.sh daily
```

### Cron job

For continuous monitoring, add to `cron`:

```bash
*/5 * * * * /path/to/docker-monitor/docker_monitor.sh
0 21 * * * /path/to/docker-monitor/docker_monitor.sh daily
```

This will:

* Run the script every 5 minutes to check Docker and system health
* Run daily at 21:00 to report package updates

---

## 🔒 Logs

* Script activity: `/var/tmp/docker_monitor.log`
* Docker container state: `/var/tmp/docker_monitor_state.txt`

---

## 📝 License

MIT License

