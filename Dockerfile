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
    mkdir -p /var/lib/rm3l-org && \
    CGO_ENABLED=0 go build -o /var/lib/rm3l-org/server server.go

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
FROM scratch

COPY --from=server-builder /var/lib/rm3l-org/server /var/lib/rm3l-org/
COPY --from=website-builder /code/public /var/lib/rm3l-org/public

ENV PORT="8888"

WORKDIR /var/lib/rm3l-org
CMD [ "./server" ]
