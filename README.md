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
| `fix-backlight.sh` | Aplica a correção sozinho (faz backup, troca a configuração e roda o `update-grub`). Tem modos `--dry-run` (mostra o que faria) e `--rollback` (volta tudo ao original). |
| `check-backlight.sh` | Verifica, depois de reiniciar, se o controle de brilho foi reconhecido. |

Passo a passo com os scripts:

```bash
cd ~/rv410-backlight-fix     # troque pelo caminho real da pasta onde você baixou o guia
sudo ./fix-backlight.sh --dry-run    # opcional: veja o que será alterado
sudo ./fix-backlight.sh
sudo reboot
```

Depois de reiniciar, o terminal reabre no seu diretório pessoal. Para verificar, navegue de novo até a pasta ou use o caminho completo:

```bash
cd ~/rv410-backlight-fix && ./check-backlight.sh
```

E, se quiser voltar atrás (desfazer a correção):

```bash
cd ~/rv410-backlight-fix
sudo ./fix-backlight.sh --rollback
sudo reboot
```

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

- Se você usou os **scripts**, rode: `sudo ./fix-backlight.sh --rollback` e reinicie.
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
