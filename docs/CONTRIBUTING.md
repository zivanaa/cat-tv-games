# Conventions

Enforced by git hooks in `.githooks/` and by CI. Install the hooks once:

```bash
git config core.hooksPath .githooks
```

`scripts/setup-repo.sh` does this for you.

## Branches

```
<type>/<kebab-case-description>
<type>/<issue-number>-<kebab-case-description>
```

Types: `feat` `fix` `chore` `docs` `refactor` `test` `perf` `ci` `build` `style`

```
feat/paw-input-assist
fix/generous-tier-reach
feat/42-rolling-buffer-android
chore/bump-flame
```

Lower case, hyphens, no underscores, no slashes past the first one. `feat` not
`feature` — one set of names, so a glob like `feat/*` always means the same thing.

`main` is protected. The pre-push hook refuses direct pushes; use a branch and a
PR. `git push --no-verify` bypasses it when you genuinely need to.

## Commits

[Conventional Commits](https://www.conventionalcommits.org):

```
<type>(<scope>): <subject>

<body: why, not what>

<footer: Closes #123>
```

Scopes match the source tree: `cat` `human` `engine` `fish` `mouse` `laser` `tv`
`capture` `session` `core` `data` `store` `stats` `profiles` `ui` `deps` `ci` `docs`

Subject: lower case, imperative, no full stop, 72 characters max. The body is
where you explain *why* — the diff already shows what changed.

```
feat(engine): add generous tier to paw hit detection
fix(capture): stop the buffer flushing twice per trigger
docs: explain why the cat surface has no back button
refactor(data)!: return domain models instead of Isar objects
```

`!` after the scope marks a breaking change.

## Attribution

Commits carry your name only. `.claude/settings.json` sets `attribution.commit`
and `attribution.pr` to empty strings so Claude Code appends no trailer, and the
`commit-msg` hook strips tool attribution as a backstop if that config ever fails
to load or a different tool adds one. Human `Co-Authored-By` trailers are left
alone — if you pair with someone, credit them.

Note that `attribution` supersedes the older `includeCoAuthoredBy` boolean that
most guides still reference. Do not set both; they conflict.

## Before pushing

```bash
dart format lib test
flutter analyze
flutter test
```

CI runs the same three. `test/architecture_test.dart` failing means the cat
surface can reach monetization code — that is a release blocker, not a lint.
