# Como resolver o brilho da tela (backlight) no Samsung RV410 no Linux

Se você tem um notebook **Samsung RV410** (ou RV510, S3510, E3510 — são praticamente o mesmo modelo por dentro) e instalou Linux (testado no Lubuntu 24.04), pode ter notado que:

- As teclas de brilho (Fn + setas) até fazem "alguma coisa" na tela, mas parece que só muda o contraste, não a luz de verdade.
- A tela nunca fica realmente escura nem realmente clara.
- Nas configurações do sistema, aparece "Backlight: 0", como se o computador nem soubesse que existe uma luz de fundo para controlar.

Boa notícia: **isso tem solução simples**, e não precisa instalar nada extra nem mexer em hardware. É só uma configuração errada que "avisa" o Linux para não usar o controle de brilho certo.

### Atalho: use os scripts prontos deste repositório

Se preferir não editar nada manualmente, este repositório traz dois scripts:

| Script | Para que serve |
|---|---|
| `fix-backlight.sh` | Aplica a correção sozinho. Faz backup, mostra o que vai mudar, **pergunta "s/n" antes de cada passo importante**, roda o `update-grub` e verifica o resultado. |
| `check-backlight.sh` | Verifica, depois de reiniciar, se o controle de brilho foi reconhecido. |

O `fix-backlight.sh` tem alguns modos, pensados para todos os níveis de confiança:

| Modo | O que faz |
|---|---|
| `./fix-backlight.sh` | Modo normal: **pede a senha do `sudo` logo no início** e aplica a correção com perguntas s/n antes de cada passo. |
| `./fix-backlight.sh --dry-run` | **Ensaio geral**: mostra o que seria alterado, sem tocar em nada. Não precisa de senha. |
| `./fix-backlight.sh --status` | **Raio-x**: mostra em que estágio a correção está (linha do GRUB, backup, se o `update-grub` já rodou, se o kernel já reconhece o backlight). Não precisa de senha. |
| `./fix-backlight.sh --rollback` | Desfaz a correção inteira, restaurando o backup (pede a senha do `sudo` no início). |
| `./fix-backlight.sh --yes` | Igual ao modo normal, mas não pergunta nada (usa "sim" em tudo). Para quem já entende e só quer resolver. |

> **Por que o script pede a senha do `sudo` no começo?** Porque editar `/etc/default/grub` e rodar `update-grub` exigem permissão de administrador. Em vez de ele falhar no meio (quando você já viu metade do processo), ele **anda até o terminal pedir a senha uma única vez logo na largada**, e só depois começa as verificações. Se preferir, pode continuar usando `sudo ./fix-backlight.sh` — ele detecta que já está com privilégios e não pede nada de novo.

Passo a passo com os scripts:

```bash
cd ~/rv410-backlight-fix     # troque pelo caminho real da pasta onde você baixou o guia
./fix-backlight.sh --dry-run     # opcional: ensaio geral, sem tocar em nada
./fix-backlight.sh               # vai pedir a senha do sudo e aplicar
sudo reboot
```

Depois de reiniciar, o terminal reabre no seu diretório pessoal. Para verificar, navegue de novo até a pasta ou use o caminho completo:

```bash
cd ~/rv410-backlight-fix && ./check-backlight.sh
```

E, se quiser voltar atrás (desfazer a correção):

```bash
cd ~/rv410-backlight-fix
./fix-backlight.sh --rollback   # também pede a senha do sudo
sudo reboot
```

#### O que as perguntas do script significam

Quando você roda `./fix-backlight.sh`, ele **primeiro pede a senha do `sudo`** (para os modos que precisam de privilégio) e depois não altera nada sem avisar. Ele segue esta sequência, esperando você responder **s** (sim) ou **n** (não) em cada etapa:

