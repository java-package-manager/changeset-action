# changeset-action

A GitHub Action for [jpm-changeset](https://github.com/java-package-manager/jpm-changeset), like
[changesets/action](https://github.com/changesets/action) for npm. On every push to main it keeps a
"Version packages" pull request with what `jpm changeset version` changes: the bumped versions, the
changelogs and the deleted changesets. Merging that pull request releases: the action tags every module
whose version has no tag yet (`jpm changeset publish`), pushes the new tags and creates a GitHub
release for each, with the module's changelog entry as its notes; a prerelease version (`1.4.0-beta.0`) becomes
a GitHub prerelease. A release needs no jpm publish: it is the tag and the GitHub release. When
[jpm-publish](https://github.com/java-package-manager/jpm-publish) is installed (in the project or globally),
the action publishes with it before it tags; `publish: true` requires that, and `publish: false` never publishes.

It needs jpm-changeset 0.3.1 or newer.

```yaml
name: Release
on:
  push:
    branches: [main]
permissions:
  contents: write
  pull-requests: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: java-package-manager/setup-jpm@v1
      - uses: java-package-manager/changeset-action@v1
```

To publish to Maven Central as well (with jpm-publish installed):

```yaml
      - uses: java-package-manager/changeset-action@v1
        with:
          publish-args: central
        env:
          JPM_PUBLISH_CENTRAL_USERNAME: ${{ secrets.CENTRAL_USERNAME }}
          JPM_PUBLISH_CENTRAL_PASSWORD: ${{ secrets.CENTRAL_PASSWORD }}
```

The project declares jpm-changeset (`jpm add github:java-package-manager/jpm-changeset`), and jpm-publish to
publish.

## Inputs

| Input | Default | |
|---|---|---|
| `publish` | (detected) | Publish with jpm publish before tagging. Left out: when jpm publish is installed. `true`: always, and fail when it is not installed. `false`: never, only tag |
| `publish-args` | | When publishing: arguments for `jpm changeset publish`, which passes them to `jpm publish` (such as a repository name) |
| `github-release` | `true` | Create a GitHub release for each new tag |
| `title` | `Version packages` | The pull request's title and its commit's message |
| `branch` | `changeset-release/<branch>` | The pull request's branch |
| `working-directory` | `.` | The jpm project's folder |
| `github-token` | `github.token` | The token that pushes and opens the pull request. GitHub starts no workflows for a pull request opened with the default token; use a personal access token or a GitHub App token when CI should run on it |
| `dry-run` | `false` | Version and commit on the branch, but push nothing and open no pull request |

Outputs: `pull-request` (its number, when one is open), `published` (`"true"` when this run released) and
`tags` (the tags it created, separated by spaces).

A project whose current version has no tag yet is released on the action's first run.

## Versions

Releases are tagged `v<version>` (`v1.2.3`), and `v1` always follows the newest `v1.x.y`. To release, change
`VERSION` and push to main: once the tests pass, CI tags the commit, creates the GitHub release and moves
`v1`.

## License

MIT, see [LICENSE](LICENSE).
