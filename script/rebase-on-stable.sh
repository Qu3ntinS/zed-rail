#!/usr/bin/env bash
# Replay ZedRail-only commits onto the latest upstream stable tag.
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

RAIL_REMOTE=""
if git remote get-url zed-rail >/dev/null 2>&1; then
  RAIL_REMOTE=zed-rail
elif git rev-parse --verify origin/zedrail >/dev/null 2>&1; then
  RAIL_REMOTE=origin
fi

if [[ -z "${RAIL_REMOTE}" ]]; then
  git fetch origin zedrail main 2>/dev/null && RAIL_REMOTE=origin
fi
if [[ -z "${RAIL_REMOTE}" ]]; then
  echo "Could not find a remote with a zedrail branch (tried zed-rail, origin)." >&2
  exit 1
fi

git fetch "${RAIL_REMOTE}" zedrail main

STABLE_SHA=$(git rev-parse "refs/tags/${STABLE_TAG}^{commit}")
STABLE_VERSION="${STABLE_TAG#v}"
ZEDRAIL_REF="${RAIL_REMOTE}/zedrail"
FORK_MAIN="${RAIL_REMOTE}/main"

echo "Rebasing ZedRail onto ${STABLE_TAG} (${STABLE_SHA})"
echo "Fork commits: ${ZEDRAIL_REF} --not ${FORK_MAIN}"

mapfile -t COMMITS < <(
  git log --reverse --no-merges "${ZEDRAIL_REF}" --not "${FORK_MAIN}" --format=%H
)

if [[ ${#COMMITS[@]} -eq 0 ]]; then
  echo "No fork-only commits found." >&2
  exit 1
fi

push_help() {
  cat <<EOF

When all commits are applied, verify:
  grep '^version' crates/zed/Cargo.toml   # should be ${STABLE_VERSION}

Then push (force required for main):
  git push ${RAIL_REMOTE} main --force-with-lease
  git push ${RAIL_REMOTE} zedrail --force-with-lease
EOF
}

git checkout -B main "${STABLE_SHA}"
mkdir -p .zedrail
echo "${STABLE_VERSION}" > .zedrail/upstream-stable
git add .zedrail/upstream-stable
git diff --staged --quiet || git commit -m "Track upstream stable ${STABLE_TAG}"

git checkout -B zedrail main

for commit in "${COMMITS[@]}"; do
  subject=$(git log -1 --format=%s "${commit}")
  case "${subject}" in
    "Track upstream stable "*)
      echo "Skip ${commit:0:12} — ${subject}"
      continue
      ;;
    "Fix stable-branch compile errors from cherry-pick migration.")
      echo "Skip ${commit:0:12} — ${subject} (previous-stable API restore)"
      continue
      ;;
  esac

  echo "Cherry-pick ${commit:0:12} — ${subject}"

  if [[ "${subject}" == Restore\ v1.16.1\ sidebar/lsp_button* ]]; then
    if git cherry-pick -n "${commit}"; then
      git checkout HEAD -- \
        crates/collab_ui/src/edit_prediction_button.rs \
        crates/edit_prediction_ui/src/edit_prediction_button.rs \
        crates/language_tools/src/lsp_button.rs \
        crates/sidebar/src/sidebar.rs \
        2>/dev/null || true
      git add -A
      if git diff --cached --quiet; then
        git reset --hard HEAD
        echo "Skipped rust API restore from ${commit:0:12}; no remaining changes"
      else
        git commit -C "${commit}"
      fi
      continue
    fi
    git cherry-pick --abort 2>/dev/null || git reset --hard HEAD
    echo "Could not apply ${commit:0:12} without conflicts; taking workflow files only"
    if git show "${commit}" -- .github/ | git apply --3way; then
      git add -A
      git diff --cached --quiet || git commit -C "${commit}"
    else
      echo "Failed to apply workflow portion of ${commit}" >&2
      push_help
      exit 1
    fi
    continue
  fi

  if git cherry-pick "${commit}"; then
    continue
  fi
  if [[ -z "$(git diff --name-only --diff-filter=U)" ]]; then
    echo "Empty cherry-pick, skipping ${commit:0:12}"
    GIT_EDITOR=true git cherry-pick --skip
    continue
  fi

  cat <<EOF

Cherry-pick stopped on ${commit}.
Resolve conflicts, then run:
  git add -A
  git cherry-pick --continue

Or abort:
  git cherry-pick --abort
EOF
  push_help
  exit 1
done

cargo_version=$(awk -F'"' '/^version = / { print $2; exit }' crates/zed/Cargo.toml)
if [[ "${cargo_version}" != "${STABLE_VERSION}" ]]; then
  echo "Warning: Cargo.toml version is ${cargo_version}, expected ${STABLE_VERSION}" >&2
fi

cat <<EOF

Migration complete on branch zedrail (based on ${STABLE_TAG}).
Review the build, then push:
  git push ${RAIL_REMOTE} main --force-with-lease
  git push ${RAIL_REMOTE} zedrail --force-with-lease
EOF
