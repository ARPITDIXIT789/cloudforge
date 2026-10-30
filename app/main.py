"""
CloudForge — Mission Control Platform API & Microservice
Production-grade FastAPI application demonstrating:
- Kubernetes Pod & Node runtime introspection
- Amazon RDS PostgreSQL multi-tier persistence
- Prometheus metrics scraping endpoint (/metrics)
- Kubernetes Liveness & Readiness health checks (/healthz)
- Chaos / SRE error simulation endpoint for Alertmanager
"""

import os
import time
import socket
from datetime import datetime
from typing import List, Optional

from fastapi import FastAPI, Request, Form, HTTPException, Response
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

# ---------------------------------------------------------------------------
# Application & Environment Configuration
# ---------------------------------------------------------------------------
APP_VERSION = os.getenv("APP_VERSION", "v1.0.0")
ENVIRONMENT = os.getenv("ENVIRONMENT", "dev")
PROJECT_NAME = os.getenv("PROJECT_NAME", "CloudForge")

# Database Configuration
DB_HOST = os.getenv("DB_HOST", "cloudforge-dev-rds.cpscqcymc878.ap-south-1.rds.amazonaws.com")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "cloudforge")
DB_USER = os.getenv("DB_USER", "cloudforge_admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "CloudForge2026Secure!")
DB_TIMEOUT = int(os.getenv("DB_TIMEOUT", "3"))

# Runtime Host Metadata
POD_NAME = os.getenv("HOSTNAME", socket.gethostname())
POD_IP = socket.gethostbyname(socket.gethostname())
NODE_NAME = os.getenv("NODE_NAME", "EKS Worker (Amazon Linux 2023)")
AWS_REGION = os.getenv("AWS_REGION", "ap-south-1")

START_TIME = time.time()

# ---------------------------------------------------------------------------
# Prometheus Observability Metrics
# ---------------------------------------------------------------------------
HTTP_REQUESTS_TOTAL = Counter(
    "cloudforge_http_requests_total",
    "Total HTTP requests handled by CloudForge microservice",
    ["method", "endpoint", "status"]
)

HTTP_REQUEST_DURATION = Histogram(
    "cloudforge_http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["endpoint"]
)

DB_QUERY_DURATION = Histogram(
    "cloudforge_db_query_duration_seconds",
    "Database query latency in seconds"
)

# ---------------------------------------------------------------------------
# FastAPI Initialization
# ---------------------------------------------------------------------------
app = FastAPI(
    title="CloudForge Mission Control",
    description="Enterprise DevSecOps Platform Microservice",
    version=APP_VERSION
)

templates = Jinja2Templates(directory="app/templates")

# In-memory fallback if database is offline/unreachable
MEMORY_LOGS = [
    {
        "id": 1,
        "title": "CloudForge Platform Initialized via GitOps",
        "author": "ArgoCD",
        "pod_name": POD_NAME,
        "created_at": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    }
]

# ---------------------------------------------------------------------------
# Database Utilities
# ---------------------------------------------------------------------------
def get_db_connection():
    """Establish connection to Amazon RDS PostgreSQL with short timeout."""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=DB_TIMEOUT
    )

def init_db():
    """Initialize database tables if connected."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS platform_audit_logs (
                        id SERIAL PRIMARY KEY,
                        title VARCHAR(255) NOT NULL,
                        author VARCHAR(100) NOT NULL,
                        pod_name VARCHAR(100) NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    );
                """)
                conn.commit()
        return True, "Connected & Initialized"
    except Exception as e:
        return False, str(e)

def test_db_status():
    """Check database health and query latency."""
    t0 = time.time()
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT version();")
                version = cur.fetchone()[0]
                latency_ms = round((time.time() - t0) * 1000, 2)
                return True, latency_ms, version.split(" ")[0] + " " + version.split(" ")[1]
    except Exception as e:
        return False, None, str(e)

# Attempt initial DB setup at startup (non-blocking)
init_db()

# ---------------------------------------------------------------------------
# Middleware: Request Logging & Prometheus Metrics
# ---------------------------------------------------------------------------
@app.middleware("http")
async def prometheus_metrics_middleware(request: Request, call_next):
    start_time = time.time()
    try:
        response = await call_next(request)
        status_code = response.status_code
    except Exception:
        status_code = 500
        raise
    finally:
        duration = time.time() - start_time
        endpoint = request.url.path
        HTTP_REQUESTS_TOTAL.labels(
            method=request.method,
            endpoint=endpoint,
            status=status_code
        ).inc()
        HTTP_REQUEST_DURATION.labels(endpoint=endpoint).observe(duration)
    return response

# ---------------------------------------------------------------------------
# REST Endpoints
# ---------------------------------------------------------------------------
@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    """Render the primary CloudForge Mission Control interactive UI."""
    db_connected, db_latency, db_info = test_db_status()
    logs = []

    if db_connected:
        try:
            with get_db_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("SELECT id, title, author, pod_name, created_at FROM platform_audit_logs ORDER BY id DESC LIMIT 10;")
                    rows = cur.fetchall()
                    for r in rows:
                        logs.append({
                            "id": r["id"],
                            "title": r["title"],
                            "author": r["author"],
                            "pod_name": r["pod_name"],
                            "created_at": r["created_at"].strftime("%Y-%m-%d %H:%M:%S")
                        })
        except Exception:
            logs = MEMORY_LOGS
    else:
        logs = MEMORY_LOGS

    uptime_seconds = int(time.time() - START_TIME)
    uptime_str = f"{uptime_seconds // 3600}h {(uptime_seconds % 3600) // 60}m {uptime_seconds % 60}s"

    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={
            "project_name": PROJECT_NAME,
            "app_version": APP_VERSION,
            "environment": ENVIRONMENT,
            "pod_name": POD_NAME,
            "pod_ip": POD_IP,
            "node_name": NODE_NAME,
            "aws_region": AWS_REGION,
            "db_connected": db_connected,
            "db_host": DB_HOST,
            "db_latency": db_latency,
            "db_info": db_info,
            "uptime": uptime_str,
            "logs": logs
        }
    )

@app.post("/api/logs")
async def add_log(title: str = Form(...), author: str = Form("DevOps Engineer")):
    """Record an audit entry into PostgreSQL RDS (or fallback memory)."""
    db_connected, _, _ = test_db_status()
    t0 = time.time()

    if db_connected:
        try:
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        "INSERT INTO platform_audit_logs (title, author, pod_name) VALUES (%s, %s, %s);",
                        (title, author, POD_NAME)
                    )
                    conn.commit()
            DB_QUERY_DURATION.observe(time.time() - t0)
            return JSONResponse({"status": "success", "storage": "PostgreSQL RDS", "pod": POD_NAME})
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    else:
        MEMORY_LOGS.insert(0, {
            "id": len(MEMORY_LOGS) + 1,
            "title": title,
            "author": author,
            "pod_name": POD_NAME,
            "created_at": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
        })
        return JSONResponse({"status": "success", "storage": "In-Memory Fallback", "pod": POD_NAME})

@app.get("/healthz")
async def healthz():
    """Kubernetes Liveness & Readiness probe endpoint."""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "pod": POD_NAME,
        "version": APP_VERSION
    }

@app.get("/metrics")
async def metrics():
    """Prometheus Scrape Endpoint."""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/api/simulate-error")
async def simulate_error():
    """Simulate a 500 Internal Server Error for Alertmanager testing."""
    raise HTTPException(status_code=500, detail="Simulated 500 error triggered for SRE observability validation!")
