from flask import Flask
from opentelemetry.instrumentation.flask import FlaskInstrumentor

# Inicializar la configuración de OpenTelemetry
import otel_config

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

@app.route("/")
def index():
    return "¡Hola desde una app instrumentada con OpenTelemetry!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)