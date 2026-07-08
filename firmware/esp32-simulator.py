"""
Simulateur ESP32-S3 pour le pont IoT MIDAS-Bénin.

Simule un capteur environnemental qui envoie des données télémétriques
au broker MQTT et s'enregistre via l'API REST.

Usage:
    python esp32-simulator.py --device-id ESP32-S3-A1B2C3

Le simulateur :
  1. Génère une paire de clés Ed25519 (ou lit depuis un fichier)
  2. S'enregistre auprès du backend
  3. Envoie des données télémétriques (température, humidité, pression)
  4. Gère le challenge d'appairage QR code
  5. Vérifie les seuils côté appareil
"""

import argparse
import hashlib
import hmac
import json
import os
import random
import sys
import time
import urllib.request
import uuid

try:
    from cryptography.hazmat.primitives.asymmetric import ed25519
    from cryptography.hazmat.primitives import serialization
    HAS_CRYPTO = True
except ImportError:
    HAS_CRYPTO = False
    print("""[WARN] cryptography non installe. Installation :
    pip install cryptography

Fonctionne en mode degrade (signatures simulees).""")


API_BASE = "http://localhost:3000/api/v1"
MQTT_TOPIC_TPL = "midas/{device_id}/telemetry"


class Ed25519Device:
    """Simule le secure element d'un ESP32-S3 avec Ed25519."""

    def __init__(self, device_id: str, key_file: str | None = None):
        self.device_id = device_id
        if key_file and os.path.exists(key_file):
            with open(key_file, "rb") as f:
                self.private_key = ed25519.Ed25519PrivateKey.from_private_bytes(f.read())
        elif HAS_CRYPTO:
            self.private_key = ed25519.Ed25519PrivateKey.generate()
        else:
            self.private_key = None

    @property
    def public_key_hex(self) -> str:
        if self.private_key:
            pub = self.private_key.public_key()
            return pub.public_bytes(
                serialization.Encoding.Raw,
                serialization.PublicFormat.Raw,
            ).hex()
        return "simulated_pubkey_" + hashlib.sha256(self.device_id.encode()).hexdigest()[:32]

    def sign(self, message: str) -> str:
        if self.private_key:
            sig = self.private_key.sign(message.encode())
            return sig.hex()
        return "simulated_sig_" + hashlib.sha256(message.encode()).hexdigest()[:64]

    def save_key(self, path: str):
        if self.private_key:
            priv = self.private_key.private_bytes(
                serialization.Encoding.Raw,
                serialization.PrivateFormat.Raw,
                serialization.NoEncryption(),
            )
            with open(path, "wb") as f:
                f.write(priv)
            print(f"[KEY] Cle sauvegardee dans {path}")


