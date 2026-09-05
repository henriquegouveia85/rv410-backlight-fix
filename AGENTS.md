# AGENTS.md — Contexto operacional do projeto

> Este arquivo é lido automaticamente por agentes de IA (como opencode/Claude/etc.)
> no início de cada sessão de trabalho nesta pasta. Ele é um resumo do projeto e das
> convenções de manutenção, para que qualquer nova ferramenta consiga "começar por aí".

## O que é este projeto

Repositório `rv410-backlight-fix`: documentação + scripts que corrigem o problema de
**backlight (brilho) em notebooks Samsung RV410** (também RV510, S3510, E3510, e outros
com a mesma base) rodando Linux. A causa é uma configuração de GRUB que desativa o
controle nativo de brilho da Intel GMA 4500MHD (GM45); a solução é trocar
`acpi_backlight=...` por `acpi_backlight=native`.

Repositório público (já publicado, com vários commits):

```
https://github.com/henriquegouveia85/rv410-backlight-fix
```

## Estado atual (concluído)

- O repositório **já está publicado**: README, scripts, licença e templates estão
  commitados na branch `main` e com push feito para `origin`.
- Não há tarefa de publicação pendente. Sessões futuras são de **manutenção**.

## Estrutura de arquivos

| Arquivo | Papel |
|---|---|
| `README.md` | Guia principal, em português simples e didático, para o público leigo. É o "produto" do repositório. |
| `AGENTS.md` | Este arquivo: contexto operacional para agentes de IA que trabalharem na pasta. |
| `fix-backlight.sh` | Script que aplica/desfaz a correção. Modos: `--status` (raio-x, sem root), `--dry-run` (ensaio, sem root), `--rollback` (desfaz), `--yes` (sem perguntas), e padrão (interativo). Pede `sudo` no início. Verifica dependências e hardware (placa + modelo DMI). |
| `check-backlight.sh` | Verifica após o reboot se o kernel reconheceu o backlight (`/sys/class/backlight/`). |
| `LICENSE` | **CC BY 4.0** — uso livre, mas com **atribuição obrigatória**. |
| `.github/ISSUE_TEMPLATE/` | Templates de issue (bug e feature). |
| `.github/PULL_REQUEST_TEMPLATE.md` | Template de pull request (checkbox de atribuição). |
| `.gitignore` | Ignora arquivos temporários/operacionais (vazio por enquanto). |

## Convenções de manutenção

- **Linguagem:** todo conteúdo voltado ao usuário final (README, mensagens dos scripts)
  deve ser em **português simples**, didático, sem jargão técnico desnecessário.
- **Licença:** o material é **CC BY 4.0** — qualquer conteúdo adaptado de terceiros, ou
  qualquer redistribuição do material, exige **atribuição**. Novos conteúdos copiados de
  outras fontes devem citar a origem (para leitura: `LICENSE`).
- **Scripts em bash:** manter o estilo atual (funções pequenas, `set -euo pipefail`,
  camadas de segurança: dry-run → backup → confirmação s/N → verificação → rollback).
- **Verificar antes de concluir:** rodar `bash -n fix-backlight.sh check-backlight.sh`.
- **Git:** commits em português, mensagem curta descrevendo a mudança. O usuário pediu
  para **sempre commitar** (e, via de regra, dar push) após concluir uma mudança.
  Nunca commitar segredos/tokens.

## Notas para quem for mexer nos scripts

- `fix-backlight.sh` faz backup em `/etc/default/grub.bak` antes de editar e o
  `--rollback` restaura.
- As verificações do script são informativas e seguras: `--dry-run` e `--status` não
  exigem root; os modos de aplicar/desfazer se auto-promovem via `sudo`.
- Não rodar `apply_fix`/rollback em derradeiro sem necessidade — é o equipamento real
  do usuário. Preferir testar lógica com `--dry-run`/`--status` e validações locais.