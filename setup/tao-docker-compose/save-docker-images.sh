#!/usr/bin/env bash
# TAO Docker Image Saver (bundled, JSON manifest, no meta files)
# - Saves each image as .tar in OUTPUT_DIR
# - Writes OUTPUT_DIR/manifest.json mapping tar -> exact image ref
# - Creates one .tar.gz bundle containing OUTPUT_DIR contents (tars + manifest.json)

# ---------- Safe reversible filename helpers ----------
sanitize_component() { sed -E 's/[^A-Za-z0-9._-]+/-/g' <<<"$1"; }

encode_image_ref() {
  # Input ref: registry/path1/path2/name[:tag]  OR  registry/...@sha256:HEX
  local ref="$1"
  local registry="${ref%%/*}"
  local rest="${ref#*/}"
  if [[ "$ref" == "$rest" ]]; then registry="docker.io"; rest="$ref"; fi

  if [[ "$rest" == *"@sha256:"* ]]; then
    local repo="${rest%@sha256:*}"; repo="${repo%/}"
    local hex="${rest#*@sha256:}"
    IFS='/' read -r -a segs <<<"$repo"
    local encoded; encoded="$(sanitize_component "$registry")"
    for s in "${segs[@]}"; do encoded+="__$(sanitize_component "$s")"; done
    echo "${encoded}__d-sha256-$(sanitize_component "$hex")"
    return
  fi

  local repo tag=""
  if [[ "${rest#*/}" == *:* ]]; then
    repo="${rest%:*}"; tag="${rest##*:}"
  else
    repo="$rest"
  fi

  IFS='/' read -r -a segs <<<"$repo"
  local encoded; encoded="$(sanitize_component "$registry")"
  for s in "${segs[@]}"; do encoded+="__$(sanitize_component "$s")"; done

  if [[ -z "$tag" ]]; then
    if docker image inspect "$ref" >/dev/null 2>&1; then
      local first_tag
      first_tag="$(docker image inspect "$ref" --format '{{(index .RepoTags 0)}}' 2>/dev/null || true)"
      [[ -n "$first_tag" && "$first_tag" == *:* ]] && tag="${first_tag##*:}" || tag="latest"
    else
      tag="latest"
    fi
  fi
  echo "${encoded}__t-$(sanitize_component "$tag")"
}

# ---------- Usage ----------
show_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --config=FILE        Config file (default: config.env)
  --output-dir=DIR     Staging folder for per-image .tar (default: ./saved-docker-images)
  --bundle=FILE        Final bundle .tar.gz (default: ./saved-docker-images-bundle.tar.gz)
  --pull               Pull all images (default: auto pull missing)
  --no-pull            Do not pull (only save local)
  --force              Overwrite existing .tar files
  --help               Show help
EOF
}

# ---------- Defaults ----------
CONFIG_FILE="config.env"
OUTPUT_DIR="./saved-docker-images"
PULL_IMAGES="auto"  # auto | force | never
FORCE_SAVE=false

# ---------- Parse args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config=*)     CONFIG_FILE="${1#*=}"; shift ;;
    --output-dir=*) OUTPUT_DIR="${1#*=}"; shift ;;
    --pull)         PULL_IMAGES="force"; shift ;;
    --no-pull)      PULL_IMAGES="never"; shift ;;
    --force)        FORCE_SAVE=true; shift ;;
    -h|--help)      show_usage; exit 0 ;;
    *) echo "Unknown option: $1"; show_usage; exit 1 ;;
  esac
done

# ---------- Preflight ----------
[[ -f "$CONFIG_FILE" ]] || { echo "Error: Config '$CONFIG_FILE' not found"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Error: docker not in PATH"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Error: Docker daemon not running"; exit 1; }

echo "TAO Docker Image Saver (Bundled, JSON manifest, no meta files)"
echo "=============================================================="
echo "Config:      $CONFIG_FILE"
echo "Output dir:  $OUTPUT_DIR"
echo "Pull mode:   $PULL_IMAGES"
echo "Force save:  $FORCE_SAVE"
echo ""

mkdir -p "$OUTPUT_DIR"

echo "Loading $CONFIG_FILE ..."
set -a
# shellcheck disable=SC1090
source "$CONFIG_FILE"
set +a

TAO_IMAGES=( "IMAGE_TAO_API" "IMAGE_TAO_PYTORCH" "IMAGE_TAO_DEPLOY" "IMAGE_VILA" "IMAGE_TAO_DS" )

available=()
for v in "${TAO_IMAGES[@]}"; do
  [[ -n "${!v-}" ]] && available+=("${!v}")
done

echo "Images to process (${#available[@]}):"
printf '  %s\n' "${available[@]}"
echo ""

saved_count=0 skipped_count=0 failed_count=0 processed=0

# Start JSON manifest
manifest_json="$OUTPUT_DIR/manifest.json"
echo "[" > "$manifest_json"
first_entry=true

for image_ref in "${available[@]}"; do
  ((processed++))
  echo "[$processed/${#available[@]}] $image_ref"

  local_exists=false
  if docker image inspect "$image_ref" >/dev/null 2>&1; then
    local_exists=true; echo "  Status: Found locally"
  else
    echo "  Status: Not local"
  fi

  should_pull=false
  case "$PULL_IMAGES" in
    force) should_pull=true ;;
    auto)  [[ $local_exists == false ]] && should_pull=true ;;
    never) ;;
  esac

  if $should_pull; then
    echo "  Pulling..."
    if ! docker pull "$image_ref"; then
      echo "  Pull failed"; ((failed_count++)); echo ""; continue
    fi
    local_exists=true
  fi

  if [[ $local_exists == false ]]; then
    echo "  Skipping (not local, pull disabled)"; ((skipped_count++)); echo ""; continue
  fi

  base="$(encode_image_ref "$image_ref")"
  out_tar="$OUTPUT_DIR/${base}.tar"

  if [[ -f "$out_tar" && $FORCE_SAVE == false ]]; then
    echo "  Exists, skip save: $(basename "$out_tar")"
  else
    echo "  Saving -> $out_tar"
    if ! docker save -o "$out_tar" "$image_ref"; then
      echo "  Save failed"; ((failed_count++)); echo ""; continue
    fi
  fi

  # Append to manifest.json
  # Fields: file (tar name), ref (image reference)
  if $first_entry; then first_entry=false; else echo "," >> "$manifest_json"; fi
  printf '  { "file": "%s", "ref": "%s" }' "${base}.tar" "$image_ref" >> "$manifest_json"

  ((saved_count++))
  echo ""
done

# Close JSON manifest
echo "" >> "$manifest_json"
echo "]" >> "$manifest_json"


echo "================================"
echo "Saved:   $saved_count"
echo "Skipped: $skipped_count"
echo "Failed:  $failed_count"
echo "Manifest: $manifest_json"
