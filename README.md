# Como resolver o brilho da tela (backlight) no Samsung RV410 no Linux

Se você tem um notebook **Samsung RV410** (ou RV510, S3510, E3510 — são praticamente o mesmo modelo por dentro) e instalou Linux (testado no Lubuntu 24.04), pode ter notado que:

- As teclas de brilho (Fn + setas) até fazem "alguma coisa" na tela, mas parece que só muda o contraste, não a luz de verdade.
- A tela nunca fica realmente escura nem realmente clara.
- Nas configurações do sistema, aparece "Backlight: 0", como se o computador nem soubesse que existe uma luz de fundo para controlar.

Boa notícia: **isso tem solução simples**, e não precisa instalar nada extra nem mexer em hardware. É só uma configuração errada que "avisa" o Linux para não usar o controle de brilho certo.

## Por que isso acontece?

De forma bem simples: o Linux tem um jeito nativo (de fábrica) de controlar a luz de fundo dessa placa de vídeo (Intel GMA 4500MHD). Só que, em algum momento, alguém (ou alguma tentativa de configuração anterior) adicionou uma instrução que **desliga esse controle de propósito**. É como se você tivesse, sem querer, dito para o computador: "não controle o brilho de jeito nenhum" — e ele obedeceu.

A solução é apagar essa instrução e trocar por outra que diz: "use o controle de brilho que já vem pronto".

## O que você vai fazer

Vamos editar um arquivo de configuração do sistema (chamado GRUB — é o programa que aparece por uma fração de segundo antes do Linux carregar) e trocar uma palavrinha nele.

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
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 acpi_backlight=native"/' /etc/default/grub
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
