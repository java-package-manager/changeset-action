# changeset-action

A GitHub Action for [jpm-changeset](https://github.com/java-package-manager/jpm-changeset), like
[changesets/action](https://github.com/changesets/action) for npm. On every push to main it keeps a
"Version packages" pull request with what `jpm changeset version` changes: the bumped versions, the
changelogs and the deleted changesets. Merging that pull request releases; with `publish: true` the action
then runs `jpm changeset publish` and pushes the tags.

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
        with:
          publish: true
          publish-args: central
        env:
          JPM_PUBLISH_CENTRAL_USERNAME: ${{ secrets.CENTRAL_USERNAME }}
          JPM_PUBLISH_CENTRAL_PASSWORD: ${{ secrets.CENTRAL_PASSWORD }}
```

The project declares jpm-changeset (`jpm add github:java-package-manager/jpm-changeset`), and jpm-publish for
`publish`.

## Inputs

| Input | Default | |
|---|---|---|
| `publish` | `false` | After the version pull request is merged (no changesets left), run `jpm changeset publish` and push the tags |
| `publish-args` | | Arguments for `jpm changeset publish`, which passes them to `jpm publish` (such as a repository name) |
| `title` | `Version packages` | The pull request's title and its commit's message |
| `branch` | `changeset-release/<branch>` | The pull request's branch |
| `working-directory` | `.` | The jpm project's folder |
| `github-token` | `github.token` | The token that pushes and opens the pull request. GitHub starts no workflows for a pull request opened with the default token; use a personal access token or a GitHub App token when CI should run on it |
| `dry-run` | `false` | Version and commit on the branch, but push nothing and open no pull request |

Outputs: `pull-request` (its number, when one is open) and `published` (`"true"` when this run published).

## Versions

Releases are tagged `v<version>` (`v1.2.3`), and `v1` always follows the newest `v1.x.y`. To release, change
`VERSION` and push to main: once the tests pass, CI tags the commit, creates the GitHub release and moves
`v1`.

## License

MIT, see [LICENSE](LICENSE).
