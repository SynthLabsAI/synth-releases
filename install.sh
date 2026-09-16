#!/usr/bin/env bash
# Synth native CLI installer. Release-pinned; no sudo or Gatekeeper changes.
configure_path() {
  local shell_name="${SHELL:-}" profile login_profile zsh_dir
  local profiles=()
  case "${shell_name##*/}" in
    bash)
      profiles=("$HOME/.bashrc")
      login_profile="$HOME/.bash_profile"
      for profile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
        if [ -e "$profile" ] || [ -L "$profile" ]; then
          login_profile="$profile"
          break
        fi
      done
      profiles+=("$login_profile")
      ;;
    zsh)
      # zsh reads .zshenv even for noninteractive shells; it may set ZDOTDIR.
      # shellcheck disable=SC2016
      zsh_dir=$(cd "$SYNTH_START_DIR" && "$shell_name" -c 'printf "%s" "${ZDOTDIR:-$HOME}"') || return 1
      case "$zsh_dir" in /*) ;; *) zsh_dir="$SYNTH_START_DIR/$zsh_dir" ;; esac
      [ -d "$zsh_dir" ] || return 1
      profiles=("$zsh_dir/.zshrc")
      ;;
    *) return 1 ;;
  esac
  # Do not replace files or source interactive startup scripts.
  for profile in "${profiles[@]}"; do
    if [ -e "$profile" ] || [ -L "$profile" ]; then
      [ -f "$profile" ] && [ -r "$profile" ] && [ -w "$profile" ] || return 1
    fi
  done
  for profile in "${profiles[@]}"; do
    # shellcheck disable=SC2016
    if ! grep -Fqx 'export PATH="$HOME/.local/bin:$PATH"' "$profile" 2>/dev/null; then
      # shellcheck disable=SC2016
      printf '\n# Added by Synth\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$profile" || return 1
    fi
    printf 'Shell setup: %s\n' "$profile"
  done
}

main() {
  set -eu
  SYNTH_START_DIR=$PWD
  SYNTH_MODIFY_PATH=1
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --no-modify-path) SYNTH_MODIFY_PATH=0 ;;
      --help|-h) echo 'Usage: install.sh [--no-modify-path]'; return 0 ;;
      *) printf 'Unknown option: %s\n' "$1" >&2; return 1 ;;
    esac
    shift
  done
  SYNTH_VERSION="0.0.1-alpha.35"
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
  # Validate the complete bundle before the release installer replaces anything.
  test -f install-release.sh
  test -x libexec/synth/restic
  test -x libexec/synth/sqlite3
  test -f licenses/restic/LICENSE
  test -f licenses/sqlite/NOTICE
  ./libexec/synth/restic version >/dev/null
  ./libexec/synth/sqlite3 --version >/dev/null
  # The archive owns the installation layout, including helpers and licenses.
  bash ./install-release.sh "$HOME/.local/bin"
  printf '%s\n' "$SYNTH_INSTALLED_VERSION"
  if [ "$SYNTH_MODIFY_PATH" = 1 ]; then
    if configure_path; then
      printf '\nSynth is ready. Open a new terminal to use it.\n'
    else
      printf '\nSynth is installed. Add ~/.local/bin to your shell PATH manually.\n' >&2
    fi
  fi
  # The caller may have cached an older binary, invisible to this subprocess.
  # Assigning PATH also clears that shell's command cache.
  # shellcheck disable=SC2016
  printf '\nTo use Synth in this terminal, run:\n  export PATH="$HOME/.local/bin:$PATH"\n'
}

main "$@"
