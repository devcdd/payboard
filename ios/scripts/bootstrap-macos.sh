#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE_PATH="${ROOT_DIR}/Brewfile"

log() {
  printf "[bootstrap] %s\n" "$1"
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew already installed"
    return
  fi

  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode command line tools already configured: $(xcode-select -p)"
    return
  fi

  log "Installing Xcode command line tools"
  xcode-select --install || true
  log "If a popup appeared, complete installation then rerun this script"
}

install_brew_packages() {
  log "Updating Homebrew"
  brew update

  if [[ ! -f "${BREWFILE_PATH}" ]]; then
    log "Brewfile not found at ${BREWFILE_PATH}"
    exit 1
  fi

  log "Installing packages from Brewfile"
  brew bundle --file="${BREWFILE_PATH}"
}

print_next_steps() {
  cat <<'STEPS'

[bootstrap] Completed.

Next steps:
1) If Xcode.app was newly installed, run: sudo xcode-select -s /Applications/Xcode.app
2) Accept Xcode license: sudo xcodebuild -license accept
3) Verify toolchain:
   - swift --version
   - xcodebuild -version
4) Build and test:
   - swift build
   - swift test

STEPS
}

main() {
  ensure_homebrew
  ensure_xcode_clt
  install_brew_packages
  print_next_steps
}

main "$@"
