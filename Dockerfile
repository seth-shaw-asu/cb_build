# -------------------------
# Stage 1: builder
# -------------------------
FROM ruby:3.2-slim AS builder

ARG CB_REPO=https://github.com/CollectionBuilder/collectionbuilder-csv.git
ARG CB_BRANCH=main
ARG CB_COMMIT=""

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=Etc/UTC \
    BUNDLE_PATH=/usr/local/bundle

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      git \
      curl \
      ca-certificates \
      libxml2-dev \
      libxslt1-dev \
      libffi-dev \
      libgmp-dev \
      pkg-config \
      xz-utils \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/site

RUN set -eux; \
    if [ -z "${CB_COMMIT:-}" ] || [ "${CB_COMMIT}" = '""' ]; then \
      git clone --depth 1 --branch "${CB_BRANCH}" "${CB_REPO}" /srv/site; \
    else \
      git init /srv/site; \
      cd /srv/site; \
      git remote add origin "${CB_REPO}"; \
      git fetch --depth 1 origin "${CB_COMMIT}"; \
      git checkout FETCH_HEAD; \
    fi; \
    rm -rf /srv/site/.git

# Install bundler
RUN gem install bundler -v 2.4.15

# Install gems
RUN bundle config set --local path "${BUNDLE_PATH}" \
 && bundle install --jobs=4 --retry=3

# -------------------------
# Stage 2: final runtime
# -------------------------
FROM ruby:3.2-slim AS final

ARG INSTALL_AWSCLI="false"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=Etc/UTC \
    BUNDLE_PATH=/usr/local/bundle

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      libxml2 \
      libxslt1.1 \
      libffi-dev \
      libgmp10 \
      imagemagick \
      ghostscript \
      rsync \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/site

# Copy site + gems from builder
COPY --from=builder /srv/site/ /srv/site/
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/srv/overlays", "/srv/project_overrides", "/srv/project_objects", "/srv/output"]

EXPOSE 4000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]