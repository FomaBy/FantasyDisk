FROM python:3.12-slim

RUN useradd --create-home --uid 10001 relay
WORKDIR /app
COPY feedback_proxy /app/feedback_proxy
RUN mkdir -p /data && chown relay:relay /data

USER relay
ENV PYTHONUNBUFFERED=1 \
    FEEDBACK_DATABASE_PATH=/data/feedback_proxy.sqlite3 \
    FEEDBACK_LISTEN_HOST=0.0.0.0 \
    FEEDBACK_LISTEN_PORT=8080
EXPOSE 8080
CMD ["python", "-m", "feedback_proxy"]
