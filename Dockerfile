# This build stage uses an official Python image to install dependencies.
# Seperation of build and runtime stages allows for a smaller final image.
# Updated sha to use the latest Python 3.12 slim image.
FROM python:3.12-slim@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1 AS builder

# Removed apt-get update and install commands since the slim image already has the necessary build tools for Python packages.
# Installing curl, vim create security vulnerabilities and is not needed for this build process.

WORKDIR /

# Copy only the required files in this build stage.
COPY app/requirements.txt requirements.txt

# Install dependencies into /deps so they can be copied to the runtime image.
# The --no-cache-dir option prevents pip from caching the downloaded packages, which reduces the size of the final image.
RUN pip install --no-cache-dir --target=/deps -r requirements.txt

FROM python:3.12-slim@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1 AS runtime

LABEL org.opencontainers.image.source="https://github.com/benfielding74/greeting-container" \
      org.opencontainers.image.title="sample-app" \
      org.opencontainers.image.description="DWP assessment production container changes." \
      org.opencontainers.image.version="1.0.3" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

# Use a non-root user to run the application for better security.
USER 1000:1000

# Copy the dependencies from the builder stage to the runtime image.
COPY --chown=1000:000 --from=builder /deps /usr/local/lib/python3.12/site-packages

COPY --chown=1000:1000 --from=builder /deps/bin /usr/local/bin

# Copy only the application code to the runtime image.
COPY --chown=1000:1000 app app

EXPOSE 8080

# Production container health check to ensure the application is running and responding to requests.
# This checks the /healthz endpoint returns a 200 status code.
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/python3", "-c", "import urllib.request; response=urllib.request.urlopen('http://localhost:8080/healthz'); assert response.code == 200"]

# The whole context was copied to /app, so the app package lives in /app/app.
CMD ["gunicorn", "--chdir", "app", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
