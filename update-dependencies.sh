#!/usr/bin/env bash
# Updates all git submodules to the latest commit on the main branch.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

if [ ! -f ".gitmodules" ]; then
    echo "No .gitmodules file found — nothing to update."
    exit 0
fi

echo "Initializing and updating submodules..."
git submodule update --init --recursive

SUBMODULE_PATHS=$(git config --file .gitmodules --get-regexp path | awk '{print $2}')
TARGET_BRANCH="master"
updated_submodules=()

for path in ${SUBMODULE_PATHS}; do
    if [ ! -d "${path}" ]; then
        echo "Skipping $(pwd)/${path}: path does not exist."
        continue
    fi

    if ! git -C "${path}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Skipping $(pwd)/${path}: not a git repository."
        continue
    fi

    echo "---- ${path} ----"
    pushd "${path}" >/dev/null
    git fetch origin

    if git show-ref --verify --quiet "refs/remotes/origin/${TARGET_BRANCH}"; then
        git checkout "${TARGET_BRANCH}"
        git pull --ff-only origin "${TARGET_BRANCH}"
    else
        echo "Remote branch ${TARGET_BRANCH} not found in ${path}, skipping."
        popd >/dev/null
        continue
    fi

    # Update nested submodules, if any
    if [ -f ".gitmodules" ]; then
        git submodule update --init --recursive
        git submodule foreach --recursive 'git fetch origin && git checkout '"${TARGET_BRANCH}"' && git pull --ff-only origin '"${TARGET_BRANCH}"' || true'
    fi

    updated_submodules+=("${path}")
    popd >/dev/null
done

if [ "${#updated_submodules[@]}" -gt 0 ]; then
    echo "Staging updated submodule commits in the parent repository..."
    git add "${updated_submodules[@]}"
fi

echo "Done."
