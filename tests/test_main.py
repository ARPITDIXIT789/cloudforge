"""
Unit tests for CloudForge Mission Control FastAPI Application.
Validates:
- Healthcheck endpoint (/healthz)
- Prometheus metrics endpoint (/metrics)
- Simulated error endpoint (/api/simulate-error)
"""

import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_healthz_endpoint():
    """Verify /healthz returns 200 OK and healthy status."""
    response = client.get("/healthz")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "pod" in data
    assert "version" in data

def test_metrics_endpoint():
    """Verify Prometheus /metrics returns scrapable text output."""
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "cloudforge_http_requests_total" in response.text

def test_simulate_error_endpoint():
    """Verify /api/simulate-error correctly returns HTTP 500 for Alertmanager."""
    response = client.get("/api/simulate-error")
    assert response.status_code == 500
    assert "Simulated 500 error" in response.json()["detail"]

def test_dashboard_endpoint():
    """Verify HTML dashboard renders successfully."""
    response = client.get("/")
    assert response.status_code == 200
    assert "CloudForge" in response.text
    assert "Mission Control" in response.text
