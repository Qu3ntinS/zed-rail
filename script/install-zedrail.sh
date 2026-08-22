#!/usr/bin/env sh
set -eu

# Downloads the latest ZedRail Linux tarball from GitHub Releases and unpacks
# it into ~/.local/. Usage:
#   curl -f https://raw.githubusercontent.com/Qu3ntinS/zed-rail/zedrail/script/install-zedrail.sh | sh

ZEDRAIL_REPO="${ZEDRAIL_REPO:-Qu3ntinS/zed-rail}"
ZEDRAIL_VERSION="${ZEDRAIL_VERSION:-latest}"

main() {
    platform="$(uname -s)"
    arch="$(uname -m)"

    if [ "$platform" != "Linux" ]; then
        echo "ZedRail install.sh currently supports Linux only."
        echo "Download other platforms from: https://github.com/${ZEDRAIL_REPO}/releases"
        exit 1
    fi

    case "$arch" in
        arm64 | aarch64) arch="aarch64" ;;
        x86_64 | amd64) arch="x86_64" ;;
        *)
            echo "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    if command -v curl >/dev/null 2>&1; then
        download() { curl -fL "$@"; }
    elif command -v wget >/dev/null 2>&1; then
        download() { wget -O- "$@"; }
    else
        echo "Could not find 'curl' or 'wget' in your PATH"
        exit 1
    fi

    if [ -n "${TMPDIR:-}" ] && [ -d "${TMPDIR}" ]; then
        temp="$(mktemp -d "$TMPDIR/zedrail-XXXXXX")"
    else
        temp="$(mktemp -d "/tmp/zedrail-XXXXXX")"
    fi

    asset="zedrail-linux-${arch}.tar.gz"
    if [ "$ZEDRAIL_VERSION" = "latest" ]; then
        url="https://github.com/${ZEDRAIL_REPO}/releases/latest/download/${asset}"
    else
        url="https://github.com/${ZEDRAIL_REPO}/releases/download/${ZEDRAIL_VERSION}/${asset}"
    fi

    echo "Downloading ZedRail (${ZEDRAIL_VERSION}) for linux-${arch}..."
    download "$url" > "$temp/${asset}"

    rm -rf "$HOME/.local/zedrail.app"
    mkdir -p "$HOME/.local"
    tar -xzf "$temp/${asset}" -C "$HOME/.local/"

    zedrail_editor="$HOME/.local/zedrail.app/libexec/zedrail-editor"
    if [ -f "$zedrail_editor" ] && command -v ldd >/dev/null 2>&1; then
        missing="$(ldd "$zedrail_editor" 2>/dev/null | sed -n 's/^[[:space:]]*\(.*\) => not found$/\1/p')"
        if [ -n "$missing" ]; then
            echo "Warning: your system is missing libraries that ZedRail needs:"
            echo "$missing" | sed 's/^/    /'
        fi
    fi

    mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
    ln -sf "$HOME/.local/zedrail.app/bin/zedrail" "$HOME/.local/bin/zedrail"

    appid="dev.zedrail.ZedRail"
    desktop_file_path="$HOME/.local/share/applications/${appid}.desktop"
    src_dir="$HOME/.local/zedrail.app/share/applications"
    if [ -f "$src_dir/${appid}.desktop" ]; then
        cp "$src_dir/${appid}.desktop" "${desktop_file_path}"
    else
        cp "$src_dir/zedrail.desktop" "${desktop_file_path}" 2>/dev/null || true
    fi
    if [ -f "${desktop_file_path}" ]; then
        sed -i "s|Icon=zedrail|Icon=$HOME/.local/zedrail.app/share/icons/hicolor/512x512/apps/zedrail.png|g" "${desktop_file_path}"
        sed -i "s|Exec=zedrail|Exec=$HOME/.local/zedrail.app/bin/zedrail|g" "${desktop_file_path}"
    fi

    if [ "$(command -v zedrail)" = "$HOME/.local/bin/zedrail" ]; then
        echo "ZedRail has been installed. Run with 'zedrail'"
    else
        echo "ZedRail has been installed to ~/.local/zedrail.app"
        echo "Add ~/.local/bin to your PATH, then run 'zedrail'"
    fi
}

main "$@"
