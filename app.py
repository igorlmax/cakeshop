import os

# Send logs, requests and errors to Application Insights if it is configured.
# This must run before Flask is imported.
if os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"):
    from azure.monitor.opentelemetry import configure_azure_monitor
    configure_azure_monitor()

from flask import Flask, jsonify
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

app = Flask(__name__)

CAKES = [
    {"name": "Chocolate Dream", "price": 24.0},
    {"name": "Lemon Cloud", "price": 21.0},
    {"name": "Strawberry Swirl", "price": 23.0},
]

@app.get("/")
def home():
    items = "".join(f"<li>{c['name']}: {c['price']:.2f}</li>" for c in CAKES)
    return f"<h1>Sweet Crumbs Bakery</h1><ul>{items}</ul>"

@app.get("/health")
def health():
    return jsonify(status="ok", env=os.getenv("APP_ENV", "local"))

@app.get("/api/cakes")
def cakes():
    return jsonify(CAKES)

@app.get("/api/photos")
def photos():
    account = os.getenv("STORAGE_ACCOUNT")
    if not account:
        return jsonify(error="STORAGE_ACCOUNT is not set"), 500
    # The app proves who it is with its managed identity. No password anywhere.
    svc = BlobServiceClient(f"https://{account}.blob.core.windows.net",
                            credential=DefaultAzureCredential())
    names = [b.name for b in svc.get_container_client("cakes").list_blobs()]
    return jsonify(photos=names)

@app.get("/api/config-check")
def config_check():
    # Reports whether a secret is present, never its value.
    return jsonify(orders_db_configured=bool(os.getenv("ORDERS_DB")))

@app.get("/api/crash")
def crash():
    # Only for practice: lets us create real errors on demand.
    if os.getenv("ENABLE_CRASH_TEST") == "true":
        raise RuntimeError("Practice crash: the oven exploded")
    return jsonify(message="crash test is off")