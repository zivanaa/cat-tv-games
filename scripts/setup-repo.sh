#!/usr/bin/env bash
# One-time repo setup. Run this from the project root, once, on your machine.
#
#   ./scripts/setup-repo.sh "Your Name" "you@example.com" [repo-name] [public|private]
#
# It never touches credentials. Repo creation goes through your own `gh` session,
# so the repo and every commit belong to your account.

set -euo pipefail

NAME="${1:-}"
EMAIL="${2:-}"
REPO="${3:-cat-tv-games}"
VISIBILITY="${4:-private}"

if [[ -z "$NAME" || -z "$EMAIL" ]]; then
  echo "Usage: ./scripts/setup-repo.sh \"Your Name\" \"you@example.com\" [repo-name] [public|private]" >&2
  exit 1
fi

echo "==> Git identity"
git init -q -b main 2>/dev/null || true
git config user.name "$NAME"
git config user.email "$EMAIL"
echo "    $NAME <$EMAIL>  (this repo only)"

echo "==> Hooks"
git config core.hooksPath .githooks
chmod +x .githooks/*
echo "    core.hooksPath = .githooks"

echo "==> Commit template"
git config commit.template .gitmessage
git config push.default current
git config pull.rebase true

echo "==> First commit"
git add -A
if git diff --cached --quiet; then
  echo "    nothing staged, skipping"
else
  git commit -q -m "chore: scaffold project structure and conventions"
  echo "    done"
fi

echo "==> GitHub"
if ! command -v gh >/dev/null 2>&1; then
  cat <<'MSG'
    gh is not installed. Install it, then run:

      gh auth login
      gh repo create <name> --private --source=. --remote=origin --push

    Install: https://cli.github.com
MSG
  exit 0
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "    Not signed in. Run 'gh auth login' first, then re-run this script."
  exit 1
fi

OWNER="$(gh api user --jq .login)"
echo "    Signed in as $OWNER"

if git remote get-url origin >/dev/null 2>&1; then
  echo "    origin already set, skipping repo creation"
else
  gh repo create "$REPO" "--$VISIBILITY" --source=. --remote=origin
  echo "    created $OWNER/$REPO ($VISIBILITY)"
fi

# --no-verify because the pre-push hook blocks main by design. This is the one
# push that has to go to main; everything after it goes through a branch.
git push --no-verify -u origin main

echo "==> Branch protection"
gh api "repos/$OWNER/$REPO/branches/main/protection" \
  --method PUT \
  --field "required_status_checks[strict]=true" \
  --field "required_status_checks[contexts][]=analyze-and-test" \
  --field "enforce_admins=false" \
  --field "required_pull_request_reviews=null" \
  --field "restrictions=null" \
  >/dev/null 2>&1 && echo "    main requires CI to pass" \
  || echo "    skipped (branch protection needs a paid plan on private repos)"

cat <<MSG

Done. https://github.com/$OWNER/$REPO

Next:
  git switch -c feat/fish-game-render
  # ... work ...
  git commit -m "feat(fish): render the pond in Flame"
  git push
  gh pr create --fill
MSG
