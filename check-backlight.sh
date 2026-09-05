#!/usr/bin/env bash
#
# check-backlight.sh — Verifica se o Linux reconhece o controle de backlight.
#
# Deve ser rodado DEPOIS de reiniciar o computador com a correção aplicada.
# Também pode ser rodado a qualquer momento, apenas para diagnóstico.
#
# Uso:
#   ./check-backlight.sh          # verificação normal
#   ./check-backlight.sh --all    # mostra detalhes extras dos dispositivos encontrados
#

set -uo pipefail

BACKLIGHT_DIR="/sys/class/backlight"

if [[ ! -d "$BACKLIGHT_DIR" ]]; then
    echo "ERRO: $BACKLIGHT_DIR não existe neste sistema." >&2
    echo "Este computador pode não ter um hardware de backlight exposto pelo kernel." >&2
    exit 2
fi

devices=($(ls "$BACKLIGHT_DIR" 2>/dev/null))

if [[ ${#devices[@]} -eq 0 ]]; then
    echo "Nenhum dispositivo de backlight encontrado em $BACKLIGHT_DIR."
    echo
    echo "A correção ainda não deu efeito. Possíveis motivos:"
    echo "  1. Você ainda não reiniciou o computador depois de rodar fix-backlight.sh"
    echo "  2. O GRUB não foi atualizado (rode: sudo update-grub)"
    echo "  3. Esta placa não é Intel GMA 4500MHD (confira com: lspci | grep -i vga)"
    echo
    echo "Próximos passos sugeridos:"
    echo "  - Rode: sudo ./fix-backlight.sh && sudo reboot"
    echo "  - Se não funcionar, tente os parâmetros alternativos do README:"
    echo "      video.use_native_backlight=1  ou  acpi_backlight=vendor"
    exit 1
fi

for dev in "${devices[@]}"; do
    echo "Backlight encontrado: $dev"
    [[ "${1:-}" == "--all" ]] && cat "$BACKLIGHT_DIR/$dev/type" 2>/dev/null | sed 's/^/  tipo: /'
done

echo

if [[ " ${devices[*]} " == *" intel_backlight "* ]]; then
    echo "SUCESSO: o 'intel_backlight' foi reconhecido."
    echo "As teclas Fn de brilho devem funcionar normalmente agora."
    exit 0
else
    echo "AVISO: nenhum dispositivo chamado 'intel_backlight' foi encontrado."
    echo "O dispositivo padrão deste sistema é: ${devices[0]}"
    echo "Teste as teclas Fn de brilho — se funcionarem, ok."
    echo "Se não funcionarem, veja a seção de soluções alternativas do README."
    exit 1
fi