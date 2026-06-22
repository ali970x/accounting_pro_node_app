# Stage 1: Build the Flutter Web app
FROM debian:latest AS build-env

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    libgconf-2-4 \
    gdb \
    libstdc++6 \
    libglu1-mesa \
    fonts-droid-fallback \
    python3 \
    && apt-get clean

# Clone Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Enable web and build
RUN flutter doctor
RUN flutter config --enable-web

RUN mkdir /app/
COPY . /app/
WORKDIR /app/

# Build for web (You can add --dart-define here if needed)
RUN flutter build web --release

# Stage 2: Serve using Nginx
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY --from=build-env /app/web/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
