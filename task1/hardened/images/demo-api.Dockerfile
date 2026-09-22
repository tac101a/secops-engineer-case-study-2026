FROM python:3.12.12-slim-bookworm@sha256:593bd06efe90efa80dc4eee3948be7c0fde4134606dd40d8dd8dbcade98e669c

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app
COPY --chown=0:0 app.py ./app.py
RUN chmod 0755 /app && chmod 0644 /app/app.py
# The base image already defines numeric nobody:nogroup (65534:65534).
# Root owns the readable application; only the explicit /tmp mount needs writes.
USER 65534:65534
EXPOSE 8080
CMD ["python", "app.py"]
