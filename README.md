# firstmate-claude-cloud

Setup de usuário do Claude Code para os ambientes de nuvem (claude.ai/code). Toda sessão de um ambiente com o bootstrap abaixo começa com:

- `~/.claude/CLAUDE.md`: as regras globais de engenharia, válidas em qualquer projeto ([claude/CLAUDE.md](claude/CLAUDE.md)).
- `~/.claude/agents/`: os subagentes do roteamento de modelos ([claude/agents/](claude/agents/)). Só os arquivos com estes nomes são instalados; outros agentes seus ficam como estão.
- `~/.claude/hooks/require-no-mistakes.sh`: hook `PreToolUse` que recusa `mcp__github__create_pull_request` sem veredito aprovado do verificador no-mistakes para o commit exato da branch ([claude/hooks/require-no-mistakes.sh](claude/hooks/require-no-mistakes.sh)). O veredito é gravado pela skill `no-mistakes-cloud` da conta.

As regras de orquestração ficam nas instruções de cada projeto. A versão oficial das regras do coordenador está em [firstmate/coordenador.md](firstmate/coordenador.md): cole o arquivo inteiro nas instruções de cada projeto, depois da parte específica do projeto, e recole quando ele mudar.

## Roteamento de modelos

| Tarefa | Modelo | Thread (coordenador) | Subagente |
| --- | --- | --- | --- |
| UI/UX: telas, fluxos, mockups | Fable 5.2 | design de telas | `ui-designer` |
| Arquitetura e design, planos | Opus 5.5 | investigação que termina em plano | `architect` |
| Implementação | Sonnet 5.5 | entrega (termina em PR) | `implementer` |
| Exploração | Sonnet 5.5 | investigação factual | `Explore` (substitui o embutido, que usa Haiku) |
| Qualquer outra coisa | Opus 5.5 | mista ou em dúvida | todo outro subagente recebe `model: opus` |

São duas camadas. O coordenador escolhe o modelo da thread inteira pelo tipo dominante do trabalho ([firstmate/coordenador.md](firstmate/coordenador.md)). Dentro de qualquer sessão, uma fase de outro tipo vai para o subagente da tabela, que tem o modelo fixado no próprio arquivo, seguindo a seção "Model routing" do [claude/CLAUDE.md](claude/CLAUDE.md).

O campo `model` do `settings.json` não serve para isso na nuvem: cada sessão é aberta com `--model`, que vence o settings.

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
