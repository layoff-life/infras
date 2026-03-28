# Dockerfile for infras-cli API
# Single-stage build for simplicity and reliability
FROM python:3.12-slim

# Set environment variable to avoid Python buffer issues
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser -u 1000 appuser

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
# Most packages are pure Python, so we don't need gcc/g++
RUN pip install --no-cache-dir -r requirements.txt

# Copy kubectl binary from host (must be downloaded before build)
# This avoids network issues during Docker build
COPY kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl

# Verify kubectl installation
RUN kubectl version --client

# Copy application code
COPY app/ ./app/
COPY setup.py pyproject.toml ./

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose ports
# 8000: FastAPI HTTP server
# 9090: Prometheus metrics (optional, if running separate metrics server)
EXPOSE 8000 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/v1/health/live')" || exit 1

# Set entrypoint to fetch Vault token before starting
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Run the application with uvicorn
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
