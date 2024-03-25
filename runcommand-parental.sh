
function parental-control() {
    
    start_joy2key
    local emulator=$(basename "$(echo "$COMMAND" | cut -d " " -f 1)")
    $HOME/RetroPie-Parental/parental_control.py start_game "$SYSTEM - $(basename -- "$ROM")" "$emulator"
    ret="$?"
    stop_joy2key
    clear
    [[ "$ret" -eq 1 ]] && restore_cursor_and_exit 0

}
