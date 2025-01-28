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


# Instala el OpenTelemetry Collector
RUN wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.74.0/otelcol_0.74.0_linux_amd64.tar.gz && \
    tar -xvf otelcol_0.74.0_linux_amd64.tar.gz && \
    mv otelcol /usr/local/bin/
COPY /opentelemetry/config.yaml /etc/otelcol-config.yaml

RUN pip install --no-cache-dir --upgrade -r /tc4/requirements.txt
RUN pip install --no-cache-dir -r /opentelemetry/requirements.txt
RUN opentelemetry-bootstrap -a install

EXPOSE 8080
EXPOSE 4317/tcp
EXPOSE 4318/tcp

CMD ["/bin/sh", "-c", "otelcol --config=/etc/otelcol-config.yaml & opentelemetry-instrument python /tc4/main.py"]