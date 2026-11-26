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

# Registra o hook uma vez só, preservando o resto do settings.json.
[ -s "$settings" ] || echo '{}' > "$settings"
tmp="$(mktemp "$settings.XXXXXX")"
jq --arg cmd "$hook" '.hooks.PreToolUse = ((.hooks.PreToolUse // [])
  | map(select(.hooks | all(.command != $cmd))))
  + [{matcher: "mcp__github__create_pull_request", hooks: [{type: "command", command: $cmd}]}]' \
  "$settings" > "$tmp"
mv "$tmp" "$settings"

echo "setup.sh: CLAUDE.md e hook do no-mistakes instalados em $claude_dir"
