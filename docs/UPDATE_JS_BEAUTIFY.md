# Updating js-beautify Assets

This repo bundles minified js-beautify assets under `Sources/JSBeautify/Assets` and exposes a Swift wrapper. Use the update script to pull new upstream releases, run tests, tag, push, and open a PR.

## Prerequisites

- Clean git working tree
- `curl`, `git`, `python3`, `swift` available on PATH
- GitHub CLI (`gh`) installed and authenticated
- `origin` remote points at the GitHub repo

## Update Steps

1. Make sure `main` is up to date and clean:

```bash
git checkout main
git pull --ff-only
```

2. Run the updater:

```bash
scripts/update-js-beautify.sh
```

The script will:
- Check the latest version via cdnjs
- Create a branch `update-js-beautify-<version>`
- Download new `.min.js` files + `LICENSE`
- Update the version string in `README.md`
- Run `swift test`
- Commit, tag `v<version>`, push branch and tag
- Create a PR with `gh`

3. Review and merge the PR, then delete the branch.

## Notes

- If the script exits early, check the error and the working tree. You can re-run after fixing issues.
- If `gh` is missing, the script will stop after pushing; create the PR manually.
- Tags must be unique; if `v<version>` already exists, the script will abort.
