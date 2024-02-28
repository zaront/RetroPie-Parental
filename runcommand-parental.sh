# will add parental support to the runcommand.sh
#
# Installation:
# (add the following to /opt/retropie/supplementary/runcommand/runcommand.sh)
# * ln 97:   source "$HOME/RetroPie-Parental/runcommand-parental.sh"
# * ln 1328: parental-control

function parental-control() {

    start_joy2key
    /home/pi/RetroPie-Parental/parental_control.py start_game "$SYSTEM - $(basename -- "$ROM")"
    ret="$?"
    stop_joy2key
    clear
    [[ "$ret" -eq 1 ]] && restore_cursor_and_exit 0

}
