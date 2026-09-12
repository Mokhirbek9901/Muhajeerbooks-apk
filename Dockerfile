FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
RUN flutter create . --platforms=web
RUN flutter pub get
RUN flutter build web --release

FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
