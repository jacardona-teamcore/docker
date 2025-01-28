FROM python:3.9-slim

WORKDIR /tc4
WORKDIR /opentelemetry

# Variables OpenTelemetry
ARG COLLECTOR_HOST
ARG COLLECTOR_PORT

ENV OTEL_EXPORTER_OTLP_ENDPOINT="https://googleapis.com/monitoring/v3"
ENV OTEL_RESOURCE_ATTRIBUTES="service.name=otelcol-test,service.version=1.0"
ENV OTEL_SERVICE_NAME="otelcol-test"

# Install depency and opentelemtry
COPY ./app/requirements.txt /tc4/requirements.txt
COPY ./opentelemetry/requirements.txt /opentelemetry/requirements.txt
COPY main.py /tc4/main.py

RUN pip install --no-cache-dir --upgrade -r /tc4/requirements.txt
RUN pip install --no-cache-dir /opentelemetry/requirements.txt

EXPOSE 8080

CMD ["opentelemetry-instrument", "python", "/tc4/main.py"]
