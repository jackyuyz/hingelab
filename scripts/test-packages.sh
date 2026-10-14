#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${SWIFTLY_BIN_DIR:-$HOME/.local/share/swiftly/bin}:$PATH"
if [[ -f "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" ]]; then
  # shellcheck disable=SC1090
  source "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
fi

packages=(
  FoldKit
  HingeInput
  Synth
  MIDIOut
  SettingsKit
  Instruments
  Looper
  Store
  ThemeKit
  HingeL10n
)

failed=0
for pkg in "${packages[@]}"; do
  echo "=== $pkg ==="
  if ! (cd "$root/Packages/$pkg" && swift test); then
    echo "FAILED $pkg"
    failed=1
  fi
done

exit $failed
