#!/usr/bin/env bash
set -euo pipefail

# Netlify build for this Godot 4 Web project.
# The game source is not modified. Netlify downloads the exact Godot version
# used by the project, installs the official Web export template, and exports
# into ./web.

VERSION="${GODOT_VERSION:-4.7.2}"
BASE_URL="https://downloads.godotengine.org/?flavor=stable&platform=linux.x86_64&slug=linux.x86_64.zip&version=${VERSION}"
TEMPLATE_URL="https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=${VERSION}"

CACHE_DIR="${NETLIFY_CACHE_DIR:-.netlify-cache}"
ENGINE_DIR="${CACHE_DIR}/godot-${VERSION}"
ENGINE_ZIP="${CACHE_DIR}/Godot_${VERSION}_linux.zip"
TEMPLATE_TPZ="${CACHE_DIR}/Godot_${VERSION}_templates.tpz"
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${VERSION}.stable"

mkdir -p "${CACHE_DIR}" "${ENGINE_DIR}" "${TEMPLATE_DIR}" web

if [ ! -x "${ENGINE_DIR}/godot" ]; then
  echo "Downloading official Godot ${VERSION} stable editor..."
  rm -f "${ENGINE_ZIP}"
  curl -fL --retry 4 --retry-delay 2 "${BASE_URL}" -o "${ENGINE_ZIP}"
  rm -rf "${ENGINE_DIR}"
  mkdir -p "${ENGINE_DIR}"
  unzip -q "${ENGINE_ZIP}" -d "${ENGINE_DIR}/unpacked"
  GODOT_BIN="$(find "${ENGINE_DIR}/unpacked" -type f -name 'Godot_v*_linux.x86_64' | head -n 1)"
  if [ -z "${GODOT_BIN}" ]; then
    echo "ERROR: Godot Linux executable was not found."
    exit 1
  fi
  cp "${GODOT_BIN}" "${ENGINE_DIR}/godot"
  chmod +x "${ENGINE_DIR}/godot"
fi

if [ ! -f "${TEMPLATE_DIR}/web_release.zip" ]; then
  echo "Downloading official Godot ${VERSION} export templates..."
  rm -f "${TEMPLATE_TPZ}"
  curl -fL --retry 4 --retry-delay 2 "${TEMPLATE_URL}" -o "${TEMPLATE_TPZ}"
  TMP_TEMPLATES="${CACHE_DIR}/templates-${VERSION}"
  rm -rf "${TMP_TEMPLATES}"
  mkdir -p "${TMP_TEMPLATES}"
  unzip -q "${TEMPLATE_TPZ}" -d "${TMP_TEMPLATES}"
  WEB_RELEASE="$(find "${TMP_TEMPLATES}" -type f -name 'web_release.zip' | head -n 1)"
  WEB_DEBUG="$(find "${TMP_TEMPLATES}" -type f -name 'web_debug.zip' | head -n 1)"
  if [ -z "${WEB_RELEASE}" ]; then
    echo "ERROR: Godot Web release template was not found."
    exit 1
  fi
  cp "${WEB_RELEASE}" "${TEMPLATE_DIR}/web_release.zip"
  if [ -n "${WEB_DEBUG}" ]; then
    cp "${WEB_DEBUG}" "${TEMPLATE_DIR}/web_debug.zip"
  fi
fi

rm -rf web
mkdir -p web

echo "Exporting Godot project for Web..."
"${ENGINE_DIR}/godot" --headless --path . --import
"${ENGINE_DIR}/godot" --headless --path . --export-release "Web" web/index.html

test -s web/index.html
test -s web/index.pck
test -s web/index.wasm

echo "Web export complete:"
ls -lh web/
