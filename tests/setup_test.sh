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
# Um Explore pessoal (mesmo nome de um agente do repo) e um agente só do usuário.
mkdir -p "$home/.claude/agents"
echo "explore pessoal" > "$home/.claude/agents/Explore.md"
echo "meu agente" > "$home/.claude/agents/meu.md"

HOME="$home" bash "$repo_dir/setup.sh" >/dev/null
HOME="$home" bash "$repo_dir/setup.sh" >/dev/null

cmp -s "$repo_dir/claude/CLAUDE.md" "$home/.claude/CLAUDE.md" || fail "CLAUDE.md não foi instalado"
[ "$(cat "$home/.claude/CLAUDE.md.bak")" = "pessoal" ] || fail "CLAUDE.md anterior não foi preservado"
# Roteamento de modelos: cada agente instalado com o modelo da tabela do Paulo.
model_of() { sed -n '2,/^---$/s/^model: *//p' "$1"; }
for pair in ui-designer:fable architect:opus implementer:sonnet Explore:sonnet; do
  name="${pair%%:*}" want="${pair#*:}"
  f="$home/.claude/agents/$name.md"
  [ -f "$f" ] || fail "agente $name não instalado"
  [ "$(sed -n '2,/^---$/s/^name: *//p' "$f")" = "$name" ] || fail "agente $name com name errado no frontmatter"
  [ "$(model_of "$f")" = "$want" ] || fail "agente $name com modelo '$(model_of "$f")', esperado $want"
done
[ "$(find "$home/.claude/agents" -name '*.md' | wc -l)" = 5 ] || fail "agentes instalados a mais ou a menos"
[ "$(cat "$home/.claude/agents/Explore.md.bak")" = "explore pessoal" ] || fail "Explore anterior não foi preservado"
[ "$(cat "$home/.claude/agents/meu.md")" = "meu agente" ] || fail "agente do usuário foi alterado"
explore_tools="$(sed -n '2,/^---$/s/^tools: *//p' "$home/.claude/agents/Explore.md")"
case ", $explore_tools," in *", Edit,"*|*", Write,"*|*", NotebookEdit,"*) fail "Explore não é só leitura: $explore_tools" ;; esac
[ -n "$explore_tools" ] || fail "Explore sem lista de ferramentas herdaria as de escrita"

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

# Outro hook do usuário na mesma entrada do hook do no-mistakes continua lá.
home3="$(mktemp -d)"
trap 'rm -rf "$home" "$home2" "$home3"' EXIT
mkdir -p "$home3/.claude"
hook3="$home3/.claude/hooks/require-no-mistakes.sh"
jq -n --arg h "$hook3" '{hooks:{PreToolUse:[{matcher:"mcp__github__create_pull_request",hooks:[{type:"command",command:"/meu.sh"},{type:"command",command:$h}]}]}}' > "$home3/.claude/settings.json"
HOME="$home3" bash "$repo_dir/setup.sh" >/dev/null
s3="$home3/.claude/settings.json"
[ "$(jq '[.hooks.PreToolUse[].hooks[] | select(.command == "/meu.sh")] | length' "$s3")" = 1 ] || fail "hook do usuário na mesma entrada foi apagado"
[ "$(jq --arg c "$hook3" '[.hooks.PreToolUse[].hooks[] | select(.command == $c)] | length' "$s3")" = 1 ] || fail "hook do no-mistakes duplicado na entrada compartilhada"

# settings.json inválido para com mensagem clara e não deixa temporário.
home4="$(mktemp -d)"
trap 'rm -rf "$home" "$home2" "$home3" "$home4"' EXIT
mkdir -p "$home4/.claude"
echo '{quebrado' > "$home4/.claude/settings.json"
if err="$(HOME="$home4" bash "$repo_dir/setup.sh" 2>&1 >/dev/null)"; then fail "setup.sh aceitou settings.json inválido"; fi
case "$err" in *"não é um objeto JSON válido"*) ;; *) fail "mensagem de erro sem citar o settings.json: $err" ;; esac
[ -z "$(find "$home4/.claude" -maxdepth 1 -name 'settings.json.*')" ] || fail "arquivo temporário ficou para trás"

# Entrada PreToolUse sem .hooks não quebra o setup e é preservada.
home5="$(mktemp -d)"
trap 'rm -rf "$home" "$home2" "$home3" "$home4" "$home5"' EXIT
mkdir -p "$home5/.claude"
echo '{"hooks":{"PreToolUse":[{"matcher":"Bash"}]}}' > "$home5/.claude/settings.json"
HOME="$home5" bash "$repo_dir/setup.sh" >/dev/null || fail "entrada sem .hooks quebrou o setup"
[ "$(jq '.hooks.PreToolUse | length' "$home5/.claude/settings.json")" = 2 ] || fail "entrada sem .hooks não foi preservada"

echo "ok: setup.sh"
