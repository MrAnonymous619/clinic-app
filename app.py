"""Clinic Appointment Booking - small Flask service for the DevOps capstone.

Endpoints
  /              web page (static/index.html): book, search and cancel appointments
  /appointments  GET list, POST book (JSON); DELETE /appointments/<id> cancels
  /health        liveness/readiness check used by Kubernetes
  /metrics       Prometheus metrics (request count, latency, bookings)
  /work          deliberately CPU-heavy endpoint used for the HPA load test
  /version       JSON with version and pod name
Data is kept in memory (no database), so each pod has its own list.
"""
import itertools
import math
import socket
import time

from flask import Flask, jsonify, request, send_from_directory
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

app = Flask(__name__)

# Change this text (v1 -> v2) for the "fresh code push" in the live demo.
VERSION = "v2"
POD = socket.gethostname()  # inside Kubernetes this is the pod name
appointments = []
id_counter = itertools.count(1)

# ---- Prometheus metrics ----
REQUESTS = Counter("clinic_http_requests_total", "Total HTTP requests", ["method", "endpoint"])
LATENCY = Histogram("clinic_request_latency_seconds", "Request latency in seconds", ["endpoint"])
BOOKINGS = Counter("clinic_appointments_booked_total", "Appointments booked")


@app.before_request
def start_timer():
    request.start_time = time.time()


@app.after_request
def record_metrics(resp):
    REQUESTS.labels(request.method, request.path).inc()
    LATENCY.labels(request.path).observe(time.time() - request.start_time)
    return resp


@app.route("/")
def home():
    # The user interface is a single HTML file: static/index.html
    return send_from_directory(app.static_folder, "index.html")


@app.route("/version")
def version():
    return jsonify(app="Clinic Appointments", version=VERSION, pod=POD)


@app.route("/appointments", methods=["GET"])
def list_appointments():
    return jsonify(appointments)


@app.route("/appointments", methods=["POST"])
def book():
    data = request.get_json(force=True)
    if not data.get("patient") or not data.get("doctor") or not data.get("time"):
        return jsonify(error="patient, doctor and time are required"), 400
    appt = {
        "id": next(id_counter),
        "patient": data["patient"],
        "doctor": data["doctor"],
        "time": data["time"],
    }
    appointments.append(appt)
    BOOKINGS.inc()
    return jsonify(appt), 201


@app.route("/appointments/<int:appt_id>", methods=["DELETE"])
def cancel(appt_id):
    for appt in appointments:
        if appt["id"] == appt_id:
            appointments.remove(appt)
            return jsonify(status="cancelled", id=appt_id)
    return jsonify(error="not found"), 404


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/work")
def work():
    # Burns CPU on purpose so the HPA has something to react to.
    total = 0.0
    for i in range(2000000):
        total += math.sqrt(i)
    return jsonify(result=total, pod=POD)


@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
