#!/usr/bin/env bash
# One-time migration: replay ZedRail-only commits onto the latest upstream stable tag.
# After this succeeds, sync-upstream.yml keeps main and zedrail aligned with gh releases.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

STABLE_TAG="${1:-}"
if [[ -z "${STABLE_TAG}" ]]; then
  STABLE_TAG=$(gh release list --repo zed-industries/zed --limit 30 \
    --json tagName,isPrerelease \
    --jq '[.[] | select(.isPrerelease == false)] | first | .tagName')
fi

if [[ -z "${STABLE_TAG}" ]]; then
  echo "Could not resolve latest stable release tag." >&2
  exit 1
fi

git remote add upstream https://github.com/zed-industries/zed.git 2>/dev/null || true
git fetch upstream tag "${STABLE_TAG}" 2>/dev/null || git fetch upstream --tags --force 2>/dev/null || git fetch upstream
git fetch origin zedrail main 2>/dev/null || git fetch zed-rail zedrail main 2>/dev/null || true

STABLE_SHA=$(git rev-parse "refs/tags/${STABLE_TAG}^{commit}")
STABLE_VERSION="${STABLE_TAG#v}"

echo "Rebasing ZedRail onto ${STABLE_TAG} (${STABLE_SHA})"

mapfile -t COMMITS < <(
  git log --reverse --no-merges zed-rail/zedrail --not upstream/main --format=%H 2>/dev/null \
    || git log --reverse --no-merges origin/zedrail --not upstream/main --format=%H 2>/dev/null \
    || git log --reverse --no-merges zedrail --not upstream/main --format=%H
)

if [[ ${#COMMITS[@]} -eq 0 ]]; then
  echo "No fork-only commits found." >&2
  exit 1
fi

git checkout -B main "${STABLE_SHA}"
mkdir -p .zedrail
echo "${STABLE_VERSION}" > .zedrail/upstream-stable
git add .zedrail/upstream-stable
git diff --staged --quiet || git commit -m "Track upstream stable ${STABLE_TAG}"

git checkout -B zedrail main

for commit in "${COMMITS[@]}"; do
  subject=$(git log -1 --format=%s "${commit}")
  echo "Cherry-pick ${commit:0:12} — ${subject}"
  if ! git cherry-pick "${commit}"; then
    cat <<EOF

Cherry-pick stopped on ${commit}.
Resolve conflicts, then run:
  git add -A
  git cherry-pick --continue

Or abort:
  git cherry-pick --abort

When all commits are applied, verify:
  grep '^version' crates/zed/Cargo.toml   # should be ${STABLE_VERSION}

Then push (force required for main):
  git push origin main --force-with-lease
  git push origin zedrail --force-with-lease
EOF
    exit 1
  fi
done

cargo_version=$(awk -F'"' '/^version = / { print $2; exit }' crates/zed/Cargo.toml)
if [[ "${cargo_version}" != "${STABLE_VERSION}" ]]; then
  echo "Warning: Cargo.toml version is ${cargo_version}, expected ${STABLE_VERSION}" >&2
fi

cat <<EOF

Migration complete on branch zedrail (based on ${STABLE_TAG}).
Review the build, then push:
  git push origin main --force-with-lease
  git push origin zedrail --force-with-lease
EOF
