#!/usr/bin/env bash
# Hook PreToolUse do no-mistakes na nuvem.
# Bloqueia a criação de PR pelo conector do GitHub quando não existe veredito
# aprovado do verificador no-mistakes para o commit exato do branch da PR.
# O veredito fica em <git-common-dir>/no-mistakes/<sha>.json (skill no-mistakes-cloud).
set -uo pipefail

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

command -v jq >/dev/null 2>&1 || { echo "require-no-mistakes: jq não encontrado" >&2; exit 2; }

input=$(cat)
owner=$(jq -r '.tool_input.owner // empty' <<<"$input")
repo=$(jq -r '.tool_input.repo // empty' <<<"$input")
head=$(jq -r '.tool_input.head // empty' <<<"$input")
if [[ "$head" == *:* ]]; then
  head_owner=${head%%:*}
  [ "${head_owner,,}" = "${owner,,}" ] \
    || deny "no-mistakes: PR a partir de fork ($head) não é suportada; o veredito só vale para branches de $owner/$repo."
  head=${head#*:}
fi

[ -n "$owner" ] && [ -n "$repo" ] && [ -n "$head" ] || deny "no-mistakes: não consegui ler owner, repo e head da chamada de criação de PR."

repo_dir=""
for d in "${CLAUDE_PROJECT_DIR:-}" "$PWD" "$PWD/$repo" "$(dirname "$PWD")/$repo" "/home/user/$repo" "$HOME/$repo"; do
  [ -n "$d" ] && [ -d "$d" ] || continue
  url=$(git -C "$d" config --get remote.origin.url 2>/dev/null) || continue
  url=${url%.git}
  case "${url,,}" in
    *"/${owner,,}/${repo,,}"|*":${owner,,}/${repo,,}") repo_dir=$d; break ;;
  esac
done
[ -n "$repo_dir" ] || deny "no-mistakes: não achei o clone local de $owner/$repo para conferir o veredito. Rode a PR a partir de uma sessão com esse repositório."

sha=$(git -C "$repo_dir" rev-parse --verify --quiet "refs/heads/$head^{commit}" || git -C "$repo_dir" rev-parse --verify --quiet "refs/remotes/origin/$head^{commit}") \
  || deny "no-mistakes: o branch '$head' não existe no clone local de $owner/$repo."

# Consulta o remoto de verdade: uma ref origin/<branch> local pode estar velha.
remote_out=$(timeout 30 git -C "$repo_dir" ls-remote --exit-code origin "refs/heads/$head" 2>/dev/null) \
  || deny "no-mistakes: não consegui confirmar no remoto o branch '$head' de $owner/$repo. Faça push do commit verificado e tente de novo."
remote_sha=${remote_out%%[[:space:]]*}
[ "$remote_sha" = "$sha" ] \
  || deny "no-mistakes: o branch '$head' no remoto ($remote_sha) não é o commit local $sha. Faça push exatamente do commit verificado antes de abrir a PR."

common=$(git -C "$repo_dir" rev-parse --path-format=absolute --git-common-dir)
verdict="$common/no-mistakes/$sha.json"
[ -f "$verdict" ] || deny "no-mistakes: não há veredito para $sha ($owner/$repo, branch $head). Rode os checks com a skill no-mistakes-cloud antes de abrir a PR."

status=$(jq -r --arg sha "$sha" 'if .sha == $sha then .status else "sha-divergente" end' "$verdict" 2>/dev/null || echo "invalido")
case "$status" in
  aprovado|dispensado) exit 0 ;;
  reprovado) deny "no-mistakes: o veredito de $sha é reprovado. Resolva os achados em $verdict, commite e rode os checks de novo." ;;
  *) deny "no-mistakes: veredito inválido em $verdict (status: $status). Rode os checks de novo." ;;
esac
