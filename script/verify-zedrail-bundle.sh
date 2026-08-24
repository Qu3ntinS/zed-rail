#!/usr/bin/env bash
# Fail fast if release bundle scripts still reference upstream Zed binary names.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

errors=0

fail() {
    echo "ERROR: $1" >&2
    errors=$((errors + 1))
}

assert_file_contains() {
    local file=$1
    local needle=$2
    if ! grep -Fq -- "$needle" "$file"; then
        fail "$file is missing required text: $needle"
    fi
}

assert_file_lacks() {
    local file=$1
    local needle=$2
    if grep -Fq -- "$needle" "$file"; then
        fail "$file still contains forbidden text: $needle"
        grep -Fn "$needle" "$file" >&2 || true
    fi
}

assert_file_contains crates/paths/src/paths.rs 'EDITOR_BINARY_NAME: &str = "zedrail"'
assert_file_contains crates/paths/src/paths.rs 'WINDOWS_EDITOR_EXE'

for script in script/bundle-linux script/bundle-mac; do
    assert_file_contains "$script" 'EDITOR_BIN="zedrail"'
    assert_file_contains "$script" '--bin "${EDITOR_BIN}" --bin cli'
    assert_file_contains "$script" 'require_release_binary'
done

assert_file_contains script/bundle-windows.ps1 '--bin zedrail --bin cli --bin auto_update_helper'
assert_file_contains script/bundle-windows.ps1 '$editorExeName = "ZedRail.exe"'

assert_file_contains crates/zed/resources/windows/zed.iss 'Source: "{#ResourcesDir}\{#AppExeName}.exe"'
assert_file_lacks crates/zed/resources/windows/zed.iss 'Source: "{#ResourcesDir}\Zed.exe"'

assert_file_lacks script/bundle-mac 'target/${target_triple}/${target_dir}/zed"'
assert_file_lacks script/bundle-mac 'Contents/MacOS/zed"'

assert_file_contains crates/explorer_command_injector/src/explorer_command_injector.rs 'paths::WINDOWS_EDITOR_EXE'
assert_file_contains crates/auto_update/src/auto_update.rs 'paths::WINDOWS_EDITOR_EXE'

assert_file_contains crates/paths/src/paths.rs 'LINUX_LIBEXEC_EDITOR_RELATIVE_TO_BIN'
assert_file_contains crates/cli/src/main.rs 'paths::LINUX_LIBEXEC_EDITOR_RELATIVE_TO_BIN'
assert_file_lacks crates/cli/src/main.rs '../libexec/zed-editor'

if [[ $errors -gt 0 ]]; then
    echo "$errors bundle consistency check(s) failed" >&2
    exit 1
fi

echo "ZedRail bundle consistency checks passed"
