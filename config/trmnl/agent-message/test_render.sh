#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_dir="$project_dir/_build"

command -v magick >/dev/null 2>&1 || {
  printf '%s\n' 'missing magick; run this test from nix develop .#display-devices' >&2
  exit 1
}

assert_non_background_pixels() {
  local image_path="$1"
  local x="$2"
  local y="$3"
  local width="$4"
  local height="$5"
  local minimum="$6"
  local label="$7"
  local body_pixels

  test -s "$image_path"
  body_pixels="$(magick "$image_path" -crop "${width}x${height}+${x}+${y}" -colorspace Gray -threshold 1% -format '%[fx:(1-mean)*w*h]' info: 2>/dev/null)"
  awk -v pixels="$body_pixels" -v minimum="$minimum" 'BEGIN { exit !(pixels >= minimum) }' || {
    printf '%s\n' "$label render has $body_pixels non-background pixels; expected at least $minimum" >&2
    exit 1
  }
}

assert_dimensions() {
  local image_path="$1"
  local width="$2"
  local height="$3"
  local label="$4"
  local dimensions

  dimensions="$(magick identify -format '%wx%h' "$image_path")"
  test "$dimensions" = "${width}x${height}" || {
    printf '%s render has dimensions %s, expected %sx%s\n' "$label" "$dimensions" "$width" "$height" >&2
    exit 1
  }
}

assert_model_renders() {
  local model="$1"
  local output_width="$2"
  local output_height="$3"
  local canvas_width=800
  local body_height
  local view
  local image_path

  # trmnlp's --width/--height set the screenshot viewport. The default
  # preview screen remains 800x480, so keep X assertions inside that canvas
  # instead of counting the surrounding viewport background.
  for view in full half_horizontal half_vertical quadrant; do
    image_path="$build_dir/$view.png"
    assert_dimensions "$image_path" "$output_width" "$output_height" "$model/$view"
    case "$view" in
      full|half_vertical) body_height=420 ;;
      half_horizontal|quadrant) body_height=190 ;;
    esac
    assert_non_background_pixels "$image_path" 0 0 "$canvas_width" "$body_height" 500 "$model/$view body"
  done

  # These independent crops caught the original regression: the body HTML
  # contained values, but collapsed flex children were clipped to width 0.
  assert_non_background_pixels "$build_dir/full.png" 250 50 300 140 500 "$model/full headline-status"
  assert_non_background_pixels "$build_dir/full.png" 200 260 400 120 500 "$model/full message-progress"
}

cd "$project_dir"
"$BASH" ./bin/trmnlp build --png --width 800 --height 480 --color-depth 1 --quiet
assert_model_renders og 800 480

"$BASH" ./bin/trmnlp build --png --width 1040 --height 780 --color-depth 4 --quiet
assert_model_renders trmnl-x 1040 780

printf '%s\n' 'TRMNLP OG/X render checks passed'
