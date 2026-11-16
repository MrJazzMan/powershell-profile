#!/usr/bin/env bash
# Installs `sysupdate` (and the `sysup` alias) for macOS or Omarchy/Arch.
#
#   curl -fsSL https://raw.githubusercontent.com/MrJazzMan/powershell-profile/master/sysupdate/install.sh | bash
#
# or, from a clone of this repo:   bash sysupdate/install.sh
#
# Puts the script in ~/.local/bin (no sudo needed) and links `sysup` to it.
# Safe to run again: it just replaces the script with the current version.

set -eu

REPO_RAW="https://raw.githubusercontent.com/MrJazzMan/powershell-profile/master/sysupdate"

case "$(uname -s)" in
    Darwin) flavour=macos ;;
    Linux)
        if command -v omarchy-update >/dev/null 2>&1 || command -v pacman >/dev/null 2>&1; then
            flavour=omarchy
        else
            echo "This Linux has neither Omarchy nor pacman; only macOS and Omarchy/Arch are supported." >&2
            exit 1
        fi ;;
    *) echo "Unsupported system: $(uname -s). On Windows use sysupdate/windows/install-sysupdate.ps1." >&2; exit 1 ;;
esac

bin="$HOME/.local/bin"
target="$bin/sysupdate"
mkdir -p "$bin"

# Prefer the copy next to this script (running from a clone); otherwise download.
here=""
if [ -n "${BASH_SOURCE:-}" ] && [ -f "${BASH_SOURCE[0]:-}" ]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$here" ] && [ -f "$here/$flavour/sysupdate" ]; then
    cp "$here/$flavour/sysupdate" "$target.new"
else
    curl -fsSL "$REPO_RAW/$flavour/sysupdate" -o "$target.new"
fi
chmod +x "$target.new"
mv "$target.new" "$target"
ln -sf "$target" "$bin/sysup"
echo "Installed: $target ($flavour) + sysup"

# An older sysupdate defined as a shell function/alias would win over the script.
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME"/.zshrc.d/*.zsh; do
    [ -f "$rc" ] || continue
    if grep -qE '^[[:space:]]*(function[[:space:]]+)?sysupdate[[:space:]]*\(\)|alias[[:space:]]+sysup(date)?=' "$rc"; then
        echo "Warning: $rc defines its own sysupdate/sysup; remove it so this version is used." >&2
    fi
done

case ":$PATH:" in
    *":$bin:"*) echo "Ready. Run:  sysupdate   (or sysup)" ;;
    *)
        echo "Note: $bin is not on your PATH. Add this line to your shell rc file, then open a new terminal:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
