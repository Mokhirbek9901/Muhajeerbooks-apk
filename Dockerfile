FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
RUN flutter create . --platforms=web
RUN flutter pub get
# Wasm gives modern Android Chrome a faster renderer. Flutter also emits the
# JavaScript fallback, so browsers without WasmGC keep working normally.
RUN flutter build web --release --wasm

FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
