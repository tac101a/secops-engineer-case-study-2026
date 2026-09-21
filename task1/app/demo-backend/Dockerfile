FROM python:3.12.12-slim-bookworm@sha256:593bd06efe90efa80dc4eee3948be7c0fde4134606dd40d8dd8dbcade98e669c

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app
COPY app.py ./app.py
# Deliberately permissive Phase B condition; the application does not need root.
USER 0
EXPOSE 8081
CMD ["python", "app.py"]
