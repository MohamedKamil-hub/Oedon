import hashlib
import json
import os
from pathlib import Path
from flask import Flask, request, jsonify

app = Flask(__name__)

# ── Config from env ─────────────────────────────────────
OEDON_PUBLIC_KEY = os.environ.get("OEDON_PUBLIC_KEY", "not-configured")

# ── Deployment registry (persistent JSON file) ─────────
REGISTRY_FILE = Path(os.environ.get("REGISTRY_FILE", "/app/deployments.json"))

def _load_registry() -> dict:
    if REGISTRY_FILE.is_file():
        with open(REGISTRY_FILE) as f:
            return json.load(f)
    return {}

def _save_registry(data: dict):
    with open(REGISTRY_FILE, "w") as f:
        json.dump(data, f, indent=2)


@app.route('/verify', methods=['GET'])
def verify():
    """Cualquiera puede consultar si el despliegue es íntegro"""
    app_name = request.args.get('app')
    current_hash = request.args.get('hash')
    registry = _load_registry()

    if app_name in registry:
        expected = registry[app_name]
        if current_hash == expected:
            return jsonify({"status": "VERIFIED", "msg": "Código íntegro y firmado por Oedon."}), 200
        else:
            return jsonify({"status": "COMPROMISED", "msg": "¡Alerta! El código ha sido modificado."}), 403
    return jsonify({"status": "NOT_FOUND"}), 404


@app.route('/sign', methods=['POST'])
def sign_deploy():
    auth = request.headers.get('X-Oedon-Key', '')
    if auth != OEDON_PUBLIC_KEY or OEDON_PUBLIC_KEY == 'not-configured':
        return jsonify({"status": "UNAUTHORIZED"}), 401

    data = request.json
    app_name = data.get('app')
    new_hash = data.get('hash')
    registry = _load_registry()
    registry[app_name] = new_hash
    _save_registry(registry)
    return jsonify({"status": "SIGNED", "app": app_name})



@app.route('/')
def home():
    return """
    <body style="background:#050505; color:#d1d1d1; font-family:monospace; padding:50px;">
        <h1 style="color:#8b0000;">OEDON NOTARY SERVICE</h1>
        <p>Status: <span style="color:#00ff41;">ONLINE</span></p>
        <p>Security Level: <b>MAXIMUM</b></p>
        <hr style="border:1px solid #333;">
        <p>Use <code>/verify?app=NAME&hash=VALUE</code> to check deployment integrity.</p>
        <br>
        <small style="color:#444;">&copy; 2026 Oedon Infrastructure - Invisible but Omnipresent</small>
    </body>
    """


if __name__ == '__main__':
    port = int(os.environ.get("APP_PORT", "5000"))
    app.run(host='0.0.0.0', port=port)
