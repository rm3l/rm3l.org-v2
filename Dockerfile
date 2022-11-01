# Builder
FROM debian:stable-slim AS builder

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

RUN bash -c "source $HOME/.asdf/asdf.sh && \
    asdf plugin add hugo && \
    asdf install hugo $(grep hugo /code/.tool-versions | awk '{print $2}') && \
    hugo --minify --baseURL=$BASE_URL"

# Main image
FROM nginx:1.23.2-alpine

COPY .docker/expires.inc /etc/nginx/conf.d/expires.inc
RUN chmod 0644 /etc/nginx/conf.d/expires.inc && \
    sed -i '9i\        include /etc/nginx/conf.d/expires.inc;\n' /etc/nginx/conf.d/default.conf

ARG WEBSITE_PATH="/"

RUN mkdir -p "/tmp${WEBSITE_PATH}"
COPY --from=builder /code/public /tmp/website_data

RUN mkdir -p "/usr/share/nginx/html${WEBSITE_PATH}" && \
    mv /tmp/website_data/* "/usr/share/nginx/html${WEBSITE_PATH}/" && \
    rm -rf /tmp/website_data

WORKDIR /usr/share/nginx/html${WEBSITE_PATH}

RUN sh -c 'if [ "$WEBSITE_PATH" != "/" ]; then rm -rf /usr/share/nginx/html/*.html; fi'
