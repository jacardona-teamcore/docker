FROM python:3.9-slim

WORKDIR /tc4
WORKDIR /opentelemetry

# Variables OpenTelemetry
ENV OTEL_SERVICE_NAME="OTELCOL"
ENV OTEL_RESOURCE_ATTRIBUTES=service.instance.id=otelcol
ENV OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED=true
ENV OTEL_ENVER_OTLP_ENDPOINT=https://otlp.nr-data.net
ENV OTEL_ENVER_OTLP_HEADERS=KEY
ENV OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT=4095
ENV OTEL_ENVER_OTLP_COMPRESSION=gzip
ENV OTEL_ENVER_OTLP_PROTOCOL=http/protobuf 
ENV OTEL_ENVER_OTLP_METRICS_TEMPORALITY_PREFERENCE=delta

# Install depency and opentelemtry
COPY ./app/requirements.txt /tc4/requirements.txt
COPY ./opentelemetry/requirements.txt /opentelemetry/requirements.txt
COPY main.py /tc4/main.py

RUN pip install --no-cache-dir --upgrade -r /tc4/requirements.txt
RUN pip install --no-cache-dir -r /opentelemetry/requirements.txt
RUN opentelemetry-bootstrap -a install

EXPOSE 8080
EXPOSE 4317/tcp
EXPOSE 4318/tcp

CMD ["/bin/sh", "-c", "opentelemetry-instrument --logs_exporter otlp  uvicorn main:app --reload --port 8080"]