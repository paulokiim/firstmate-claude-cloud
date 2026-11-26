#!/usr/bin/env bash
# Instala o setup de usuário do Claude Code: regras globais (~/.claude/CLAUDE.md)
# e o hook que recusa PR sem veredito aprovado do no-mistakes.
# Pode rodar várias vezes; o resultado é sempre o mesmo.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="$HOME/.claude"
hook="$claude_dir/hooks/require-no-mistakes.sh"
settings="$claude_dir/settings.json"

command -v jq >/dev/null || { echo "setup.sh: jq não encontrado; instale jq e rode de novo" >&2; exit 1; }

mkdir -p "$claude_dir/hooks"

# Um CLAUDE.md diferente que já exista (ex.: num computador pessoal) fica salvo ao lado.
if [ -f "$claude_dir/CLAUDE.md" ] && ! cmp -s "$repo_dir/claude/CLAUDE.md" "$claude_dir/CLAUDE.md"; then
  cp "$claude_dir/CLAUDE.md" "$claude_dir/CLAUDE.md.bak"
fi
install -m 644 "$repo_dir/claude/CLAUDE.md" "$claude_dir/CLAUDE.md"
install -m 755 "$repo_dir/claude/hooks/require-no-mistakes.sh" "$hook"

# Registra o hook uma vez só, preservando o resto do settings.json:
# tira só o comando deste hook de onde ele estiver e acrescenta uma entrada nova.
[ -s "$settings" ] || echo '{}' > "$settings"
jq -e 'type == "object"' "$settings" >/dev/null 2>&1 \
  || { echo "setup.sh: $settings não é um objeto JSON válido; corrija ou apague o arquivo e rode de novo" >&2; exit 1; }
tmp="$(mktemp "$settings.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
if ! jq --arg cmd "$hook" '
  .hooks = (.hooks // {})
  | .hooks.PreToolUse = (
      ((.hooks.PreToolUse // [])
        | map(if (.hooks | type) == "array" and any(.hooks[]; .command == $cmd)
              then (.hooks |= map(select(.command != $cmd))) | select(.hooks | length > 0)
              else . end))
      + [{matcher: "mcp__github__create_pull_request", hooks: [{type: "command", command: $cmd}]}])' \
  "$settings" > "$tmp"; then
  echo "setup.sh: não consegui registrar o hook em $settings (formato inesperado em hooks.PreToolUse)" >&2
  exit 1
fi
mv "$tmp" "$settings"

echo "setup.sh: CLAUDE.md e hook do no-mistakes instalados em $claude_dir"
