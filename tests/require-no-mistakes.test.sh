#!/usr/bin/env bash
# Testa o hook require-no-mistakes contra um repositório git real, com um
# remoto local no lugar do GitHub. Roda como gate do .no-mistakes.yaml.
set -uo pipefail
hook="$(cd "$(dirname "$0")/.." && pwd)/claude/hooks/require-no-mistakes.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0

export GIT_CONFIG_GLOBAL="$tmp/gitconfig" GIT_CONFIG_NOSYSTEM=1
git config --global user.email t@example.com
git config --global user.name teste
git config --global init.defaultBranch main
git config --global url."$tmp/remote.git".insteadOf https://github.com/acme/app

git init -q --bare "$tmp/remote.git"
git init -q "$tmp/app"
cd "$tmp/app" || exit 1
git remote add origin https://github.com/acme/app
git commit -q --allow-empty -m base && git push -q origin main
git checkout -q -b feat && git commit -q --allow-empty -m feat
sha=$(git rev-parse HEAD)
verdicts="$(git rev-parse --path-format=absolute --git-common-dir)/no-mistakes"

decide() { # decide <cwd> <head> -> allow | deny
  local out
  out=$(printf '{"tool_input":{"owner":"acme","repo":"app","head":"%s","base":"main"}}' "$2" \
    | (cd "$1" && env -u CLAUDE_PROJECT_DIR "$hook")) || { echo "erro"; return; }
  if [ -z "$out" ]; then echo allow
  else jq -r '.hookSpecificOutput.permissionDecision' <<<"$out"; fi
}
expect() { # expect <nome> <esperado> <cwd> <head>
  local got; got=$(decide "$3" "$4")
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FALHA $1: esperado $2, veio $got"; fail=1; fi
}
verdict() { mkdir -p "$verdicts"; printf '{"sha":"%s","status":"%s"}' "$1" "$2" > "$verdicts/$1.json"; }

expect "sem push nega" deny "$tmp/app" feat
git push -q origin feat
expect "sem veredito nega" deny "$tmp/app" feat
verdict "$sha" reprovado
expect "veredito reprovado nega" deny "$tmp/app" feat
verdict "$sha" aprovado
expect "veredito aprovado permite" allow "$tmp/app" feat
expect "head owner:branch permite" allow "$tmp/app" acme:feat
expect "head de fork nega" deny "$tmp/app" outrofork:feat
expect "sessão no diretório pai permite" allow "$tmp" feat
verdict "$sha" dispensado
expect "dispensado permite" allow "$tmp/app" feat
printf '{"sha":"outro","status":"aprovado"}' > "$verdicts/$sha.json"
expect "veredito de outro sha nega" deny "$tmp/app" feat
verdict "$sha" aprovado
git commit -q --allow-empty -m depois
expect "commit local novo sem veredito nega" deny "$tmp/app" feat
git reset -q --hard "$sha"
git clone -q https://github.com/acme/app "$tmp/outro" && (cd "$tmp/outro" && git checkout -q feat \
  && git commit -q --allow-empty -m remoto && git push -q origin feat)
expect "remoto à frente do local nega, mesmo com origin/feat velho" deny "$tmp/app" feat
expect "branch inexistente nega" deny "$tmp/app" nada

exit $fail
