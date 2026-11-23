#!/usr/bin/env bash
# Keeps a "Version packages" pull request with the changes `jpm changeset version` makes; once it is merged
# and no changesets are left, tags what has no tag yet with `jpm changeset publish`, pushes the new tags and
# creates a GitHub release for each. It publishes with jpm publish first when `publish` is true, or when it is
# left out and jpm publish is installed; otherwise it only tags (--tag-only).
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

# pushes with github-token, not with the credentials actions/checkout stored: GitHub starts no workflows for a push
# made with github.token, so CI would not run on the version pull request although github-token is another token.
# An empty http.<server>/.extraheader drops the header checkout set; the next one sends github-token.
push() {
  if [ -n "${GH_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
    local server="${GITHUB_SERVER_URL:-https://github.com}"
    local auth
    auth="$(printf 'x-access-token:%s' "$GH_TOKEN" | base64 | tr -d '\n')"
    echo "::add-mask::$auth"
    git -c "http.$server/.extraheader=" -c "http.$server/.extraheader=AUTHORIZATION: basic $auth" push "$@"
  else
    git push "$@"
  fi
}

plan="$(jpm changeset status 2>&1 || true)"
git checkout -q -B "$branch"
trap 'git checkout -q "$base" 2>/dev/null || true' EXIT
jpm changeset version
if [ -z "$(git status --porcelain -- . ':(exclude).changeset')" ]; then
  if [ -n "$(git status --porcelain)" ]; then
    echo "The pending changesets release nothing (they are empty): no version pull request; they stay until a release."
    git reset -q --hard
    git clean -fdq -- .changeset
  else
    echo "No changesets to release."
  fi
  git checkout -q "$base"
  git branch -q -D "$branch"
  if help="$(jpm publish --help 2>&1)"; then
    installed=true
  elif printf '%s' "$help" | grep -q 'Unknown command "publish"'; then
    installed=false
  else
    echo "::error::could not tell whether jpm publish is installed: $help"
    exit 1
  fi
  case "${INPUT_PUBLISH:-}" in
    "") publish="$installed" ;;
    true)
      if [ "$installed" = false ]; then
        echo "::error::publish is true, but jpm publish is not installed; add it with \`jpm add github:java-package-manager/jpm-publish\`"
        exit 1
      fi
      publish=true
      ;;
    false) publish=false ;;
    *)
      echo "::error::publish must be true, false or left out, not \"$INPUT_PUBLISH\""
      exit 1
      ;;
  esac
  if [ "$publish" = "true" ]; then
    echo "Publishing with jpm publish, then tagging."
    # shellcheck disable=SC2206
    args=(${INPUT_PUBLISH_ARGS:-})
  else
    echo "Tagging without jpm publish ($([ "$installed" = true ] && echo "publish is false" || echo "it is not installed"))."
    args=(--tag-only)
  fi
  before="$(git tag -l | sort)"
  jpm changeset publish "${args[@]}"
  tags="$(comm -13 <(printf '%s\n' "$before") <(git tag -l | sort) | tr '\n' ' ' | sed 's/ *$//')"
  echo "tags=$tags" >> "$out"
  if [ -z "$tags" ]; then
    echo "published=false" >> "$out"
    exit 0
  fi
  echo "published=true" >> "$out"
  if [ "$dry" = "true" ]; then
    echo "Dry run: tagged $tags; nothing is pushed and no release is created."
    exit 0
  fi
  refs=()
  for t in $tags; do refs+=("refs/tags/$t"); done
  push -q origin "${refs[@]}"
  echo "Pushed $tags"
  if [ "${INPUT_GITHUB_RELEASE:-true}" = "true" ]; then
    for t in $tags; do
      name="$(git tag -l "$t" --format='%(contents:subject)')"
      notes="$(git tag -l "$t" --format='%(contents:body)')"
      pre=()
      case "${t##*@}" in *-*) pre=(--prerelease) ;; esac
      gh release create "$t" --verify-tag --title "${name:-$t}" --notes "${notes:-$t}" "${pre[@]}" >/dev/null
      echo "Released $t"
    done
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

push -q --force origin "$branch"
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
