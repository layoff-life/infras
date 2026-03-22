#!/bin/bash
# ONE-CLICK SETUP: Docker Stats Collector for MiniKube Monitoring
# Run this on your HOST machine (where minikube runs)

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Docker Stats Collector - One Click Setup                ║"
echo "║  for MiniKube Host Resources Monitoring                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

METRICS_DIR="/tmp/node_exporter_textfile"
SCRIPT_PATH="$METRICS_DIR/docker-stats.sh"
AUTO_EXPOSE_SCRIPT="$METRICS_DIR/auto-expose.sh"
PID_FILE="$METRICS_DIR/docker-stats.pid"
AUTO_EXPOSE_PID_FILE="$METRICS_DIR/auto-expose.pid"
LOG_FILE="$METRICS_DIR/docker-stats.log"

# Check if minikube is running
echo "→ Checking minikube..."
if ! docker stats minikube --no-stream > /dev/null 2>&1; then
    echo "❌ minikube container not found!"
    echo ""
    echo "Please start minikube first:"
    echo "  minikube start"
    exit 1
fi
echo "✅ minikube is running"
echo ""

# Create metrics directory
echo "→ Creating metrics directory..."
mkdir -p "$METRICS_DIR"

# Create the collector script
echo "→ Creating collector script..."
cat > "$SCRIPT_PATH" << 'COLLECTOR_SCRIPT'
#!/bin/bash
METRICS_DIR="/tmp/node_exporter_textfile"
METRICS_FILE="$METRICS_DIR/docker_stats.prom"

mkdir -p "$METRICS_DIR"

# Helper function to convert values to bytes
convert_to_bytes() {
    local value=$1
    local unit=$2

    # Normalize unit
    case $unit in
        B|b)
            echo "${value%%.*}"
            ;;
        KB|KiB|kB)
            echo "$value * 1000" | bc 2>/dev/null | cut -d'.' -f1 || echo "0"
            ;;
        MB|MiB|mB)
            echo "$value * 1000 * 1000" | bc 2>/dev/null | cut -d'.' -f1 || echo "0"
            ;;
        GB|GiB|gB)
            echo "$value * 1000 * 1000 * 1000" | bc 2>/dev/null | cut -d'.' -f1 || echo "0"
            ;;
        TB|TiB|tB)
            echo "$value * 1000 * 1000 * 1000 * 1000" | bc 2>/dev/null | cut -d'.' -f1 || echo "0"
            ;;
        *)
            echo "0"
            ;;
    esac
}

