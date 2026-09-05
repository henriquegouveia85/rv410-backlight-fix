#!/usr/bin/env bash
#
# fix-backlight.sh — Aplica a correção de backlight do Samsung RV410
# (e similares com Intel GMA 4500MHD) no Linux.
#
# Este script segue o princípio de "camadas de segurança":
#   0. Verifica se os programas necessários existem (e sugere como instalá-los);
#      e confere se o computador tem a placa/modelo certo antes de mexer;
#   1. Mostra um modo de teste (--dry-run) que não altera nada;
#   2. Faz backup do arquivo antes de qualquer mudança;
#   3. Pede confirmação (sim/não) antes de cada passo importante;
#   4. Verifica o resultado depois de aplicar;
#   5. Tem modo --rollback para desfazer tudo.
#
# Uso:
#   ./fix-backlight.sh                  # aplica a correção (pede a senha do sudo no início)
#   ./fix-backlight.sh --yes            # aplica sem perguntar (idem -y)
#   ./fix-backlight.sh --dry-run        # mostra o que faria, sem mudar nada (sem sudo)
#   ./fix-backlight.sh --status         # mostra o estado atual da correção (sem sudo)
#   ./fix-backlight.sh --rollback       # desfaz a correção a partir do backup (pede sudo)
#
# Obs.: os modos de aplicar/desfazer pedem permissão de administrador (sudo)
# assim que começam — a senha é solicitada UMA vez, antes de qualquer outro passo.
#
# Opções:
#   --dry-run    Mostra o que seria alterado sem tocar em nenhum arquivo.
#   --status     Mostra o estado atual: linha do GRUB, backup, update-grub, kernel.
#   --rollback   Restaura /etc/default/grub.bak (o arquivo original, se existir).
#   --yes, -y    Não faz perguntas — usa "sim" para todas as confirmações.
#   -h, --help   Mostra esta ajuda.

set -euo pipefail

GRUB_FILE="/etc/default/grub"
BACKUP_FILE="/etc/default/grub.bak"
NEW_PARAM="acpi_backlight=native"
GRUB_CFG="/boot/grub/grub.cfg"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ASSUME_YES=0

# Pergunta "sim/não" e retorna 0 (sim) ou 1 (não).
# A letra "s" aparece em maiúsculo se "sim" for o padrão; invertemos o padrão
# em perguntas mais delicadas passando "y" como segundo argumento.
confirm() {
    local pergunta="$1"
    local resposta
    if [[ $ASSUME_YES -eq 1 ]]; then
        echo "  [--yes] Prosseguindo automaticamente."
        return 0
    fi
    while :; do
        read -r -p "$pergunta (s/N) " resposta || return 1
        case "${resposta,,}" in
            s|sim|y|yes)     return 0 ;;
            ""|n|nao|não|no) return 1 ;;
            *)               echo "  Responda 's' (sim) ou 'n' (não)." ;;
        esac
    done
}

print_usage() {
    sed -n '2,26p' "$0" | sed 's/^# \{0,2\}//'
}

# Garante permissão de administrador JÁ NO INÍCIO dos modos que precisam dela.
# Se o script não foi iniciado com sudo, ele se reexecuta via sudo
# (a senha é pedida uma única vez, antes de começar qualquer trabalho).
ensure_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        echo "Este modo precisa de permissão de administrador, mas o 'sudo' não está instalado." >&2
        echo "Rode como root diretamente com: su -c \"$0 $*\"" >&2
        exit 1
    fi
    echo "Este modo precisa de permissão de administrador (sudo)."
    echo "O sistema vai pedir sua senha — ela não aparece enquanto você digita (é normal)."
    exec sudo "$0" "$@"
}

show_grub_line() {
    grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE" || echo "(linha GRUB_CMDLINE_LINUX_DEFAULT não encontrada)"
}

already_applied() {
    grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=.*acpi_backlight=native' "$GRUB_FILE" >/dev/null 2>&1
}

# Procura um comando no PATH ou nos lugares comuns (/bin, /sbin, /usr/sbin...).
have_cmd() {
    command -v "$1" >/dev/null 2>&1 && return 0
    local p
    for p in /bin /usr/bin /sbin /usr/sbin /usr/local/bin /usr/local/sbin; do
        [[ -x "$p/$1" ]] && return 0
    done
    return 1
}

