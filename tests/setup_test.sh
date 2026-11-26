#!/usr/bin/env bash
# Roda o setup.sh num $HOME temporário e confere o resultado.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FALHOU: $*" >&2; exit 1; }

home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT
hook="$home/.claude/hooks/require-no-mistakes.sh"
settings="$home/.claude/settings.json"

# settings.json com conteúdo do usuário e um CLAUDE.md pessoal já existentes.
mkdir -p "$home/.claude"
echo '{"model":"x","hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"/outro.sh"}]}]}}' > "$settings"
echo "pessoal" > "$home/.claude/CLAUDE.md"

HOME="$home" bash "$repo_dir/setup.sh" >/dev/null
HOME="$home" bash "$repo_dir/setup.sh" >/dev/null

cmp -s "$repo_dir/claude/CLAUDE.md" "$home/.claude/CLAUDE.md" || fail "CLAUDE.md não foi instalado"
[ "$(cat "$home/.claude/CLAUDE.md.bak")" = "pessoal" ] || fail "CLAUDE.md anterior não foi preservado"
[ -x "$hook" ] || fail "hook não instalado ou sem permissão de execução"
cmp -s "$repo_dir/claude/hooks/require-no-mistakes.sh" "$hook" || fail "hook diferente do repositório"

[ "$(jq -r .model "$settings")" = "x" ] || fail "settings.json perdeu campos existentes"
[ "$(jq '[.hooks.PreToolUse[] | select(.matcher == "Bash")] | length' "$settings")" = 1 ] || fail "hook existente foi removido"
n="$(jq --arg c "$hook" '[.hooks.PreToolUse[] | select(.matcher == "mcp__github__create_pull_request") | .hooks[] | select(.command == $c)] | length' "$settings")"
[ "$n" = 1 ] || fail "hook do no-mistakes registrado $n vezes, esperado 1"

# Sem settings.json prévio também funciona.
home2="$(mktemp -d)"
trap 'rm -rf "$home" "$home2"' EXIT
HOME="$home2" bash "$repo_dir/setup.sh" >/dev/null
[ "$(jq '.hooks.PreToolUse | length' "$home2/.claude/settings.json")" = 1 ] || fail "settings.json novo incorreto"

echo "ok: setup.sh"