0. **Confere as dependências.** Verifica se os programas necessários (grep, sed, `lspci`, `update-grub`, etc.) estão instalados. Se faltar algum, ele **já mostra o comando de instalação** (ex: `sudo apt install pciutils grub2-common`) e só continua depois que você instalar.
1. **Confere o hardware — o computador certo.** Ele olha dois sinais: a **placa de vídeo** (para confirmar Intel GMA 4500MHD/GM45) e o **modelo** lido do firmware (`Fabricante`/`Modelo` da BIOS). Se o aparelho *não* parecer o alvo deste guia, ele avisa e pergunta **"Quer continuar mesmo assim?"** — nada trava, você decide.
2. Mostra a linha atual do GRUB e a linha que ficará no lugar, e pergunta: "Aplicar essa mudança?".
3. Antes, faz um backup automático do arquivo original (`grub.bak`) — para poder desfazer depois.
4. Percebe que editou o arquivo e pergunta: "Rodar `update-grub` agora?" (sem isso, o computador ignora a mudança — responda **s**).
5. Depois de rodar, verifica sozinho se o resultado está no `grub.cfg`.
6. Pergunta se você quer **reiniciar agora** (o brilho só muda depois que o computador liga de novo).

Responder `n` em qualquer etapa **não estraga nada** — ele para no lugar exato, informa o que ficou faltando fazer manualmente, e você pode continuar quando quiser.

#### E se o script disser que faltam componentes?

É só instalar. No Lubuntu/Debian/Ubuntu, abra o terminal e rode o comando que ele sugeriu:

```bash
sudo apt update
sudo apt install pciutils grub2-common
```

Depois repita `./fix-backlight.sh` normalmente. O próprio script faz essa checagem sozinho antes de qualquer outra coisa — você não precisa aprender esses comandos de cor.

#### Por que o script "verifica o modelo do computador"?

Porque a correção só faz sentido no notebook certo. O chip de vídeo que falha (Intel GMA 4500MHD) é o mesmo em vários Samsung RV410/RV510/S3510/E3510 da época — e é *muito* melhor o script avisar "seu aparelho não parece ser o do guia" do que você mexer à toa e chegar à conclusão errada. A checagem é apenas informativa (no modo `--status` e `--dry-run`) e, no modo de aplicar, você continua informado de que escolheu seguir mesmo assim.

> O restante deste guia explica o passo a passo manual, que é útil para entender *o que* está acontecendo — e é o mesmo raciocínio que o script usa internamente.

## Por que isso acontece?

De forma bem simples: o Linux tem um jeito nativo (de fábrica) de controlar a luz de fundo dessa placa de vídeo (Intel GMA 4500MHD). Só que, em algum momento, alguém (ou alguma tentativa de configuração anterior) adicionou uma instrução que **desliga esse controle de propósito**. É como se você tivesse, sem querer, dito para o computador: "não controle o brilho de jeito nenhum" — e ele obedeceu.

A solução é apagar essa instrução e trocar por outra que diz: "use o controle de brilho que já vem pronto".

## O que você vai fazer

Vamos editar um arquivo de configuração do sistema (chamado GRUB — é o programa que aparece por uma fração de segundo antes do Linux carregar) e trocar uma palavrinha nele.

## Antes de começar: confirme que este guia é para o seu notebook

Reserve 1 minuto para verificar se o problema do seu aparelho é o mesmo, para não mexer à toa. Abra o terminal e rode:

```bash
lspci | grep -i vga
```

Se aparecer algo com **Intel GMA 4500MHD**, **GM45**, **Intel Corporation Mobile 4 Series Chipset** ou similar, pode continuar — este guia serve para você.

Se a placa for de outra marca (AMD, NVIDIA, outra Intel mais nova), o problema provavelmente tem outra causa. Não desista: pesquise por `nome_do_seu_modelo` + `linux backlight` na internet. Você pode, ainda assim, acompanhar o guia por curiosidade — mas as teclas de brilho podem continuar sem funcionar.

### Passo 1: Abra o terminal

No Lubuntu, procure por "Terminal" no menu de aplicativos, ou aperte `Ctrl + Alt + T`.

### Passo 2: Faça uma cópia de segurança do arquivo (por precaução)