# Verifica se os programas necessários para trabalhar existem na máquina.
# Se faltar algum, mostra o comando de instalação apropriado.
check_deps() {
    echo "== Verificação de dependências =="
    local missing=0 cmd
    for cmd in grep sed cp cat readlink lspci update-grub reboot; do
        if have_cmd "$cmd"; then
            printf '  ok   %s\n' "$cmd"
        else
            printf '  FALTA %s\n' "$cmd"
            missing=1
        fi
    done
    if [[ $missing -eq 1 ]]; then
        echo
        echo "Faltam componentes para o script funcionar."
        echo "No Debian/Ubuntu (Lubuntu), instale com:"
        echo "  sudo apt update"
        echo "  sudo apt install pciutils grub2-common"
        echo
        echo "  (lspci está no pacote 'pciutils'; update-grub está em 'grub2-common'.)"
        echo "  Depois rode este script de novo."
        return 1
    fi
    echo "  Todos os programas necessários estão presentes."
    echo
    return 0
}

# Verifica se o computador é o "alvo certo" deste guia:
#   - a placa de vídeo deve ser Intel GMA 4500MHD (GM45), e
#   - o modelo deve ser um Samsung das séries RV410/RV510/S3510/E3510/R518/R470.
# Retorna 0 se confirmado, 1 se houver divergência, 2 se não deu para descobrir.
verify_hardware() {
    echo "== Verificação do hardware =="
    local gpu_ok=0 gpu_unknown=0
    local vga
    vga=$(lspci 2>/dev/null | grep -i -m1 'vga' || true)
    if [[ -n "$vga" ]]; then
        echo "Placa de vídeo (lspci): $vga"
        if [[ "$vga" =~ [Gg]M45|[Gg]MA|Mobile[[:space:]]4|4500M ]]; then
            gpu_ok=1
            echo "  -> compatível (Intel GMA 4500MHD / GM45)."
        else
            echo "  -> NÃO reconhecida como Intel GMA 4500MHD."
        fi
    else
        gpu_unknown=1
        echo "Placa de vídeo: não foi possível identificar (lspci sem resposta)."
    fi

    local dmi_vendor dmi_product dmi_ok=0
    dmi_vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr -d ' \t\r\n' || true)
    dmi_product=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr -d ' \t\r\n' || true)

    if [[ -n "$dmi_vendor" ]]; then
        echo "Fabricante (DMI): $dmi_vendor"
        if [[ -n "$dmi_product" ]]; then
            echo "Modelo (DMI): $dmi_product"
        fi
        if [[ "${dmi_vendor,,}" == *samsung* ]] && [[ -n "$dmi_product" ]] && \
           [[ "${dmi_product,,}" =~ rv4[0-9]|rv5[0-9]|r518|r470|s35[0-9][0-9]|e35[0-9][0-9] ]]; then
            dmi_ok=1
            echo "  -> modelo Samsung da família afetada confirmado."
        else
            echo "  -> modelo/fabricante fora da lista do guia (ou DMI legível com sudo)."
        fi
    else
        echo "Fabricante/modelo (DMI): indisponível sem permissão de administrador."
    fi

    echo
    if [[ $gpu_ok -eq 1 ]]; then
        echo "VERIFICAÇÃO: placa de vídeo compatível confirmada."
        return 0
    fi
    if [[ $dmi_ok -eq 1 ]]; then
        echo "VERIFICAÇÃO: modelo Samsung da família afetada, mas a placa não foi reconhecida."
        echo "  (É possível, em raras configurações, o comando lspci agrupar a GPU de outra forma.)"
        return 1
    fi
    if [[ $gpu_unknown -eq 1 ]]; then
        echo "VERIFICAÇÃO: não foi possível confirmar o hardware."
        return 2
    fi
    echo "VERIFICAÇÃO: este computador NÃO está na lista dos compatíveis."
    echo "  O guia foi testado em Samsung RV410/RV510/S3510/E3510 com Intel GMA 4500MHD."
    return 1
}

# Pergunta se o usuário quer continuar apesar da verificação de hardware ter falhado.
# Retorna 0 para "continuar" e 1 para "parar".
proceed_despite_hardware() {
    echo "Atenção: o script não confirmou que este aparelho é o alvo deste guia."
    echo "  É seguro para o sistema (nada aqui corrompe o computador), mas pode não resolver seu problema."
    if ! confirm "Quer continuar mesmo assim?"; then
        echo "Cancelado. Nada foi alterado."
        return 1
    fi
    echo "OK, continuando por conta e risco — a correção será aplicada."
    return 0
}

