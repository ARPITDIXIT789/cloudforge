###############################################################################
# CloudForge — Multi-Stage Production Dockerfile
# Optimized for minimal attack surface, Trivy vulnerability compliance & speed
###############################################################################

# ─── Stage 1: Build Dependencies ─────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

# Install compilation essentials for psycopg2 / C-extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt requirements.txt

RUN pip install --no-cache-dir --user -r requirements.txt

# ─── Stage 2: Minimal Runtime ────────────────────────────────────────────────
FROM python:3.12-slim AS runner

WORKDIR /app

# Install only minimal runtime shared libraries (libpq5 for PostgreSQL)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-privileged service user adhering to CIS Kubernetes Benchmark
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/bash -m appuser

# Copy installed Python packages from builder stage
COPY --from=builder /root/.local /home/appuser/.local

# Copy application source code & templates
COPY app/ /app/app/

# Set ownership to unprivileged user
RUN chown -R appuser:appgroup /app /home/appuser

# Configure environment variables
ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/healthz || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
