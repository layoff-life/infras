#!/bin/bash
# Stop Docker Stats Collector and Auto-Expose

METRICS_DIR="/tmp/node_exporter_textfile"
PID_FILE="$METRICS_DIR/docker-stats.pid"
AUTO_EXPOSE_PID_FILE="$METRICS_DIR/auto-expose.pid"

echo "Stopping Docker Stats Collector..."
STOPPED=0

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        kill "$PID" 2>/dev/null
        sleep 1
        ps -p "$PID" > /dev/null 2>&1 && kill -9 "$PID" 2>/dev/null
        echo "✅ Collector stopped (PID: $PID)"
    else
        echo "⚠️  Collector not running (stale PID file)"
    fi
    rm -f "$PID_FILE"
    STOPPED=1
fi

if [ -f "$AUTO_EXPOSE_PID_FILE" ]; then
    PID=$(cat "$AUTO_EXPOSE_PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        kill "$PID" 2>/dev/null
        sleep 1
        ps -p "$PID" > /dev/null 2>&1 && kill -9 "$PID" 2>/dev/null
        echo "✅ Auto-expose stopped (PID: $PID)"
    else
        echo "⚠️  Auto-expose not running (stale PID file)"
    fi
    rm -f "$AUTO_EXPOSE_PID_FILE"
    STOPPED=1
fi

if [ $STOPPED -eq 0 ]; then
    echo "⚠️  No collector processes found running"
    exit 1
fi

echo ""
echo "Note: Metrics file still available at:"
echo "  $METRICS_DIR/docker_stats.prom"
