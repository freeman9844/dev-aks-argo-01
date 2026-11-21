FROM python:3.12-slim
WORKDIR /app
COPY app/server.py app/VERSION ./
ARG SOURCE_COMMIT
RUN test -n "$SOURCE_COMMIT" && printf '%s\n' "$SOURCE_COMMIT" > COMMIT
USER 65532:65532
EXPOSE 8080
CMD ["python", "server.py"]
