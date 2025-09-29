#!/usr/bin/env bash
# TAO Docker Image Loader
# - Accepts a input directory
# - Uses manifest.json (via jq) to map tar -> image ref
# - Falls back to decoding safe filename if manifest missing
# - Skips docker load if the image already exists (unless --force)


show_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --input-dir=DIR     Directory with .tar files
  --force             Force load even if image exists
  --keep-temp         Keep extracted folder (debug)
  --help              Show help
EOF
}

INPUT_DIR="./saved-docker-images"
FORCE_LOAD=false
KEEP_TEMP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input-dir=*) INPUT_DIR="${1#*=}"; shift ;;
    --force)      FORCE_LOAD=true; shift ;;
    --keep-temp)  KEEP_TEMP=true; shift ;;
    -h|--help)    show_usage; exit 0 ;;
    *) echo "Unknown option: $1"; show_usage; exit 1 ;;
  esac
done

if [[ -z "$INPUT_DIR" ]]; then
  echo "Error: Provide --input-dir"; show_usage; exit 1
fi


command -v docker >/dev/null 2>&1 || { echo "Error: docker not in PATH"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Error: Docker daemon not running"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not found in PATH"; exit 1; }

# ---------- Safe filename decoder (fallback) ----------
strip_ext_all() {
  local n="$1"; n="${n%.tar.gz}"; n="${n%.tgz}"; n="${n%.tar}"; printf '%s' "$n"
}
decode_image_ref_from_base() {
  local base="$1" IFS=$'\n'
  read -r -d '' -a parts < <(printf '%s' "${base//__/\\n}"; printf '\0')
  local n=${#parts[@]}
  (( n >= 3 )) || { echo "ERROR: bad filename base '$base'" >&2; return 1; }
  local registry="${parts[0]}" suffix="${parts[n-1]}"
  local repo_segments=("${parts[@]:1:n-2}")
  local repo_path; (IFS=/; repo_path="${repo_segments[*]}")
  [[ -n "$repo_path" ]] || { echo "ERROR: missing repo in '$base'" >&2; return 1; }
  if [[ "$suffix" == t-* ]]; then
    echo "${registry}/${repo_path}:${suffix#t-}"
  elif [[ "$suffix" == d-sha256-* ]]; then
    echo "${registry}/${repo_path}@sha256:${suffix#d-sha256-}"
  else
    echo "ERROR: bad suffix in '$base'" >&2; return 1
  fi
}
already_present() { docker image inspect "$1" >/dev/null 2>&1; }

# ---------- Prepare working dir ----------
TEMP_DIR=""
WORK_DIR=""
if [[ -d "$INPUT_DIR" ]]; then
  WORK_DIR="$INPUT_DIR"
else
  echo "Error: Input dir '$INPUT_DIR' not found"
  exit 1
fi

MANIFEST_JSON="$WORK_DIR/manifest.json"
have_manifest=false
[[ -f "$MANIFEST_JSON" ]] && have_manifest=true

# ---------- Build a map file->ref using jq if manifest exists ----------
declare -A REF_BY_FILE
if $have_manifest; then
  # Manifest is an array of { file, ref }
  while IFS=$'\t' read -r f r; do
    REF_BY_FILE["$f"]="$r"
  done < <(jq -r '.[] | [.file, .ref] | @tsv' "$MANIFEST_JSON")
fi

# ---------- Find image tar files ----------
# shellcheck disable=SC2207
files=($(find "$WORK_DIR" -maxdepth 1 -type f \( -name '*.tar' -o -name '*.tar.gz' -o -name '*.tgz' \) | sort))
(( ${#files[@]} > 0 )) || { echo "No image tar files found in $WORK_DIR"; exit 0; }

echo "Found ${#files[@]} image files:"
for f in "${files[@]}"; do echo "  $(basename "$f")"; done
echo ""

loaded=0 skipped=0 failed=0

for f in "${files[@]}"; do
  name="$(basename "$f")"
  base="$(strip_ext_all "$name")"

  echo "Processing: $name"

  image_ref=""
  if $have_manifest && [[ -n "${REF_BY_FILE[$name]-}" ]]; then
    image_ref="${REF_BY_FILE[$name]}"
  else
    # Fallback: decode from safe filename
    if ! image_ref="$(decode_image_ref_from_base "$base")"; then
      echo "  ✗ Could not determine image reference"; ((failed++)); echo ""; continue
    fi
  fi

  echo "  Target ref: $image_ref"

  if ! $FORCE_LOAD && already_present "$image_ref"; then
    echo "  ✓ Already present, skipping"
    ((skipped++)); echo ""; continue
  fi

  echo "  Loading..."
  if [[ "$f" =~ \.tar\.gz$ || "$f" =~ \.tgz$ ]]; then
    if gzip -dc -- "$f" | docker load; then
      echo "  ✓ Loaded (compressed)"; ((loaded++))
    else
      echo "  ✗ Load failed"; ((failed++))
    fi
  else
    if docker load -i "$f"; then
      echo "  ✓ Loaded (tar)"; ((loaded++))
    else
      echo "  ✗ Load failed"; ((failed++))
    fi
  fi
  echo ""
done

echo "================================================"
echo "Loading complete"
echo "Loaded:  $loaded"
echo "Skipped: $skipped"
echo "Failed:  $failed"
[[ -n "$TEMP_DIR" && "$KEEP_TEMP" == true ]] && echo "Kept temp: $TEMP_DIR"
