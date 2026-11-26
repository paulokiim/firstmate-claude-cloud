# firstmate-claude-cloud

Setup de usuário do Claude Code para os ambientes de nuvem (claude.ai/code). Toda sessão de um ambiente com o bootstrap abaixo começa com:

- `~/.claude/CLAUDE.md`: as regras globais de engenharia, válidas em qualquer projeto ([claude/CLAUDE.md](claude/CLAUDE.md)).
- `~/.claude/hooks/require-no-mistakes.sh`: hook `PreToolUse` que recusa `mcp__github__create_pull_request` sem veredito aprovado do verificador no-mistakes para o commit exato da branch ([claude/hooks/require-no-mistakes.sh](claude/hooks/require-no-mistakes.sh)). O veredito é gravado pela skill `no-mistakes-cloud` da conta.

As regras de orquestração (coordenador e threads) ficam nas instruções de cada projeto, não aqui.

## Bootstrap

Cole no setup script de cada ambiente (engrenagem ao lado do ambiente, campo "Setup script"):

```sh
rm -rf "$HOME/.firstmate-claude-cloud"
git clone --depth 1 https://github.com/paulokiim/firstmate-claude-cloud.git "$HOME/.firstmate-claude-cloud"
bash "$HOME/.firstmate-claude-cloud/setup.sh"
```

Cada sessão nova baixa a versão atual da `main`. Não existe configuração da conta que aplique isso sozinho a ambientes novos: todo ambiente novo precisa dessas três linhas uma vez.

Se o clone ou o setup falhar, o setup script para com erro e a sessão avisa que o setup falhou.

No computador pessoal dá para rodar o mesmo `setup.sh` uma vez. Um `~/.claude/CLAUDE.md` diferente que já exista é salvo como `CLAUDE.md.bak`.

## Testes

```sh
bash tests/setup_test.sh
bash tests/require-no-mistakes.test.sh
```

Requisitos: `bash`, `git` e `jq`.
