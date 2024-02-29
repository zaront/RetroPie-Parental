#!/usr/bin/env bash

#important file paths
RUNCOMMAND="/opt/retropie/supplementary/runcommand/runcommand.sh"
AUTOSTART="/opt/retropie/configs/all/autostart.sh"
ONEND="/opt/retropie/configs/all/runcommand-onend.sh"


#FUNCTIONS

# params: package name
insure_package() {
  local package="$1"
  dpkg -l "$package" &>/dev/null
  local exitCode=$?
  if [ $exitCode != 0 ]
  then
    echo installing missing package: $package
    sudo apt install "$package" -y
    local exitCode=$?
    # try updating package list - one time only
    if [ $exitCode != 0 ] && [ -z $_triedUpdate ]
    then
      _triedUpdate=1
      sudo apt update -y
      sudo apt install "$package" -y
      local exitCode=$?
    fi
  fi
  if [ $exitCode != 0 ]
  then
    echo "the required package: '$package' could not be installed.  please install the package manualy and try this script again." >&2
    exit 1
  fi
}

insure_os() {
  local sysName=$(uname -n)
  if [ "$sysName" != "reropie" ]
  then
    echo "This setup script was intended for the RetroPie os installed from an image for a raspberry pi.  This system apears to be diffrent."
    read -r -p "Do you want to continue? [Y/n] " response
    if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]
    then
        exit 1
    fi
  fi
}

insure_file() {
  local file="$1"
  if [ ! -e "$file" ]
  then
    echo "'$file' is missing."
    echo "RetroPie does not seem to be installed on this system" >&2
    exit 1
  fi
}

# find the first matching line number of a string
get_line() {
  local line="$1"
  local file="$2"
  local lineNumber=${3:-0}
  get_line_result=$(tail -n +$lineNumber $file | grep "$line" -n | head -1 | cut -d: -f1)
  [ -z "$get_line_result" ] && get_line_result=0
  [ "$get_line_result" != 0 ] && [ "$lineNumber" != 0 ] && get_line_result=$(($get_line_result + $lineNumber - 1))
}

# insert at a line number
insert_line() {
  local line="$1"
  local file="$2"
  local lineNumber=${3:-0}
  sudo sed -i "$lineNumber i $line" $file
}

# remove at a line number
remove_line() {
  local file="$1"
  local lineNumber=${2:-0}
  sudo sed -i "${lineNumber}d" $file
}

install() {
  echo "This will setup Parental Controls on your RetroPie"

  # is this the right os
  insure_os

  # is RetroPie installed
  insure_file $RUNCOMMAND
  insure_file $AUTOSTART

  # add any missing packages
  insure_package "git"
  insure_package "toilet"
  insure_package "sox"
  insure_package "python3"
  insure_package "python3-pip"

  # download the app
  cd ~
  if [ ! -e "RetroPie-Parental" ]
  then
    git clone https://github.com/zaront/RetroPie-Parental.git
  fi
  cd "RetroPie-Parental"
  installDir=$(pwd)

  # install python packages
  pip3 install -r requirements.txt

  # ==integrate with RetroPie sys by doing the following:

  # --add hard link to runcommand-onend.sh file
  if [ -f "$ONEND" ]
  then
    rm "$ONEND"
  fi
  ln runcommand-onend.sh $ONEND

  # --add website to autostart along with RetroPie
  local autostart_line="$installDir/web.py prod &"
  get_line "$autostart_line" $AUTOSTART
  if [ "$get_line_result" == 0 ]
  then
    insert_line "$autostart_line" $AUTOSTART 0
  fi

  # --add parental support to runcommand.sh
  local run_find1="source \"\$ROOTDIR/lib/inifuncs.sh\""
  local run_line1="source \"$installDir/runcommand-parental.sh\""
  get_line "$run_line1" $RUNCOMMAND
  if [ "$get_line_result" == 0 ]
  then
    get_line "$run_find1" $RUNCOMMAND
    if [ "$get_line_result" != 0 ]
    then
      insert_line "$run_line1" $RUNCOMMAND $(($get_line_result + 1))
    fi
  fi
  local run_find2="function runcommand() {"
  local run_find3="rm -f \"\$LOG\""
  local run_line2="parental-control"
  get_line "$run_line2" $RUNCOMMAND
  if [ "$get_line_result" == 0 ]
  then
    get_line "$run_find2" $RUNCOMMAND
    if [ "$get_line_result" != 0 ]
    then
      get_line "$run_find3" $RUNCOMMAND $get_line_result
      if [ "$get_line_result" != 0 ]
      then
        insert_line "$run_line2" $RUNCOMMAND $get_line_result
      fi
    fi
  fi

  echo "Parental Controls are installed at ~/RetroPie_Parental"
  echo "Please Reboot your RetroPie to complete your installation"
  echo
  echo "the parental website is at:"
  echo "http://retropie.local:8080" or http://$(hostname -I | cut -f1 -d' '):8080 
  echo "username: admin"
  echo "password: retropie"
}

update() {
  echo "updating to the latest version"
  if [ -e "~/RetroPie-Parental/.git/"]
  then
    cd "~/RetroPie-Parental"
    
  fi
}

uninstall() {
  echo uninstall
}

auto_choose_action() {
  echo "Checking if already installed"
  local installed=0
  if [ -f "~/RetroPie-Parental/runcommand-onend.sh" ] && [ -f "$ONEND" ]
  then
    local hardlink1=$(ls -i "~/RetroPie-Parental/runcommand-onend.sh" | cut -f1 -d" ")
    local hardlink2=$(ls -i "$ONEND" | cut -f1 -d" ")
    [ $hardlink1 == $hardlink2 ] && $installed=1
  fi

  # if not installed then install
  if [ $installed == 0 ]
  then
    install
  fi

  # if already installed then update
  if [ $installed == 1 ]
  then
    update
  fi
  
  # message about uninstalling
  echo "

update by running '~/RetroPie-Parental/setup.sh update'
uninstall by running '~/RetroPie-Parental/setup.sh uninstall'
"
}

show_help() {
  echo "
Setup script for adding Parental Controls to RetroPie

commands:
  install          - download and install Parental Controls
  update           - update to the lattest version
  uninstall        - remove Parental Controls
"
}

#COMMANDS


case "$1" in

  "install")
    install
    ;;

  "uninstall")
    uninstall
    ;;

  "update")
    update
    ;;

  "")
    auto_choose_action
    ;;

  *)
    show_help
    ;;

esac

