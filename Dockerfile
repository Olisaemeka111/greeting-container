FROM python:3.12@sha256:63828510c8b5ccce3bf0d6fabd6f3d17d4effa1ffe690f80a67c8e2d394e03ee

RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    curl \
    vim

WORKDIR /app

COPY . .

RUN pip install -r app/requirements.txt

EXPOSE 8080

# The whole context was copied to /app, so the app package lives in /app/app.
CMD ["gunicorn", "--chdir", "app", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
