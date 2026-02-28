CollectionBuilder Docker Build System
=====================================

This repository provides a reproducible, containerized build system for **CollectionBuilder** using `collectionbuilder-csv`.

The container is intentionally minimal and metadata-agnostic.
It does **not** inspect, validate, or download metadata files.
CollectionBuilder itself handles all metadata loading and processing.

# TODO

- Add code so that the derivative paths are added to the csv file.
- Stop the whole project from showing up in the site build directory.

# Architecture Overview

## Image Layer (Immutable)

The Docker image:

* Clones CollectionBuilder (branch or commit)
* Installs Ruby gems
* Includes:
  * ImageMagick
  * Ghostscript

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

# Repository Structure

## Build Repository (this repo)

```
.
├── Dockerfile
├── entrypoint.sh
├── run-cb.sh
├── example/
├── README.md
└── [optional theme overlays: _layouts/, _includes/, assets/, etc.]
```

Run `run-cb.sh` from this directory. Optional theme customizations can be added directly to the root directory.


## Example Project Repository

The `example/` directory demonstrates the project structure:

```
example/
├── overrides/
│   ├── _config.yml
│   └── _data/
│       ├── metadata.csv
│       └── theme.yml
└── objects/
    ├── 01casc.jpg
    ├── 01land.pdf
    └── [additional collection objects]
```

### Configuration

* `overrides/_config.yml` - Base CollectionBuilder configuration
* `overrides/_data/theme.yml` - Theme-specific settings
* `overrides/_data/metadata.csv` - Collection metadata

Metadata configuration must follow official [CollectionBuilder documentation](https://collectionbuilder.github.io/cb-docs/docs/metadata/csv_metadata/).

# Building the Docker Image

## Default (clone main branch)

```bash
docker build -t collectionbuilder:latest .
```

## Pin to a Specific Commit (Recommended for CI)

CollectionBuilder does not publish tagged releases.

For production or CI, you should use `CB_COMMIT`.

```bash
docker build \
  --build-arg CB_COMMIT=<full-commit-sha> \
  -t collectionbuilder:sha-<shortsha> .
```

# Running Builds

## Local Build

```bash
./run-cb.sh ../my-project ./out
```

## Use Specific Image

```bash
./run-cb.sh ../my-project ./out \
  --image collectionbuilder:sha-3f2a6e8
```

## Build and Deploy to S3 (Host-Side)

AWS CLI must be installed on the host.

```bash
./run-cb.sh ../my-project ./out \
  --s3 s3://my-bucket/site1
```

S3 sync happens outside the container.

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

# Production Recommendations

For CI:

1. Pin to a commit SHA
2. Tag image with short SHA
3. Push to registry
4. Reference immutable tag in CI pipeline

Example:

```bash
docker build --build-arg CB_COMMIT=<sha> -t collectionbuilder:csv-<shortsha> .
docker push collectionbuilder:csv-<shortsha>
```
