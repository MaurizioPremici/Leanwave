#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
bundle_path="$project_dir/build/Leanwave.app"
install_path="/Applications/Leanwave.app"
staging_root="$(mktemp -d /tmp/leanwave-build.XXXXXX)"
staged_bundle="$staging_root/Leanwave.app"
contents_path="$staged_bundle/Contents"

cleanup() {
    /bin/rm -rf "$staging_root"
}
trap cleanup EXIT INT TERM

if [[ "${1:-}" != "" && "${1:-}" != "--install" ]]; then
    print -u2 "Usage: ./scripts/build-app.sh [--install]"
    exit 64
fi

cd "$project_dir"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
binary_path="$binary_dir/Leanwave"

if [[ ! -x "$binary_path" ]]; then
    print -u2 "Leanwave release executable was not produced."
    exit 1
fi

/bin/mkdir -p "$contents_path/MacOS" "$contents_path/Resources"
/usr/bin/install -m 755 "$binary_path" "$contents_path/MacOS/Leanwave"
/usr/bin/install -m 644 "$project_dir/Resources/Info.plist" "$contents_path/Info.plist"
/usr/bin/install -m 644 "$project_dir/Resources/Leanwave.icns" "$contents_path/Resources/Leanwave.icns"
/usr/bin/codesign --force --deep --sign - "$staged_bundle"
/usr/bin/codesign --verify --deep --strict "$staged_bundle"
/usr/bin/plutil -lint "$contents_path/Info.plist"

/bin/rm -rf "$bundle_path"
/bin/mkdir -p "${bundle_path:h}"
/usr/bin/ditto --norsrc "$staged_bundle" "$bundle_path"

if [[ "${1:-}" == "--install" ]]; then
    staging_path="/Applications/.Leanwave.installing.$$.app"
    backup_path="/Applications/.Leanwave.backup.$$.app"
    /bin/rm -rf "$staging_path" "$backup_path"
    /usr/bin/ditto --norsrc "$staged_bundle" "$staging_path"
    if [[ -e "$install_path" ]]; then
        /bin/mv "$install_path" "$backup_path"
    fi
    if /bin/mv "$staging_path" "$install_path"; then
        /bin/rm -rf "$backup_path"
    else
        [[ -e "$backup_path" ]] && /bin/mv "$backup_path" "$install_path"
        exit 1
    fi
    /usr/bin/codesign --verify --deep --strict "$install_path"
    print "Installed: $install_path"
else
    print "Built: $bundle_path"
fi
