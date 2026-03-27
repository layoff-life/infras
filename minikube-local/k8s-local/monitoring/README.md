# Monitoring Stack

Complete monitoring infrastructure for MiniKube cluster with Prometheus, Grafana, Loki, and service exporters.

---

## 🚀 Quick Start

All monitoring services should already be deployed. Check status:

```bash
kubectl get pods -n infras-monitoring
```

Expected pods:
- prometheus-0
- grafana-xxxxx
- node-exporter-xxxxx
- kube-state-metrics-xxxxx
- docker-stats-exporter-xxxxx

---

## 📊 Access Dashboards

For detailed access instructions (Cloudflare Tunnel, SSH tunnel, port-forward), see the **[Main README](../README.md#-access-services)**.

**Quick Links:**
- **Grafana**: https://grafana.yourdomain.com (or http://grafana.local:8080)
- **Prometheus**: https://prometheus.yourdomain.com (or http://prometheus.local:8080)

**Default Credentials:**
- Grafana: `admin` / `admin` (change on first login)

---

## 📈 Available Dashboards

### 1. Kubernetes Cluster Monitoring
**Dashboard:** Kubernetes Cluster Monitoring (via Prometheus)
**Panels:** Overall health map of Kubernetes components, running pods, namespaces, and cluster footprint.

### 2. Node Exporter Full (Infrastructure Metrics)
**Dashboard:** Node Exporter Full
**Panels:** Deep insights into host-level physical resources (CPU, Memory, Disk Space, Disk I/O, Network I/O).

### 3. Host Resources (Custom Docker Stats) ⭐
**Dashboard:** Host Docker Stats (restored from Cluster Overview)
**Panels:** Custom metrics from the `docker-stats-exporter`:
   - Host CPU Usage (gauge)
   - Host Memory Usage (gauge)
   - Host Memory Bytes (timeseries)
   - Host Network I/O (RX/TX timeseries)
   - Host Block I/O (Read/Write timeseries)
   - Host Memory Limit (stat)
   - **From host machine perspective** (actual resource usage on your computer)

### Prometheus Metrics
**Dashboard:** Prometheus 2.0 Stats
**URL:** http://grafana.local/d/prometheus/prometheus

**Panels:**
- Prometheus stats, performance, target health

---

## 🔧 Host Resources Monitoring

The **Host Resources** section in the Cluster Overview dashboard shows actual Docker container stats from the minikube container running on your host machine.

**Setup (one-time):**
```bash
/home/hunghlh/app/infras/minikube-local/k8s-local/monitoring/host-stats/setup-host-metrics.sh
```

**What it monitors:**
- `docker_cpu_percent` - CPU usage of minikube container from host
- `docker_memory_bytes` - Memory usage in bytes from host
- `docker_memory_limit_bytes` - Total memory limit
- `docker_memory_percent` - Memory usage percentage
- `docker_net_rx_bytes` - Network received bytes
- `docker_net_tx_bytes` - Network transmitted bytes
- `docker_block_read_bytes` - Block read bytes
- `docker_block_write_bytes` - Block write bytes

**Why it matters:**
- **Cluster metrics** show resource usage inside minikube VM
- **Host metrics** show actual resource consumption on your physical machine
- Host metrics include VM overhead, emulation layer, system services

For more details, see: `minikube-local/k8s-local/monitoring/host-stats/README.md`

---

## 🎯 Metrics Collection

### Service Exporters

| Exporter | Purpose | Access |
|----------|---------|--------|
| node-exporter | Cluster node metrics | :9100/metrics |
| kube-state-metrics | Kubernetes resource metrics | :8080/metrics |
| docker-stats-exporter | Host container stats | :9417/metrics |

### Prometheus Scrape Config

Prometheus scrapes metrics every 15 seconds from:
- node-exporter (node metrics)
- kube-state-metrics (k8s resources)
- docker-stats-exporter (host container stats)
- Service exporters (MySQL, PostgreSQL, Redis, Kafka - when deployed)

---

## 📁 Service Configuration

### Grafana
- **Deployment:** `grafana/deployment.yaml`
- **ConfigMap:** `grafana/configmap.yaml`
- **Dashboards:** `grafana/dashboards/`
- **Provisioning:** `grafana/dashboard-*.yaml`

> **Note on Dashboard ConfigMaps:** The Grafana dashboards are split into separate YAML ConfigMaps (e.g., `dashboard-node.yaml`) and injected via a projected volume in `deployment.yaml`. This is required to bypass the Kubernetes `metadata.annotations` size limit (256KB) that occurs during `kubectl apply`. A large dashboard like `Node Exporter Full` easily exceeds this limit if loaded into a single monolithic file.

### Prometheus
- **StatefulSet:** `prometheus/statefulset.yaml`
- **ConfigMap:** `prometheus/configmap.yaml`
- **Data PVC:** `prometheus-data-pvc`

### Exporters
- **Node Exporter:** `node-exporter.yaml`
- **Kube-State-Metrics:** `kube-state-metrics.yaml`
- **Docker Stats:** `docker-stats-exporter.yaml`

---

## 🛠️ Troubleshooting

### Grafana dashboard not showing data

1. **Check Prometheus targets:**
   ```bash
   # Open Prometheus UI
   kubectl port-forward -n infras-monitoring statefulset/prometheus 9090:9090
   # Go to http://localhost:9090/targets
   # All targets should be "UP"
   ```

2. **Check Grafana data source:**
   ```bash
   # In Grafana UI: Configuration → Data Sources → Prometheus
   # Verify URL: http://prometheus:9090
   # Click "Test" - should show "Data source is working"
   ```

3. **Restart services:**
   ```bash
   kubectl rollout restart deployment/grafana -n infras-monitoring
   kubectl rollout restart statefulset/prometheus -n infras-monitoring
   ```

### Host metrics not appearing

1. **Check if collector is running:**
   ```bash
   ps aux | grep docker-stats
   ```

2. **Check metrics file:**
   ```bash
   cat /tmp/node_exporter_textfile/docker_stats.prom
   ```

3. **Restart collector:**
   ```bash
   /home/hunghlh/app/infras/minikube-local/k8s-local/monitoring/host-stats/setup-host-metrics.sh
   ```

For more troubleshooting, see: `minikube-local/k8s-local/monitoring/host-stats/README.md`

### Prometheus scraping failing

**Check node-exporter pod:**
```bash
kubectl logs -n infras-monitoring daemonset/node-exporter
```

**Check kube-state-metrics:**
```bash
kubectl logs -n infras-monitoring deployment/kube-state-metrics
```

**Verify services exist:**
```bash
kubectl get svc -n infras-monitoring
```

---

## 🔄 Updating Dashboards

1. **Export dashboard from Grafana UI:**
   - Open dashboard
   - Click Share → Export → Save to JSON

2. **Update dashboard file:**
   ```bash
   minikube-local/k8s-local/monitoring/grafana/dashboards/cluster-overview.json
   ```

3. **Restart Grafana:**
   ```bash
   kubectl rollout restart deployment/grafana -n infras-monitoring
   ```

---

## 📝 Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Grafana | admin | admin (change on first login) |
| Prometheus | - | (no authentication) |

---

## 🧪 Verify Monitoring Setup

**Quick health check:**
```bash
# Check all pods are running
kubectl get pods -n infras-monitoring

# Check Prometheus targets
kubectl port-forward -n infras-monitoring statefulset/prometheus 9090:9090 &
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Check Grafana data source
kubectl port-forward -n infras-monitoring deployment/grafana 3000:3000 &
# Open http://localhost:3000 → Configuration → Data Sources → Test

# Check host metrics
cat /tmp/node_exporter_textfile/docker_stats.prom | grep docker_cpu_percent
```

---

## 📚 Related Documentation

- [Host Stats Monitoring](host-stats/README.md)
- [Ingress Setup](../ingress/README.md)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
