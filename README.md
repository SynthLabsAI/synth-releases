# Synth CLI releases

Public, binary-only releases for the Synth CLI.

The current release, [`v0.0.1-alpha.1`](https://github.com/SynthLabsAI/synth-releases/releases/tag/v0.0.1-alpha.1), is prerelease software for users whose Synth account and organization are already provisioned.

## Current limitations

- First-time account and organization provisioning is currently unavailable. If browser login cannot complete, stop; there is no supported CLI workaround.
- The released task registry is scoped to records owned by the signed-in user. It does not provide public task discovery, so this release does not yet have a complete public managed-training quickstart.
- The macOS binaries are ad-hoc signed and not notarized. Gatekeeper rejects the current build. Do not disable Gatekeeper or remove quarantine to install it; use a supported Linux environment or wait for a notarized release.

## Install and verify

[Release assets](https://github.com/SynthLabsAI/synth-releases/releases) include Linux, macOS, and Windows builds plus `checksums.txt`. The example below installs the Linux x86-64 CLI. Choose a different `synth_...` archive only when it matches your operating system and CPU and the limitations above.

Run this in a fresh directory:

```bash
set -euo pipefail

VERSION=v0.0.1-alpha.1
ARCHIVE=synth_0.0.1-alpha.1_linux_amd64.tar.gz
BASE="https://github.com/SynthLabsAI/synth-releases/releases/download/$VERSION"
DEST="./synth-$VERSION"

[ ! -e "$DEST" ] || {
  printf 'destination already exists: %s\n' "$DEST" >&2
  exit 1
}

curl -fLO "$BASE/$ARCHIVE"
curl -fLO "$BASE/checksums.txt"

CHECKSUM_LINE="$(
  awk -v archive="$ARCHIVE" '
    $2 == archive { line = $0; matches++ }
    END {
      if (matches != 1) exit 1
      print line
    }
  ' checksums.txt
)" || {
  printf 'expected exactly one checksum entry for %s\n' "$ARCHIVE" >&2
  exit 1
}

if command -v sha256sum >/dev/null 2>&1; then
  printf '%s\n' "$CHECKSUM_LINE" | sha256sum -c -
elif command -v shasum >/dev/null 2>&1; then
  printf '%s\n' "$CHECKSUM_LINE" | shasum -a 256 -c -
else
  printf 'no SHA-256 checker found\n' >&2
  exit 1
fi

mkdir "$DEST"
tar -xzf "$ARCHIVE" -C "$DEST" synth
[ -f "$DEST/synth" ] && [ ! -L "$DEST/synth" ] || {
  printf 'archive did not contain a regular synth binary\n' >&2
  exit 1
}

mkdir -p "$HOME/.local/bin"
install -m 0755 "$DEST/synth" "$HOME/.local/bin/synth"
export PATH="$HOME/.local/bin:$PATH"
synth --version
```

The checksum lookup requires exactly one matching entry. Extraction selects only the `synth` binary into a new directory; it does not unpack the archive's bundled README over files in your working directory.

## Sign in

Provisioned users can sign in through the browser and inspect the resulting customer identity:

```bash
synth login
synth auth status --json
synth whoami --json
```

Continue only when auth status reports both `"signed_in": true` and `"request_authenticated": true`. If either value is false, stop and sign in again.

## Managed training

The binary includes `synth train`, but `v0.0.1-alpha.1` cannot discover a public task version for a fresh user. This README intentionally stops before run creation. Do not invent a task ID or treat this release as a complete managed-training onboarding path.
