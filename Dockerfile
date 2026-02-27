# -------------------------
# Stage 1: builder
# -------------------------
FROM ruby:3.2-slim AS builder

ARG CB_REPO=https://github.com/CollectionBuilder/collectionbuilder-sheets.git
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

RUN gem install bundler -v "$( (bundle _2.4.15_ --version 2>/dev/null) || echo '2.4.15' )" || true

# Install gems if Gemfile present
RUN if [ -f "Gemfile" ]; then \
      bundle config set --local path "${BUNDLE_PATH}" && \
      bundle install --jobs=4 --retry=3 ; \
    fi

# -------------------------
# Stage 2: final runtime
# -------------------------
FROM ruby:3.2-slim AS final

ARG INSTALL_AWSCLI="false"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=Etc/UTC \
    BUNDLE_PATH=/usr/local/bundle

# runtime libs + imagemagick & ghostscript for derivative generation
# use libffi-dev (generic) so we don't pin a specific libffi version
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      libxml2 \
      libxslt1.1 \
      libffi-dev \
      libgmp10 \
      imagemagick \
      ghostscript \
 && rm -rf /var/lib/apt/lists/*

# Optional awscli install (disabled by default to keep image small)
RUN if [ "${INSTALL_AWSCLI}" = "true" ]; then \
      apt-get update && apt-get install -y --no-install-recommends unzip groff less && rm -rf /var/lib/apt/lists/* && \
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && \
      unzip /tmp/awscliv2.zip -d /tmp/ && /tmp/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update && \
      rm -rf /tmp/aws* /tmp/awscliv2.zip ; \
    fi

WORKDIR /srv/site

# copy site and gems from builder
COPY --from=builder /srv/site/ /srv/site/
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

# copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/srv/overlays", "/srv/project_overrides", "/srv/project_objects", "/srv/output"]

EXPOSE 4000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]