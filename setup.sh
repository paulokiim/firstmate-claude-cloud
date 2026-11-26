#!/usr/bin/env bash
# Instala o setup de usuário do Claude Code: regras globais (~/.claude/CLAUDE.md),
# os subagentes do roteamento de modelos (~/.claude/agents/) e o hook que recusa
# PR sem veredito aprovado do no-mistakes.
# Pode rodar várias vezes; o resultado é sempre o mesmo.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="$HOME/.claude"
hook="$claude_dir/hooks/require-no-mistakes.sh"
settings="$claude_dir/settings.json"

command -v jq >/dev/null || { echo "setup.sh: jq não encontrado; instale jq e rode de novo" >&2; exit 1; }

mkdir -p "$claude_dir/hooks" "$claude_dir/agents"

# Instala um arquivo do repositório. Um arquivo diferente que já exista no destino
# (ex.: num computador pessoal) fica salvo ao lado como .bak.
install_file() {
  local src="$1" dest="$2"
  if [ -f "$dest" ] && ! cmp -s "$src" "$dest"; then
    cp "$dest" "$dest.bak"
  fi
  install -m 644 "$src" "$dest"
}

install_file "$repo_dir/claude/CLAUDE.md" "$claude_dir/CLAUDE.md"
# Só os agentes com estes nomes; outros agentes do usuário ficam como estão.
for agent in "$repo_dir"/claude/agents/*.md; do
  install_file "$agent" "$claude_dir/agents/$(basename "$agent")"
done
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

echo "setup.sh: CLAUDE.md, agentes e hook do no-mistakes instalados em $claude_dir"