while true; do
    STATS=$(docker stats minikube --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}" 2>/dev/null)

    if [ -z "$STATS" ]; then
        sleep 15
        continue
    fi

    CPU=$(echo "$STATS" | cut -d',' -f1 | sed 's/%//')
    MEM_FULL=$(echo "$STATS" | cut -d',' -f2)
    MEM_USAGE=$(echo "$MEM_FULL" | grep -oP '^\d[\d.]*' 2>/dev/null || echo "0")
    MEM_LIMIT=$(echo "$MEM_FULL" | grep -oP '/\s*\K\d[\d.]*' 2>/dev/null || echo "0")
    MEM_UNIT=$(echo "$MEM_FULL" | grep -oP '\d[\d.]*\s*\K[MG]iB' | head -1 2>/dev/null || echo "MiB")
    MEM_PERCENT=$(echo "$STATS" | cut -d',' -f3 | sed 's/%//')

    if [ "$MEM_UNIT" = "GiB" ]; then
        MEM_BYTES=$(echo "$MEM_USAGE * 1024 * 1024 * 1024" | bc 2>/dev/null | cut -d'.' -f1 || echo "0")
        MEM_LIMIT_BYTES=$(echo "$MEM_LIMIT * 1024 * 1024 * 1024" | bc 2>/dev/null | cut -d'.' -f1 || echo "0")
    else
        MEM_BYTES=$(echo "$MEM_USAGE * 1024 * 1024" | bc 2>/dev/null | cut -d'.' -f1 || echo "0")
        MEM_LIMIT_BYTES=$(echo "$MEM_LIMIT * 1024 * 1024" | bc 2>/dev/null | cut -d'.' -f1 || echo "0")
    fi

    # Parse NET I/O (format: "672MB / 183MB")
    NET_IO=$(echo "$STATS" | cut -d',' -f4)
    NET_RX=$(echo "$NET_IO" | grep -oP '^\S+' | sed 's/[[:space:]]*$//')
    NET_TX=$(echo "$NET_IO" | grep -oP '/\s*\K\S+')

    # Convert NET RX to bytes
    NET_RX_VALUE=$(echo "$NET_RX" | grep -oP '^\d[\d.]*' || echo "0")
    NET_RX_UNIT=$(echo "$NET_RX" | grep -oP '\d[\d.]*\s*\K[BKMGT]?i?B?' | head -1 2>/dev/null || echo "B")
    NET_RX_BYTES=$(convert_to_bytes "$NET_RX_VALUE" "$NET_RX_UNIT")

    # Convert NET TX to bytes
    NET_TX_VALUE=$(echo "$NET_TX" | grep -oP '^\d[\d.]*' || echo "0")
    NET_TX_UNIT=$(echo "$NET_TX" | grep -oP '\d[\d.]*\s*\K[BKMGT]?i?B?' | head -1 2>/dev/null || echo "B")
    NET_TX_BYTES=$(convert_to_bytes "$NET_TX_VALUE" "$NET_TX_UNIT")

    # Parse BLOCK I/O (format: "0B / 4.42GB")
    BLOCK_IO=$(echo "$STATS" | cut -d',' -f5)
    BLOCK_READ=$(echo "$BLOCK_IO" | grep -oP '^\S+' | sed 's/[[:space:]]*$//')
    BLOCK_WRITE=$(echo "$BLOCK_IO" | grep -oP '/\s*\K\S+')

    # Convert BLOCK READ to bytes
    BLOCK_READ_VALUE=$(echo "$BLOCK_READ" | grep -oP '^\d[\d.]*' || echo "0")
    BLOCK_READ_UNIT=$(echo "$BLOCK_READ" | grep -oP '\d[\d.]*\s*\K[BKMGT]?i?B?' | head -1 2>/dev/null || echo "B")
    BLOCK_READ_BYTES=$(convert_to_bytes "$BLOCK_READ_VALUE" "$BLOCK_READ_UNIT")

    # Convert BLOCK WRITE to bytes
    BLOCK_WRITE_VALUE=$(echo "$BLOCK_WRITE" | grep -oP '^\d[\d.]*' || echo "0")
    BLOCK_WRITE_UNIT=$(echo "$BLOCK_WRITE" | grep -oP '\d[\d.]*\s*\K[BKMGT]?i?B?' | head -1 2>/dev/null || echo "B")
    BLOCK_WRITE_BYTES=$(convert_to_bytes "$BLOCK_WRITE_VALUE" "$BLOCK_WRITE_UNIT")

    cat > "$METRICS_FILE" << PROM_METRICS
# HELP docker_cpu_percent CPU from host
# TYPE docker_cpu_percent gauge
docker_cpu_percent{container="minikube"} ${CPU:-0}
# HELP docker_memory_bytes Memory from host
# TYPE docker_memory_bytes gauge
docker_memory_bytes{container="minikube"} ${MEM_BYTES:-0}
# HELP docker_memory_limit_bytes Memory limit from host
# TYPE docker_memory_limit_bytes gauge
docker_memory_limit_bytes{container="minikube"} ${MEM_LIMIT_BYTES:-0}
# HELP docker_memory_percent Memory percent from host
# TYPE docker_memory_percent gauge
docker_memory_percent{container="minikube"} ${MEM_PERCENT:-0}
# HELP docker_net_rx_bytes Network RX from host
# TYPE docker_net_rx_bytes gauge
docker_net_rx_bytes{container="minikube"} ${NET_RX_BYTES:-0}
# HELP docker_net_tx_bytes Network TX from host
# TYPE docker_net_tx_bytes gauge
docker_net_tx_bytes{container="minikube"} ${NET_TX_BYTES:-0}
# HELP docker_block_read_bytes Block read from host
# TYPE docker_block_read_bytes gauge
docker_block_read_bytes{container="minikube"} ${BLOCK_READ_BYTES:-0}
# HELP docker_block_write_bytes Block write from host
# TYPE docker_block_write_bytes gauge
docker_block_write_bytes{container="minikube"} ${BLOCK_WRITE_BYTES:-0}
# HELP docker_stats_scrape_seconds Last scrape
# TYPE docker_stats_scrape_seconds gauge
docker_stats_scrape_seconds{container="minikube"} $(date +%s)
PROM_METRICS
    sleep 15
