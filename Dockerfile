FROM ghcr.io/cirruslabs/flutter:stable@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS build
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release

FROM nginx:alpine
RUN apk add --no-cache python3 py3-pip supervisor && pip3 install --break-system-packages --no-cache-dir flask gunicorn requests pywebpush
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
COPY server /app/server
COPY supervisord.conf /etc/supervisord.conf
RUN nginx -t
EXPOSE 8080
CMD ["supervisord", "-c", "/etc/supervisord.conf"]
