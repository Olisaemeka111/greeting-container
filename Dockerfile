FROM python:3.12@sha256:4d1caded1f729ae443eb803f26ffde7b61e696aeaef62f099abb6dd6b14257c7

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