done
COLLECTOR_SCRIPT

chmod +x "$SCRIPT_PATH"

# Create auto-expose script
echo "→ Creating auto-expose script..."
cat > "$AUTO_EXPOSE_SCRIPT" << 'EXPOSE_SCRIPT'
#!/bin/bash
METRICS_FILE="/tmp/node_exporter_textfile/docker_stats.prom"

while true; do
    if [ -f "$METRICS_FILE" ]; then
        minikube ssh "sudo mkdir -p /tmp/node_exporter_textfile" 2>/dev/null || true
        minikube cp "$METRICS_FILE" /tmp/docker-stats-to-expose.prom 2>/dev/null || true
        minikube ssh "sudo mv /tmp/docker-stats-to-expose.prom /tmp/node_exporter_textfile/docker_stats.prom" 2>/dev/null || true
        echo "$(date '+%H:%M:%S') - Metrics exposed to minikube"
    fi
    sleep 20
done
EXPOSE_SCRIPT

chmod +x "$AUTO_EXPOSE_SCRIPT"

# Start collector
echo "→ Starting docker stats collector..."
if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; then
    PID=$(cat "$PID_FILE")
    echo "⚠️  Collector already running (PID: $PID)"
    echo "   Stopping old process..."
    kill "$PID" 2>/dev/null || true
    sleep 1
fi

nohup "$SCRIPT_PATH" > "$LOG_FILE" 2>&1 &
COLLECTOR_PID=$!
echo "$COLLECTOR_PID" > "$PID_FILE"

# Start auto-expose
echo "→ Starting auto-expose to minikube..."
nohup "$AUTO_EXPOSE_SCRIPT" >> "$LOG_FILE" 2>&1 &
EXPOSE_PID=$!
echo "$EXPOSE_PID" > "$AUTO_EXPOSE_PID_FILE"

# Wait a moment for first collection
sleep 3

# Do first exposure immediately
echo "→ Exposing metrics to minikube (first time)..."
if [ -f "$METRICS_DIR/docker_stats.prom" ]; then
    minikube ssh "sudo mkdir -p /tmp/node_exporter_textfile" 2>/dev/null || true
    minikube cp "$METRICS_DIR/docker_stats.prom" /tmp/docker-stats-upload.prom 2>/dev/null || true
    minikube ssh "sudo mv /tmp/docker-stats-upload.prom /tmp/node_exporter_textfile/docker_stats.prom" 2>/dev/null || true
    echo "✅ Metrics exposed to minikube"
else
    echo "⚠️  Metrics file not ready yet, will expose in next cycle"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ SETUP COMPLETE!                                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Running processes:"
echo "  • Collector PID: $COLLECTOR_PID"
echo "  • Auto-expose PID: $EXPOSE_PID"
echo ""
echo "What's happening now:"
echo "  • Docker stats collected every 15 seconds"
echo "  • Metrics auto-exposed to minikube every 20 seconds"
echo "  • Grafana dashboard will show host resources"
echo ""
echo "View metrics:"
echo "  cat $METRICS_DIR/docker_stats.prom"
echo ""
echo "View logs:"
echo "  tail -f $LOG_FILE"
echo ""
echo "View in Grafana:"
echo "  kubectl port-forward -n infras-monitoring deployment/grafana 3000:3000"
echo "  Open: http://localhost:3000/d/minikube-cluster/minikube-cluster-overview"
echo "  Check section: '3. HOST RESOURCES (Docker Stats)'"
echo ""
echo "Stop everything:"
echo "  kill $COLLECTOR_PID $EXPOSE_PID"
echo "  rm $PID_FILE $AUTO_EXPOSE_PID_FILE"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Wait 30-60 seconds for metrics to appear in Grafana"
echo "════════════════════════════════════════════════════════════"
echo ""