Cole este comando e aperte Enter:

```bash
sudo cp /etc/default/grub /etc/default/grub.bak
```

Isso simplesmente faz uma cópia do arquivo original, guardando-a com o nome `grub.bak`. Se algo der errado mais tarde, dá para voltar ao original facilmente. O sistema vai pedir sua senha — pode digitar normalmente (ela não aparece na tela, é assim mesmo, não travou).

### Passo 3: Abra o arquivo para editar

```bash
sudo nano /etc/default/grub
```

Isso abre o arquivo dentro do próprio terminal, num programinha simples chamado `nano`.

### Passo 4: Encontre a linha certa e edite

Procure uma linha parecida com esta (pode variar um pouco):

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
```

ou, se você já mexeu nisso antes, pode ter algo como:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_backlight=none"
```

Troque para que fique assim (apagando qualquer `acpi_backlight=alguma_coisa` que já exista e colocando este no lugar):

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_backlight=native"
```

Essa palavra `native` é o segredo: ela diz para o Linux "use o controle de brilho que já vem pronto para essa placa de vídeo".

### Passo 5: Salve e feche

No `nano`:
- Aperte `Ctrl + O` para salvar (depois aperte Enter para confirmar o nome do arquivo)
- Aperte `Ctrl + X` para sair

### Passo 6: Aplique a mudança

```bash
sudo update-grub
```

Isso "avisa" o sistema para ler a nova configuração e prepará-la para o próximo ligamento do computador. Sem esse passo, a edição do arquivo não tem efeito nenhum.

### Passo 7: Reinicie o computador

```bash
sudo reboot
```

### Passo 8: Confira se funcionou

Depois que o computador ligar de novo, abra o terminal outra vez e digite:

```bash
ls /sys/class/backlight/
```

Se aparecer a palavra **`intel_backlight`** na tela, deu certo! Isso significa que o Linux agora reconhece e controla a luz de fundo de verdade.

Teste as teclas Fn de brilho (aumentar/diminuir) — elas devem funcionar normalmente agora, clareando e escurecendo a tela de verdade, não só mudando o contraste.

## Resumindo tudo em um bloco só

Se você já sabe o que está fazendo e só quer copiar e colar (funciona bem em instalação nova, sem nenhuma configuração de brilho feita antes):

```bash
sudo cp /etc/default/grub /etc/default/grub.bak
sudo sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/( )?acpi_backlight=[^ "]+//g' /etc/default/grub
sudo sed -i -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="([^"]*)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 acpi_backlight=native"/' /etc/default/grub
sudo update-grub
sudo reboot
```

## E se eu já tentei outras coisas antes (driver customizado, script de brilho, etc.)?

Se você tentou compilar algum driver chamado `samsung_backlight` ou fez scripts que usam o comando `setpci` para mudar o brilho manualmente, pode remover tudo isso — não é mais necessário depois dessa correção:

```bash
sudo rmmod samsung_backlight 2>/dev/null
```

Esse comando remove o driver customizado da memória, caso ele esteja carregado (se não estiver, ele só mostra uma mensagem sem importância, que é ignorada).

## Isso funciona só nesse notebook?

Essa correção serve especificamente para notebooks com a placa de vídeo **Intel GMA 4500MHD** (também chamada de "GM45"), que é a mesma usada em vários modelos Samsung da época (R410, R510, R518, R470, entre outros). Se seu notebook usa outra placa de vídeo, o problema pode ter uma causa diferente.

## Aviso sobre um detalhe secundário

Em alguns casos, ao segurar a tecla de brilho por muito tempo (em vez de apertar rapidinho), pode haver um pequeno atraso até a tela realmente mudar. Isso é um detalhe separado, relacionado a como o sistema processa cliques repetidos de tecla — não afeta o funcionamento normal do dia a dia, e tem solução à parte se incomodar muito.

## Se algo der errado: como voltar atrás

Cada passo deste guia guarda uma "rede de segurança":

- Se você usou os **scripts**, rode: `./fix-backlight.sh --rollback` e reinicie.
- Se você fez **manualmente**, restaure a cópia de segurança que fez no início:

```bash
sudo cp /etc/default/grub.bak /etc/default/grub
sudo update-grub
sudo reboot
```

Isso devolve o arquivo exatamente como estava e desfaz qualquer efeito da correção.

## O que fazer se não funcionou (ainda)

Você reiniciou, rodou o `check-backlight.sh` (ou o `ls /sys/class/backlight/`) e o brilho continua ruim? Antes de desistir, tente nesta ordem:

1. **Confirme que o `update-grub` rodou de verdade** (sem esse passo, nada muda):

```bash
sudo update-grub
sudo reboot
```

2. **Troque `native` por `vendor`.** Algumas placas (especialmente notebooks Samsung da época) respondem melhor a esse modo. Edite o arquivo de novo (passo 3) e deixe a linha assim:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_backlight=vendor"
```

