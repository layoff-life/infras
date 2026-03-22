# Docker Stats Collector for MiniKube Monitoring

Collects Docker stats from the minikube container on your host machine and exposes them to Grafana/Prometheus running inside minikube.

## 🚀 Quick Start (ONE SCRIPT)

### Start everything:

```bash
/home/hunghlh/app/infras/minikube-local/k8s-local/monitoring/host-stats/setup-host-metrics.sh
```

That's it! This single script will:
- ✅ Start collecting docker stats every 15 seconds
- ✅ Auto-expose metrics to minikube every 20 seconds
- ✅ Make metrics available in Grafana dashboard

### Stop everything:

```bash
/home/hunghlh/app/infras/minikube/local/k8s-local/monitoring/host-stats/stop-host-metrics.sh
```

---

## 📊 View in Grafana

After running the setup script, wait 30-60 seconds, then access Grafana:

### Access Methods

**Via Cloudflare Tunnel:**
- URL: https://grafana.yourdomain.com/d/minikube-cluster/minikube-cluster-overview

**Via SSH Tunnel:**
```bash
# On local machine
ssh -L 8080:localhost:8080 user@server-ip -N
# Access: http://grafana.local:8080/d/minikube-cluster/minikube-cluster-overview
```

**Via Port Forward:**
```bash
kubectl port-forward -n infras-monitoring deployment/grafana 3000:3000
# Access: http://localhost:3000/d/minikube-cluster/minikube-cluster-overview
```

Check the **"3. HOST RESOURCES (Docker Stats)"** section for actual docker stats!

---

## 🔍 What's Being Collected

| Metric | Description | Example |
|--------|-------------|---------|
| `docker_cpu_percent` | CPU usage of minikube container from host perspective | `10.5` |
| `docker_memory_bytes` | Memory usage in bytes from host perspective | `1358283407` |
| `docker_memory_percent` | Memory usage percentage from host perspective | `7.9` |
| `docker_stats_scrape_seconds` | Unix timestamp of last successful scrape | `1774139996` |

---

## 🛠️ How It Works

1. **Collector Script** runs on your host machine (outside minikube)
   - Executes `docker stats minikube --no-stream` every 15 seconds
   - Parses CPU and memory usage
   - Writes Prometheus format metrics to `/tmp/node_exporter_textfile/docker_stats.prom`

2. **Auto-Expose Script** runs simultaneously
   - Reads metrics from `/tmp/node_exporter_textfile/docker_stats.prom`
   - Copies them into minikube VM via `minikube ssh`
   - Writes to `/tmp/node_exporter_textfile/docker_stats.prom` in minikube VM
   - node-exporter pod mounts this directory via hostPath volume
   - Prometheus scrapes node-exporter and gets the host metrics

3. **Grafana Dashboard**
   - Queries Prometheus for `docker_*` metrics
   - Displays them in the "HOST RESOURCES" section
   - Shows host perspective vs cluster-internal perspective

---

## 📈 Understanding: Host vs Cluster Metrics

| Perspective | What It Measures | Typical Values |
|-------------|------------------|----------------|
| **Host (Docker Stats)** | minikube container usage on your physical machine | CPU: 10%, Memory: 1.3GB/16GB (7.9%) |
| **Cluster (Node-exporter)** | Processes running inside minikube VM | CPU: 2%, Memory: 13% |

### Why the Difference?

- **Host metrics** include: VM overhead, system services, emulation layer
- **Cluster metrics** show only: Your Kubernetes workloads

For development with minikube, **host metrics** show actual resource consumption on your machine!

---

## 🧪 Verify It's Working

```bash
# Check current metrics
cat /tmp/node_exporter_textfile/docker_stats.prom

# View logs
tail -f /tmp/node_exporter_textfile/docker_stats.log

# Compare with actual docker stats
docker stats minikube --no-stream

# Check if processes are running
ps aux | grep docker-stats
```

---

## 🛑 Troubleshooting

### "minikube container not found"

Start minikube first:
```bash
minikube start
```

### "Metrics not appearing in Grafana"

1. Check if collector is running:
   ```bash
   ps aux | grep docker-stats
   ```

2. Check logs:
   ```bash
   tail -f /tmp/node_exporter_textfile/docker-stats.log
   ```

3. Verify metrics file exists:
   ```bash
   cat /tmp/node_exporter_textfile/docker_stats.prom
   ```

4. Wait 30-60 seconds for Prometheus to scrape and Grafana to refresh

### Restart the collector

```bash
# Stop
/home/hunghlh/app/infras/minikube-local/k8s-local/monitoring/host-stats/stop-host-metrics.sh

# Start again
/home/hunghlh/app/infras/minikube-local/k8s-local/monitoring/host-stats/setup-host-metrics.sh
```

---

## 📁 Files Created During Setup

| File | Purpose |
|------|---------|
| `/tmp/node_exporter_textfile/docker-stats.sh` | Collector script |
| `/tmp/node_exporter_textfile/auto-expose.sh` | Auto-expose script |
| `/tmp/node_exporter_textfile/docker-stats.prom` | Current metrics |
| `/tmp/node_exporter_textfile/docker-stats.pid` | Collector PID |
| `/tmp/node_exporter_textfile/auto-expose.pid` | Auto-expose PID |
| `/tmp/node_exporter_textfile/docker-stats.log` | Log file |

---

## 🎯 What You Get in Grafana

Your dashboard now has **3 complete sections**:

1. **CLUSTER OVERVIEW**
   - Total Pods, Namespaces, Nodes
   - Pod Status pie chart
   - Pod Restarts (filtered to only show pods with restarts)
   - Running Pods Details table

2. **NODE/INFRASTRUCTURE METRICS**
   - CPU, Memory, Disk I/O, Network I/O
   - From **cluster-internal** perspective

3. **HOST RESOURCES (Docker Stats)** ⭐
   - Host CPU Usage (gauge)
   - Host Memory Usage (gauge)
   - Host Memory Bytes (time series)
   - Setup instructions panel
   - From **host machine** perspective

---

## 📝 Notes

- **Collection Interval**: Every 15 seconds
- **Exposure Interval**: Every 20 seconds
- **Log Location**: `/tmp/node_exporter_textfile/docker-stats.log`
- **Persistence**: Metrics are NOT persisted across reboots (restart collector after reboot)
- **Resource Usage**: Minimal (~1-2% CPU, ~10MB RAM)

---

## 🔄 After System Reboot

The collector doesn't auto-start after reboot. Simply run:

```bash
/home/hunghlh/app/infras/minikube-local/k8s-local/monitoring/host-stats/setup-host-metrics.sh
```

---

## 🤝 Contributing

To modify collection behavior, edit these files created by the setup script:
- `/tmp/node_exporter_textfile/docker-stats.sh` (collector)
- `/tmp/node_exporter_textfile/auto-expose.sh` (expose)
