#!/usr/bin/env bash
# Synth native CLI installer. Release-pinned; no sudo or Gatekeeper changes.
main() {
  set -eu
  SYNTH_VERSION="0.0.1-alpha.31"
  case "$(uname -s)" in
    Darwin) SYNTH_OS="darwin" ;;
    Linux) SYNTH_OS="linux" ;;
    *) echo "Unsupported operating system" >&2; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64) SYNTH_ARCH="amd64" ;;
    aarch64|arm64) SYNTH_ARCH="arm64" ;;
    *) echo "Unsupported architecture" >&2; exit 1 ;;
  esac
  mkdir -p "$HOME/.cache/synth"
  SYNTH_TMP=$(mktemp -d "$HOME/.cache/synth/install.XXXXXX")
  SYNTH_STAGE=""
  trap 'rm -rf "$SYNTH_TMP"; if [ -n "$SYNTH_STAGE" ]; then rm -f "$SYNTH_STAGE"; fi' EXIT
  cd "$SYNTH_TMP"
  RELEASE_BASE="https://github.com/SynthLabsAI/synth-releases/releases/download/v${SYNTH_VERSION}"
  ARCHIVE="synth_${SYNTH_VERSION}_${SYNTH_OS}_${SYNTH_ARCH}.tar.gz"
  curl -fsSLO "${RELEASE_BASE}/${ARCHIVE}"
  curl -fsSLO "${RELEASE_BASE}/checksums.txt"
  awk -v asset="$ARCHIVE" '$2 == asset { print }' checksums.txt > asset.checksum
  test -s asset.checksum
  if [ "$SYNTH_OS" = darwin ]; then
    shasum -a 256 --check asset.checksum
  else
    sha256sum --check asset.checksum
  fi
  tar -xzf "$ARCHIVE"
  mkdir -p "$HOME/.local/bin"
  test ! -d "$HOME/.local/bin/synth"
  SYNTH_STAGE=$(mktemp "$HOME/.local/bin/.synth-install.XXXXXX")
  install -m 0755 synth "$SYNTH_STAGE"
  SYNTH_INSTALLED_VERSION=$("$SYNTH_STAGE" version)
  if [ "$SYNTH_INSTALLED_VERSION" != "synth $SYNTH_VERSION" ]; then
    echo "Downloaded binary reports an unexpected version" >&2
    exit 1
  fi
  mv -f "$SYNTH_STAGE" "$HOME/.local/bin/synth"
  printf '%s\n' "$SYNTH_INSTALLED_VERSION"
  # The caller may have cached an older binary, invisible to this subprocess.
  # Assigning PATH also clears that shell's command cache.
  # shellcheck disable=SC2016
  printf '\nTo use Synth in this terminal, run:\n  export PATH="$HOME/.local/bin:$PATH"\n'
}

main "$@"
