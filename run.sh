#!/usr/bin/env bash
# Keeps a "Version packages" pull request with the changes `jpm changeset version` makes; once it is merged
# and no changesets are left, publishes with `jpm changeset publish` (when asked) and pushes the tags.
set -euo pipefail

base="$(git rev-parse --abbrev-ref HEAD)"
if [ "$base" = HEAD ]; then base="${GITHUB_REF_NAME:?the checkout has no branch; run on a push to a branch}"; fi
branch="${INPUT_BRANCH:-changeset-release/$base}"
title="${INPUT_TITLE:-Version packages}"
dry="${INPUT_DRY_RUN:-false}"
out="${GITHUB_OUTPUT:-/dev/null}"

command -v jpm >/dev/null || { echo "::error::jpm is not on PATH; add java-package-manager/setup-jpm@v1 before this action"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "::error::not in a git repository; check out the repository first"; exit 1; }

git config user.name >/dev/null || git config user.name "github-actions[bot]"
git config user.email >/dev/null || git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

plan="$(jpm changeset status 2>&1 || true)"
git checkout -q -B "$branch"
trap 'git checkout -q "$base" 2>/dev/null || true' EXIT
jpm changeset version
if [ -z "$(git status --porcelain)" ]; then
  git checkout -q "$base"
  git branch -q -D "$branch"
  echo "No changesets to release."
  echo "published=false" >> "$out"
  if [ "${INPUT_PUBLISH:-false}" = "true" ]; then
    # shellcheck disable=SC2086
    jpm changeset publish ${INPUT_PUBLISH_ARGS:-}
    if [ "$dry" = "true" ]; then
      echo "Dry run: the tags are not pushed."
    else
      git push --tags
    fi
    echo "published=true" >> "$out"
  fi
  exit 0
fi

git add -A
git commit -q -m "$title"
body="This pull request was opened by [changeset-action](https://github.com/java-package-manager/changeset-action). Merging it releases:

\`\`\`
$plan
\`\`\`

Add more changesets to main and this pull request follows them."

if [ "$dry" = "true" ]; then
  echo "Dry run: committed \"$title\" on $branch; nothing is pushed."
  git log --oneline -1
  exit 0
fi

git push -q --force origin "$branch"
number="$(gh pr list --head "$branch" --base "$base" --state open --json number --jq '.[0].number // empty')"
if [ -n "$number" ]; then
  gh pr edit "$number" --title "$title" --body "$body" >/dev/null
  echo "Updated #$number"
else
  gh pr create --head "$branch" --base "$base" --title "$title" --body "$body" >/dev/null
  number="$(gh pr list --head "$branch" --base "$base" --state open --json number --jq '.[0].number')"
  echo "Opened #$number"
fi
echo "pull-request=$number" >> "$out"
git checkout -q "$base"
