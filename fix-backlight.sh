#!/usr/bin/env bash
#
# fix-backlight.sh — Aplica a correção de backlight do Samsung RV410
# (e similares com Intel GMA 4500MHD) no Linux.
#
# O que faz:
#   1. Faz backup de /etc/default/grub em /etc/default/grub.bak (se ainda não existir)
#   2. Troca qualquer "acpi_backlight=alguma_coisa" por "acpi_backlight=native"
#   3. Roda "update-grub" para aplicar a mudança
#
# Uso:
#   sudo ./fix-backlight.sh              # aplica a correção
#   sudo ./fix-backlight.sh --dry-run    # mostra o que faria, sem mudar nada
#   sudo ./fix-backlight.sh --rollback   # restaura o arquivo original a partir do backup
#

set -euo pipefail

GRUB_FILE="/etc/default/grub"
BACKUP_FILE="/etc/default/grub.bak"
NEW_PARAM="acpi_backlight=native"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

print_usage() {
    sed -n '2,12p' "$0" | sed 's/^# \{0,2\}//'
    echo
    echo "Opções:"
    echo "  --dry-run    Mostra o que seria alterado sem tocar em nenhum arquivo."
    echo "  --rollback   Restaura /etc/default/grub.bak (o arquivo original, se existir)."
    echo "  -h, --help   Mostra esta ajuda."
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Este script precisa de permissão de administrador." >&2
        echo "Rode com: sudo $0 $*" >&2
        exit 1
    fi
}

show_grub_line() {
    grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE" || echo "(linha GRUB_CMDLINE_LINUX_DEFAULT não encontrada)"
}

# Detecta se acpi_backlight=native já está aplicado na linha principal do GRUB.
already_applied() {
    grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=.*acpi_backlight=native' "$GRUB_FILE" >/dev/null 2>&1
}

rollback() {
    check_root
    if [[ ! -f "$BACKUP_FILE" ]]; then
        echo "Nenhum backup encontrado em $BACKUP_FILE. Nada para restaurar." >&2
        exit 1
    fi
    echo "Restaurando $BACKUP_FILE -> $GRUB_FILE ..."
    cp -a "$BACKUP_FILE" "$GRUB_FILE"
    echo "Gerando nova configuração do GRUB (update-grub)..."
    update-grub
    echo "Backup restaurado. Reinicie o computador (sudo reboot)."
}

apply_fix() {
    check_root

    if [[ ! -f "$GRUB_FILE" ]]; then
        echo "Arquivo $GRUB_FILE não encontrado. Este script foi feito para sistemas que usam GRUB." >&2
        exit 1
    fi

    if already_applied && [[ -f "$BACKUP_FILE" ]]; then
        echo "A correção já parece estar aplicada ($NEW_PARAM presente em $GRUB_FILE)."
        echo "Nada a fazer."
        exit 0
    fi

    if [[ ! -f "$BACKUP_FILE" ]]; then
        echo "Criando backup: $GRUB_FILE -> $BACKUP_FILE"
        cp -a "$GRUB_FILE" "$BACKUP_FILE"
    else
        echo "Backup $BACKUP_FILE já existe — mantendo o original."
    fi

    echo "Antes:  $(show_grub_line)"

    # 1. Remove qualquer "acpi_backlight=..." existente na linha GRUB_CMDLINE_LINUX_DEFAULT
    sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/( )?acpi_backlight=[^ "]+//g' "$GRUB_FILE"
    # 2. Adiciona "acpi_backlight=native" no final da linha (se ainda não estiver)
    if ! grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=.*acpi_backlight=native' "$GRUB_FILE" >/dev/null 2>&1; then
        sed -i -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="([^"]*)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 '"$NEW_PARAM"'"/' "$GRUB_FILE"
    fi

    echo "Depois: $(show_grub_line)"

    echo "Gerando nova configuração do GRUB (update-grub)..."
    update-grub

    echo
    echo "Feito! Reinicie o computador (sudo reboot) e confira com:"
    echo "  $SCRIPT_DIR/check-backlight.sh"
}

dry_run() {
    check_root
    echo "MODO DE TESTE (--dry-run): nada será alterado."
    echo "Linha atual em $GRUB_FILE:"
    echo "  $(show_grub_line)"
    echo
    echo "Depois da correção ela ficaria com ${NEW_PARAM} inserido (e sem nenhum "
    echo "acpi_backlight=... diferente já existente):"
    local linha
    linha=$(show_grub_line)
    echo "  $linha" | sed -E 's/( )?acpi_backlight=[^ "]+//g' | sed -E 's/GRUB_CMDLINE_LINUX_DEFAULT="([^"]*)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 '"$NEW_PARAM"'"/'
    echo
    echo "Também seria executado: update-grub"
}

case "${1:-}" in
    --help|-h)            print_usage ;;
    --dry-run)            dry_run ;;
    --rollback)           rollback ;;
    "")                   apply_fix ;;
    *)                    echo "Opção desconhecida: $1" >&2; print_usage >&2; exit 1 ;;
esac