import pytest
import json
from app import app

@pytest.fixture
def client():
    """Create a test client for the Flask application."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_hello_endpoint(client):
    """Test the main hello endpoint."""
    response = client.get('/')
    assert response.status_code == 200
    assert b'Hello from Flask App!' in response.data

def test_health_endpoint(client):
    """Test the health check endpoint."""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert 'message' in data

def test_info_endpoint(client):
    """Test the info endpoint."""
    response = client.get('/info')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['app'] == 'Flask Application'
    assert data['version'] == '1.0.0'
    assert 'environment' in data

def test_404_endpoint(client):
    """Test that non-existent endpoints return 404."""
    response = client.get('/nonexistent')
    assert response.status_code == 404

def test_health_endpoint_content_type(client):
    """Test that health endpoint returns JSON content type."""
    response = client.get('/health')
    assert response.content_type == 'application/json'

def test_info_endpoint_content_type(client):
    """Test that info endpoint returns JSON content type."""
    response = client.get('/info')
    assert response.content_type == 'application/json' 