CollectionBuilder Docker Build System
=======================================

This repository provides a reproducible, containerized build system for **CollectionBuilder**, supporting both:

* `collectionbuilder-sheets`
* `collectionbuilder-gh`

The container is intentionally minimal and metadata-agnostic.
It does **not** inspect, validate, or download metadata files.
CollectionBuilder itself handles all metadata loading and processing.

---

# Design Goals

* Reproducible builds
* Optional commit pinning
* Slim runtime image
* Clean theme/project separation
* Host-side S3 deployment
* Built-in derivative generation support

---

# Versioning Strategy

CollectionBuilder does not publish tagged releases.

This build system supports:

| Mode          | Behavior                      | Reproducible |
| ------------- | ----------------------------- | ------------ |
| Default       | Clone `main` branch           | ❌ No         |
| Commit pinned | Fetch specific Git commit SHA | ✅ Yes        |

For production or CI, you should use `CB_COMMIT`.

---

# Architecture Overview

## Image Layer (Immutable)

The Docker image:

* Clones CollectionBuilder (branch or commit)
* Installs Ruby gems
* Includes:
  * ImageMagick
  * Ghostscript
* (Optionally) AWS CLI

---

## Runtime Mounts

At runtime, the container mounts:

| Host Location       | Container Path           | Purpose                             |
| ------------------- | ------------------------ | ----------------------------------- |
| Current directory   | `/srv/overlays`          | Theme/layout overrides              |
| `project/overrides` | `/srv/project_overrides` | Project config overrides            |
| `project/objects`   | `/srv/project_objects`   | CollectionBuilder objects directory |
| Output directory    | `/srv/output`            | Generated site                      |

The container:

1. Applies overlays
2. Symlinks `objects/`
3. Runs `bundle install`
4. Runs `bundle exec jekyll build`

---

# Repository Structure

## Theme / Build Repository (this repo)

```
.
├── Dockerfile
├── entrypoint.sh
├── run-cb.sh
├── _layouts/
├── _includes/
├── assets/
└── README.md
```

Run `run-cb.sh` from this directory.

---

## Project Repository

```
my-project/
├── overrides/
│   └── _config.yml
└── objects/
    ├── metadata.csv
    ├── image1.jpg
    └── ...
```

Metadata configuration must follow official CollectionBuilder documentation:

* `metadata-csv` (Sheets template)
* `metadata` (GH/CSV template)

Official documentation:
[https://collectionbuilder.github.io/cb-docs/docs/config/collection/](https://collectionbuilder.github.io/cb-docs/docs/config/collection/)

---

# Building the Docker Image

## Default (clone main branch)

```bash
docker build -t collectionbuilder:latest .
```

---

## Pin to a Specific Commit (Recommended for CI)

```bash
docker build \
  --build-arg CB_COMMIT=<full-commit-sha> \
  -t collectionbuilder:sha-<shortsha> .
```

---

# Running Builds

## Local Build

```bash
./run-cb.sh ../my-project ./out
```

---

## Use Specific Image

```bash
./run-cb.sh ../my-project ./out \
  --image collectionbuilder:sha-3f2a6e8
```

---

## Build and Deploy to S3 (Host-Side)

AWS CLI must be installed on the host.

```bash
./run-cb.sh ../my-project ./out \
  --s3 s3://my-bucket/site1
```

S3 sync happens outside the container.

---

# Generate Derivatives

CollectionBuilder provides a rake task:

```
bundle exec rake generate_derivatives
```

Official docs:
[https://collectionbuilder.github.io/cb-docs/docs/objects/derivatives/#generate-derivatives-rake-task](https://collectionbuilder.github.io/cb-docs/docs/objects/derivatives/#generate-derivatives-rake-task)

The Docker image includes:

* ImageMagick
* Ghostscript

To generate derivatives and then build:

```bash
./run-cb.sh ../my-project ./out --derivatives
```

What happens:

1. Runs `bundle exec rake generate_derivatives`
2. Writes derivatives into `project/objects/`
3. Runs the site build
4. Outputs to `./out`

---

# Derivatives Only (Manual Invocation)

If you only want derivatives:

```bash
docker run --rm \
  -v "$(pwd)":/srv/overlays:ro \
  -v "../my-project/overrides":/srv/project_overrides:ro \
  -v "../my-project/objects":/srv/project_objects:rw \
  -w /srv/site \
  collectionbuilder:latest \
  bundle exec rake generate_derivatives
```

---

# Security & Minimalism

The image:

* Uses multi-stage build
* Removes build dependencies from runtime
* Does not include git in final image
* Does not include AWS CLI by default
* Does not pass AWS credentials into container

You may enable AWS CLI with:

```bash
docker build --build-arg INSTALL_AWSCLI=true -t collectionbuilder:latest .
```

But host-side sync is recommended.

---

# Production Recommendations

For CI:

1. Pin to a commit SHA
2. Tag image with short SHA
3. Push to registry
4. Reference immutable tag in CI pipeline

Example:

```bash
docker build --build-arg CB_COMMIT=<sha> -t collectionbuilder:sheets-<shortsha> .
docker push collectionbuilder:sheets-<shortsha>
```
