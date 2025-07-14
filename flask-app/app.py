from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello from Flask App!"

@app.route("/health")
def health():
    return jsonify({"status": "healthy", "message": "Flask app is running"})

@app.route("/info")
def info():
    return jsonify({
        "app": "Flask Application",
        "version": "1.0.0",
        "environment": os.getenv("ENVIRONMENT", "development")
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)