Depois: `sudo update-grub && sudo reboot`.

3. **Use a opção moderna, em vez da `acpi_backlight`.** Alguns kernels mais novos preferem esta:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash video.use_native_backlight=1"
```

Depois: `sudo update-grub && sudo reboot`.

4. **Teste combinações.** As duas opções podem ser combinadas:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash video.use_native_backlight=1 acpi_backlight=vendor"
```

5. **Limpou o `acpi_backlight=none`?** Se uma instalação anterior deixou um valor sobrando (ex: uma segunda linha com `acpi_backlight=none` em outro lugar do `/etc/default/grub`), remova essa palavra de todas as linhas antes de testar de novo.

> Importante: testou uma opção, reiniciou e não resolveu, **troque para a próxima** — não misture várias sem critério, pois aí fica impossível saber qual funcionou.

Se nenhuma funcionar, é um motivo válido para **abrir uma Issue** neste repositório usando o template de bug. Isso ajuda quem tem o mesmo problema a encontrar uma solução.

## Perguntas frequentes (FAQ)

**Tenho que fazer todos os passos manuais do guia?**
Não. Se quiser o caminho rápido, use os scripts (veja a seção no início). Os passos manuais existem para você entender o que acontece por trás.

**Preciso desse repositório sempre?**
Não. Depois que aplica a correção uma vez, ela fica gravada no GRUB do computador. Este repositório serve como guia, referência e para desfazer a mudança se precisar.

**A correção some quando atualiza o sistema?**
Não. Atualizações normais do sistema não apagam o `acpi_backlight=native` do GRUB. É raro precisar reaplicar (só em situações bem específicas, como reinstalação).

**Funciona no RV510, S3510, E3510, R518 ou R470?**
Muito provavelmente sim — eles usam a mesma placa de vídeo (Intel GMA 4500MHD). O guia — e os scripts — foram escritos para o RV410, mas a lógica é idêntica nesses modelos. Se você testou em outro modelo, considere abrir uma Issue confirmando que funcionou, para ajudar os demais.

**E se eu removi o driver customizado `samsung_backlight` e agora não consigo nem ligar a tela?**
A remoção do driver só afeta o módulo em memória e é segura. Se houver problema, um `sudo reboot` limpa tudo e a correção deste guia assume o controle.

**Posso usar este conteúdo como base para meu próprio guia?**
Sim, desde que dê os créditos devidos, como exige a licença deste repositório (CC BY 4.0 — veja abaixo). Basta citar a fonte, por exemplo: "Baseado no guia de [henriquegouveia85/rv410-backlight-fix](https://github.com/henriquegouveia85/rv410-backlight-fix) (licença CC BY 4.0)".

## Licença

Este repositório está licenciado sob a **Creative Commons Attribution 4.0 International (CC BY 4.0)** — o texto completo está no arquivo `LICENSE`.

Em resumo, você pode usar, copiar, adaptar e publicar este conteúdo livremente, **desde que dê os devidos créditos à fonte** (indicando quem criou e de onde veio o material). Se modificar, indique o que mudou e mantenha a mesma licença ao redistribuir.