check_backlights() {
    echo "Backlight reconhecido pelo kernel (/sys/class/backlight):"
    if [[ -d /sys/class/backlight ]] && ls /sys/class/backlight 2>/dev/null | grep -q .; then
        ls /sys/class/backlight 2>/dev/null | sed 's/^/  /'
    else
        echo "  nenhum dispositivo ainda (normal antes de reiniciar com a correção)."
    fi
}

status() {
    echo "== Estado atual da correção de backlight =="
    echo
    verify_hardware || true
    echo
    echo "1) Arquivo de configuração do GRUB ($GRUB_FILE)"
    if [[ -f "$GRUB_FILE" ]]; then
        echo "   Linha: $(show_grub_line)"
        if already_applied; then
            echo "   acpi_backlight=native -> APLICADO em $GRUB_FILE"
        else
            echo "   acpi_backlight=native -> AINDA NÃO aplicado"
        fi
    else
        echo "   arquivo não encontrado."
    fi
    echo
    echo "2) Backup do original ($BACKUP_FILE)"
    if [[ -f "$BACKUP_FILE" ]]; then
        echo "   EXISTE (cópia do arquivo original — pode desfazer com --rollback)"
    else
        echo "   não existe ainda"
    fi
    echo
    echo "3) Configuração gerada pelo update-grub ($GRUB_CFG)"
    if [[ -r "$GRUB_CFG" ]]; then
        if grep -q 'acpi_backlight=native' "$GRUB_CFG" 2>/dev/null; then
            echo "   contém acpi_backlight=native -> update-grub JÁ rodou após a edição"
        else
            echo "   NÃO contém -> você ainda precisa rodar 'sudo update-grub'"
        fi
    else
        echo "   arquivo ilegível sem permissões de admin — rode 'sudo $0 --status' para ler."
    fi
    echo
    check_backlights
    echo
    echo "Próximo passo sugerido:"
    if already_applied && [[ -f "$BACKUP_FILE" ]]; then
        echo "  Reinicie e confira com: $SCRIPT_DIR/check-backlight.sh"
    else
        echo "  rode o guia (ou 'sudo $0' e responda as perguntas)."
    fi
}

dry_run() {
    echo "MODO DE TESTE (--dry-run): nada será alterado."
    echo
    check_deps || return 1
    verify_hardware || true
    echo
    if [[ ! -f "$GRUB_FILE" ]]; then
        echo "ERRO: $GRUB_FILE não encontrado. Este script foi feito para sistemas que usam GRUB." >&2
        exit 1
    fi
    echo "Linha atual em $GRUB_FILE:"
    echo "  $(show_grub_line)"
    echo
    echo "Depois da correção ela ficaria com ${NEW_PARAM} inserido"
    echo "(e qualquer acpi_backlight=... diferente já existente seria removido):"
    local linha
    linha=$(show_grub_line)
    echo "  $linha" | sed -E 's/( )?acpi_backlight=[^ "]+//g' | sed -E 's/GRUB_CMDLINE_LINUX_DEFAULT="([^"]*)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 '"$NEW_PARAM"'"/'
    echo
    echo "Depois disso, quando você rodar o script de verdade, ele:"
    echo "  0. re-verificará dependências e hardware;"
    echo "  1. pedirá confirmação antes de editar o arquivo;"
    echo "  2. fará backup em $BACKUP_FILE;"
    echo "  3. pedirá confirmação antes de rodar o update-grub;"
    echo "  4. verificará o resultado;"
    echo "  5. perguntará se você quer reiniciar agora."
}

rollback() {
    ensure_root
    echo "== Revertendo a correção =="
    echo
    check_deps || return 1
    if [[ ! -f "$BACKUP_FILE" ]]; then
        echo "Nenhum backup encontrado em $BACKUP_FILE. Nada para restaurar." >&2
        exit 1
    fi
    echo "Vai restaurar:"
    echo "  $BACKUP_FILE -> $GRUB_FILE"
    if ! confirm "Deseja continuar com a restauração?"; then
        echo "Cancelado. Nada foi alterado."
        exit 0
    fi
    cp -a "$BACKUP_FILE" "$GRUB_FILE"
    if ! confirm "Restaurar o arquivo e rodar o update-grub agora?"; then
        echo "Arquivo restaurado, mas o update-grub NÃO foi rodado."
        echo "Rode manualmente quando quiser: sudo update-grub"
        exit 0
    fi
    update-grub
    echo "Backup restaurado e GRUB regenerado."
    if confirm "Reiniciar o computador agora?"; then
        echo "Reiniciando..."
        sync
        reboot
    fi
    echo "OK. Reinicie manualmente (sudo reboot) quando quiser."
}

