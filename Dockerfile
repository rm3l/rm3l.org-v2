# Builder
FROM debian:stable-slim AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf

# For maximum backward compatibility with Hugo modules
ENV HUGO_ENVIRONMENT=production
ENV HUGO_ENV=production

COPY . /code
WORKDIR /code

ARG BASE_URL="http://127.0.0.1.nio.io/"

RUN source "$HOME/.asdf/asdf.sh" && \
    asdf plugin add hugo && \
    asdf install hugo "$(grep hugo /code/.tool-versions | awk '{print $2}')" && \
    hugo --minify --baseURL="$BASE_URL"

# Main image
FROM cgr.dev/chainguard/nginx:1.23.1

ARG NGINX_HTML_ROOT="/var/lib/nginx/html"

RUN mkdir -p "/tmp"
COPY --from=builder /code/public /tmp/website_data

USER root

RUN mv /tmp/website_data/* "${NGINX_HTML_ROOT}/" && rm -rf /tmp/website_data

USER nginx
