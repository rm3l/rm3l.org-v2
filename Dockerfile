# Server Builder
FROM debian:stable-slim AS server-builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf

COPY . /code
WORKDIR /code

RUN source "$HOME/.asdf/asdf.sh" && \
    asdf plugin add golang && \
    asdf install golang "$(grep golang /code/.tool-versions | awk '{print $2}')" && \
    CGO_ENABLED=0 go build -o ./server server.go

# Website Builder
FROM debian:stable-slim AS website-builder

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
FROM cgr.dev/chainguard/static:latest

COPY --from=server-builder /code/server ./
COPY --from=website-builder /code/public ./public

ENV PORT="8888"

CMD [ "./server" ]