apply_fix() {
    ensure_root

    echo "== Correção de backlight (Samsung RV410 / Intel GMA 4500MHD) =="
    echo
    check_deps || return 1
    local hw_status=0
    verify_hardware || hw_status=$?
    if [[ $hw_status -ne 0 ]]; then
        proceed_despite_hardware || exit 0
    fi
    echo

    if [[ ! -f "$GRUB_FILE" ]]; then
        echo "ERRO: $GRUB_FILE não encontrado. Este script foi feito para sistemas que usam GRUB." >&2
        exit 1
    fi

    if already_applied && [[ -f "$BACKUP_FILE" ]]; then
        echo "A correção já parece aplicada ($NEW_PARAM presente)."
        if confirm "Mesmo assim, rodar 'update-grub' agora para garantir?"; then
            update-grub
        else
            echo "Nada a fazer."
        fi
    else
        echo "O arquivo será alterado de:"
        echo "  $(show_grub_line)"
        echo
        echo "para:"
        echo "  $(show_grub_line | sed -E 's/( )?acpi_backlight=[^ "]+//g' | sed -E 's/GRUB_CMDLINE_LINUX_DEFAULT="([^"]*)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 '"$NEW_PARAM"'"/')"
        echo
        if ! confirm "Aplicar essa mudança?"; then
            echo "Cancelado. Nada foi alterado."
            exit 0
        fi

        if [[ ! -f "$BACKUP_FILE" ]]; then
            echo "Criando backup: $GRUB_FILE -> $BACKUP_FILE"
            cp -a "$GRUB_FILE" "$BACKUP_FILE"
        else
            echo "Backup $BACKUP_FILE já existe — mantendo o original."
        fi

        sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/( )?acpi_backlight=[^ "]+//g' "$GRUB_FILE"
        if ! grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=.*acpi_backlight=native' "$GRUB_FILE" >/dev/null 2>&1; then
            sed -i -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="([^"]*)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 '"$NEW_PARAM"'"/' "$GRUB_FILE"
        fi
        echo "Arquivo atualizado: $(show_grub_line)"

        if ! confirm "Rodar 'update-grub' agora para aplicar na próxima inicialização?"; then
            echo "Mudança salva, mas o GRUB NÃO foi atualizado."
            echo "Rode manualmente quando quiser: sudo update-grub"
            exit 0
        fi
        update-grub
    fi

    echo
    echo "== Verificação da camada gerada =="
    if [[ -r "$GRUB_CFG" ]]; then
        if grep -q 'acpi_backlight=native' "$GRUB_CFG" 2>/dev/null; then
            echo "OK: $GRUB_CFG já contém acpi_backlight=native."
        else
            echo "AVISO: não encontrei acpi_backlight=native em $GRUB_CFG."
            echo "  Confira manualmente com: sudo grep acpi_backlight /boot/grub/grub.cfg"
        fi
    else
        echo "AVISO: $GRUB_CFG não existe ou não pode ser lido neste caminho."
        echo "  Verifique com: sudo grep acpi_backlight /boot/grub/grub.cfg /boot/grub2/grub.cfg 2>/dev/null"
    fi
    echo
    echo "== Próximo passo =="
    if confirm "Reiniciar o computador agora para ativar o brilho?"; then
        echo "Reiniciando..."
        sync
        reboot
    fi
    echo "OK. Quando reiniciar, confira com:"
    echo "  $SCRIPT_DIR/check-backlight.sh"
    echo "(o reinício é obrigatório para a mudança ter efeito.)"
}

case "${1:-}" in
    --help|-h)       print_usage ;;
    --dry-run)       dry_run ;;
    --status)        status ;;
    --rollback)      rollback ;;
    --yes|-y)        ASSUME_YES=1; apply_fix ;;
    "")              apply_fix ;;
    *)               echo "Opção desconhecida: $1" >&2; print_usage >&2; exit 1 ;;
esac