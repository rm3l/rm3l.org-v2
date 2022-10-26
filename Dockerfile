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

RUN bash -c "source $HOME/.asdf/asdf.sh && \
    asdf plugin add hugo && \
    asdf plugin add odo && \
    asdf install && \
    hugo --minify"

# Main image
FROM nginx:1.23.2-alpine

COPY --from=builder /code/public /usr/share/nginx/html
