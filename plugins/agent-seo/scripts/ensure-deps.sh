#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
RUBY_DIR="${PLUGIN_ROOT}/data_sources/ruby"
MARKER="${RUBY_DIR}/vendor/.installed"

if ! command -v ruby &> /dev/null; then
  echo "[agent-seo] Ruby not found. Core commands (research, write, humanize, fact-check) work without it. Analysis tools (keyword density, readability, SEO quality, scrub) require Ruby 3.0+."
  exit 0
fi

if ! command -v bundle &> /dev/null; then
  echo "[agent-seo] Bundler not found. Install with: gem install bundler"
  exit 0
fi

if [ ! -d "$RUBY_DIR" ]; then
  echo "[agent-seo] Ruby tools directory not found at ${RUBY_DIR}. Core prompt-driven workflows still work."
  exit 0
fi

cd "$RUBY_DIR"

if [ ! -f "$MARKER" ] || [ "Gemfile" -nt "$MARKER" ] || [ "Gemfile.lock" -nt "$MARKER" ]; then
  echo "[agent-seo] Installing Ruby dependencies..."
  bundle config set --local path vendor/bundle
  bundle install --quiet
  touch "$MARKER"
  echo "[agent-seo] Ruby dependencies installed."
fi
