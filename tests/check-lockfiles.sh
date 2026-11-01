#!/usr/bin/env bash
set -euo pipefail

action_file="$(cd "$(dirname "$0")/.." && pwd)/action.yml"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

# Exercise the actual composite-action script without installing packages.
awk '
  /^      run: \|/ { copying = 1; next }
  copying && /^    - name:/ { exit }
  copying { sub(/^        /, ""); print }
' "$action_file" > "$test_dir/check-lockfiles.sh"
bash -n "$test_dir/check-lockfiles.sh"

check() {
    local name=$1 input=$2 manifest=$3 lockfile=$4 expected=$5
    local project="$test_dir/$name"
    mkdir -p "$project/site"
    printf '%s\n' "$manifest" > "$project/site/package.json"
    touch "$project/site/$lockfile"
    (cd "$project/site" && INPUT_PM="$input" GITHUB_ENV="$project/env" bash -e "$test_dir/check-lockfiles.sh") > "$project/log"
    while IFS= read -r line; do
        if [ "$(awk -F= -v key="${line%%=*}" '$1 == key { value = $0 } END { print value }' "$project/env")" != "$line" ]; then
            echo "$name: expected $line" >&2
            cat "$project/env" >&2
            exit 1
        fi
    done <<< "$expected"
    echo "PASS: $name"
}

modern='{"packageManager":"pnpm@12.8.2","devEngines":{"packageManager":{"name":"pnpm","version":"^12.0.0"}}}'
check range "" "$modern" pnpm-lock.yaml $'PACKAGE_MANAGER=pnpm\nLOCKFILE=pnpm-lock.yaml\nPNPM_SETUP=true\nVERSION='
check unversioned-input pnpm "$modern" pnpm-lock.yaml $'PNPM_SETUP=true\nVERSION='
check explicit-input pnpm@12.8.2 "$modern" pnpm-lock.yaml $'PNPM_SETUP=false\nVERSION=12.8.2'
check explicit-tag pnpm@latest "$modern" pnpm-lock.yaml $'PNPM_SETUP=false\nVERSION=latest'
check exact "" '{"devEngines":{"packageManager":{"name":"pnpm","version":"12.8.1"}}}' pnpm-lock.yaml $'PNPM_SETUP=true\nVERSION='
check legacy "" '{"packageManager":"pnpm@10.30.0"}' pnpm-lock.yaml $'PNPM_SETUP=false\nVERSION='
check legacy-input pnpm '{"packageManager":"pnpm@10.30.0"}' pnpm-lock.yaml $'PNPM_SETUP=false\nVERSION='
check fallback "" '{}' pnpm-lock.yaml $'PNPM_SETUP=false\nVERSION=latest'
grep -q '::warning' "$test_dir/fallback/log"
check empty-version "" '{"devEngines":{"packageManager":{"name":"pnpm","version":""}}}' pnpm-lock.yaml $'PNPM_SETUP=false\nVERSION=latest'
check other-manager "" '{"devEngines":{"packageManager":{"name":"npm","version":"11"}}}' pnpm-lock.yaml $'PNPM_SETUP=false\nVERSION=latest'
check npm "" "$modern" package-lock.json $'PACKAGE_MANAGER=npm\nLOCKFILE=package-lock.json\nVERSION=latest'
check yarn "" "$modern" yarn.lock $'PACKAGE_MANAGER=yarn\nLOCKFILE=yarn.lock\nVERSION='
check bun "" "$modern" bun.lock $'PACKAGE_MANAGER=bun\nLOCKFILE=bun.lock\nVERSION=latest'
check deno "" "$modern" deno.lock $'PACKAGE_MANAGER=deno\nLOCKFILE=deno.lock\nVERSION=vx.x.x'
PACKAGE_MANAGER=pnpm VERSION=12.8.1 PNPM_SETUP=true check repeated-action "" "$modern" package-lock.json $'PACKAGE_MANAGER=npm\nPNPM_SETUP=false\nVERSION=latest'

step() {
    awk -v name="$1" '
      /^    - name:/ { copying = ($0 == "    - name: " name) }
      copying { print }
    ' "$action_file"
}

assert_step() {
    if ! step "$1" | grep -Fq -- "$2"; then
        echo "$1: expected $2" >&2
        exit 1
    fi
}

assert_step "Setup PNPM from lockfile" "runtime: node@\${{ inputs.node-version }}"
assert_step "Setup PNPM from lockfile" "env.PNPM_SETUP == 'true'"
assert_step "Setup Node" "env.PNPM_SETUP != 'true'"
assert_step "Install" "env.PNPM_SETUP != 'true'"
# pnpm/setup's default install adds --no-runtime after installing Node.
if step "Setup PNPM from lockfile" | grep -Eq "install: ['\"]?false"; then
    echo 'pnpm/setup must install dependencies to suppress duplicate runtime installation' >&2
    exit 1
fi
for name in "Setup Node" "Install" "Build (npm/yarn/pnpm/bun)"; do
    assert_step "$name" "PNPM_CONFIG_PM_ON_FAIL: \${{ startsWith(inputs.package-manager, 'pnpm@') && 'ignore' || env.PNPM_CONFIG_PM_ON_FAIL || env.pnpm_config_pm_on_fail }}"
done
echo 'PASS: one Node setup, one dependency install, and explicit pnpm overrides'

# Requires pnpm 11+; the uppercase override must beat conflicting lowercase configuration.
mkdir -p "$test_dir/override"
printf '%s\n' '{"devEngines":{"packageManager":{"name":"pnpm","version":"0.0.0","onFail":"error"}}}' > "$test_dir/override/package.json"
(
    cd "$test_dir/override"
    expected=$(pnpm --config.pm-on-fail=ignore --version)
    actual=$(PNPM_CONFIG_PM_ON_FAIL=ignore pnpm_config_pm_on_fail=error pnpm --version)
    if [ "$actual" != "$expected" ]; then
        echo "Expected pnpm $expected despite conflicting project and lowercase configuration, got $actual" >&2
        exit 1
    fi
)
echo 'PASS: uppercase pnpm override wins over conflicting project and lowercase configuration'