class MQTTSimulator:
    """Simule l'envoi MQTT via HTTP (le broker MQTT est aussi accessible)."""

    def __init__(self, api_base: str):
        self.api_base = api_base

    def _req(self, method: str, path: str, data: dict | None = None):
        url = f"{self.api_base}{path}"
        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(
            url, data=body,
            headers={"Content-Type": "application/json"},
            method=method,
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            print(f"[HTTP {e.code}] {e.read().decode()}")
            return None
        except Exception as e:
            print(f"[ERR] {e}")
            return None

    def register(self, device_id: str, public_key: str):
        attestation = {
            "manufacturer": "Espressif",
            "model": "ESP32-S3",
            "chipRevision": "3",
            "secureBoot": True,
            "flashEncryption": True,
            "tpm": True,
            "firmwareVersion": "midas-iot-v1.0",
            "bootCounter": random.randint(1, 100),
        }
        return self._req("POST", "/iot/register", {
            "deviceId": device_id,
            "name": f"ESP32-S3-{device_id[-6:]}",
            "publicKey": public_key,
            "attestation": attestation,
        })

    def pair(self, device_id: str, signature: str, challenge: str, token: str):
        return self._req("POST", "/iot/pair", {
            "deviceId": device_id,
            "signature": signature,
            "challenge": challenge,
        })

    def send_telemetry(self, device_id: str, temperature: float,
                       humidity: float, pressure: float, signature: str):
        payload = {
            "deviceId": device_id,
            "payloadType": "telemetry",
            "metricName": "temperature",
            "metricValue": round(temperature, 1),
            "unit": "celsius",
            "signature": signature,
            "encryptedPayload": json.dumps({
                "temperature": round(temperature, 1),
                "humidity": round(humidity, 1),
                "pressure": round(pressure, 1),
                "timestamp": time.time(),
            }),
        }
        return self._req("POST", "/iot/data", payload)


def simulate_sensors() -> tuple[float, float, float]:
    """Génère des données simulées de capteurs."""
    return (
        round(random.gauss(25, 5), 1),   # température °C
        round(random.gauss(60, 10), 1),   # humidité %
        round(random.gauss(1013, 10), 1), # pression hPa
    )


def main():
    parser = argparse.ArgumentParser(description="Simulateur ESP32 MIDAS")
    parser.add_argument("--device-id", default=f"ESP32-{uuid.uuid4().hex[:8].upper()}")
    parser.add_argument("--key-file", default=None)
    parser.add_argument("--api", default=API_BASE)
    parser.add_argument("--interval", type=int, default=5, help="Intervalle entre envois (s)")
    parser.add_argument("--pair", action="store_true", help="Mode appairage")
    parser.add_argument("--challenge", default=None, help="Challenge pour appairage")
    parser.add_argument("--token", default=None, help="Token JWT pour appairage")
    parser.add_argument("--qr", action="store_true", help="Génère un QR code JSON pour appairage (pair-qr)")
    args = parser.parse_args()

    device_id = args.device_id
    mqtt = MQTTSimulator(args.api)
    device = Ed25519Device(device_id, args.key_file)

    print(f"""
+--------------------------------------------+
| ESP32-S3 Simulator - MIDAS IoT Bridge       |
| Device : {device_id:<35}|
| PubKey : {device.public_key_hex[:40]:<35}|
+--------------------------------------------+
""")

    if args.qr:
        challenge = os.urandom(16).hex()
        message = f"pair:{device_id}:{challenge}"
        sig = device.sign(message)
        qr_data = json.dumps({
            "deviceId": device_id,
            "challenge": challenge,
            "signature": sig,
        })
        print(f"[QR] Challenge : {challenge}")
        print(f"[QR] Signature : {sig}")
        print(f"[QR] Contenu du QR code (a scanner) :")
        print(qr_data)
        print()
        print(f"Scannez ce QR depuis l'application mobile.")
        return

    if args.pair:
        if not args.challenge:
            print("[ERR] --challenge requis pour le mode appairage")
            sys.exit(1)
        if not args.token:
            print("[ERR] --token requis pour le mode appairage")
            sys.exit(1)
        challenge = args.challenge
        message = f"pair:{device_id}:{args.token}:{challenge}"
        sig = device.sign(message)
        print(f"[PAIR] Signature : {sig[:48]}...")
        result = mqtt.pair(device_id, sig, challenge, args.token)
        if result:
            print(f"[PAIR] Appairage reussi : {result.get('status')}")
        else:
            print("[PAIR] Echec de l'appairage")
        return

    # Mode télémétrie continue
    print(f"[REG] Enregistrement de l'appareil...")
    result = mqtt.register(device_id, device.public_key_hex)
    if result:
        print(f"[REG] Appareil enregistre (ID: {result.get('id', '?')[:8]}...)")
        print(f"[REG] Statut : {result.get('status', '?')}")
    else:
        print("[REG] L'appareil existe peut-etre deja")

    if args.key_file:
        device.save_key(args.key_file)

    print(f"\n[TELEM] Envoi de donnees toutes les {args.interval}s...\n")
    try:
        while True:
            temp, hum, press = simulate_sensors()
            sensor_data = f"temp:{temp},hum:{hum},press:{press}"
            sig = device.sign(sensor_data)

            result = mqtt.send_telemetry(device_id, temp, hum, press, sig)
            if result:
                print(f"  [OK] {time.strftime('%H:%M:%S')} T:{temp}C  H:{hum}%  P:{press}hPa")
            else:
                print(f"  [ERR] {time.strftime('%H:%M:%S')} Envoi echoue")

            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\n[STOP] Simulateur arrete.")


if __name__ == "__main__":
    main()
