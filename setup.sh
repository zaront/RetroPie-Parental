#!/usr/bin/env bash

# Install, Uninstall, and Update script for adding Parental Controls to RetroPie

# call 'setup.sh' to autmaticly install or update an existing installation
# call 'setup.sh uninstall' to remove


# file paths
RUNCOMMAND="/opt/retropie/supplementary/runcommand/runcommand.sh"
AUTOSTART="/opt/retropie/configs/all/autostart.sh"
ONEND="/opt/retropie/configs/all/runcommand-onend.sh"
INSTALLDIR="$HOME/RetroPie-Parental"

# script inserts
AUTOSTART_LINE="$INSTALLDIR/web.py prod &"
RUN_LINE1="source \"$INSTALLDIR/runcommand-parental.sh\""
RUN_LINE2="parental-control"

#FUNCTIONS

setup_colors() {
  # check if stdout is a terminal...
  if test -t 1; then

    # see if it supports colors...
    ncolors=$(tput colors)

    if test -n "$ncolors" && test $ncolors -ge 8; then
        bold="$(tput bold)"
        underline="$(tput smul)"
        standout="$(tput smso)"
        normal="$(tput sgr0)"
        black="$(tput setaf 0)"
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
        yellow="$(tput setaf 3)"
        blue="$(tput setaf 4)"
        magenta="$(tput setaf 5)"
        cyan="$(tput setaf 6)"
        white="$(tput setaf 7)"
        gray=$(tput setaf 8)
    fi
  fi
}

# params: package name
insure_package() {
  local package="$1"
  dpkg -l "$package" &>/dev/null
  local exitCode=$?
  if [ $exitCode != 0 ]
  then
    echo ${magenta}installing missing package: $package ${normal}
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
    echo "${red}The required package: '$package' could not be installed.  Please install the package manually and try this script again.${normal}" >&2
    exit 1
  fi
}

insure_os() {
  local sysName=$(uname -n)
  if [ "$sysName" != "retropie" ]
  then
    echo "${yellow}This setup script was intended for the RetroPie os installed from an image for a raspberry pi.  
    As such it was expecting the host name to be 'retropie'.  
    Instead, your host name is '$(uname -n)'.  
    This setup was tested for retropie os and may have errors installing on a diffrent setup.${normal}"
    read -r -p "${bold}Do you want to continue? [Y/n] ${normal}" response
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
    echo "'$file' is missing but was exprected for RetroPie"
    echo "${red}RetroPie does not seem to be installed on this system${normal}" >&2
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
  echo "${standout}setting up Parental Controls on your RetroPie...${normal}"

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
  if [ ! -e "$INSTALLDIR" ]
  then
    echo "${magenta}Downloading RetroPie Parental software...${normal}"
    git clone https://github.com/zaront/RetroPie-Parental.git
  fi
  cd "$INSTALLDIR"

  # install python packages
  echo "${magenta}Verifying python requirements...${normal}"
  pip3 install -r requirements.txt

  # ==integrate with RetroPie sys by doing the following:
  echo "${blue}Integrating Parental Controls into RetroPie...${normal}"

  # --add hard link to runcommand-onend.sh file
  echo "${magenta}Adding runcommand-onend.sh...${normal}"
  if [ -f "$ONEND" ]
  then
    rm "$ONEND"
  fi
  ln runcommand-onend.sh $ONEND

  # --add website to autostart along with RetroPie
  echo "${magenta}Adding website to autostart along with RetroPie...${normal}"
  get_line "$AUTOSTART_LINE" $AUTOSTART
  if [ "$get_line_result" == 0 ]
  then
    insert_line "$AUTOSTART_LINE" $AUTOSTART 1
  else
    echo "${gray}skipped: changes have been already made${normal}"
  fi

  # --add parental support to runcommand.sh
  echo "${magenta}Adding parental support to runcommand.sh...${normal}"
  local run_find1="source \"\$ROOTDIR/lib/inifuncs.sh\""
  get_line "$RUN_LINE1" $RUNCOMMAND
  if [ "$get_line_result" == 0 ]
  then
    get_line "$run_find1" $RUNCOMMAND
    if [ "$get_line_result" != 0 ]
    then
      insert_line "$RUN_LINE1" $RUNCOMMAND $(($get_line_result + 1))
    fi
  else
    echo "${gray}skipped: 1st change has already been already made${normal}"
  fi
  local run_find2="function runcommand() {"
  local run_find3="rm -f \"\$LOG\""
  get_line "$RUN_LINE2" $RUNCOMMAND
  if [ "$get_line_result" == 0 ]
  then
    get_line "$run_find2" $RUNCOMMAND
    if [ "$get_line_result" != 0 ]
    then
      get_line "$run_find3" $RUNCOMMAND $get_line_result
      if [ "$get_line_result" != 0 ]
      then
        insert_line "$RUN_LINE2" $RUNCOMMAND $get_line_result
      fi
    fi
  else
    echo "${gray}skipped: 2nd change has already been already made${normal}"
  fi

  echo "${green}SUCCESS: Parental Controls are installed at ~/RetroPie_Parental${normal}
  ${bold}Please Reboot your RetroPie to complete your installation${normal}

  The parental website is at:
    ${blue}http://retropie.local:8080${normal} or ${blue}http://$(hostname -I | cut -f1 -d' '):8080 ${normal}
    username: ${magenta}admin${normal}
    password: ${magenta}retropie${normal}"
}

update() {
  echo "${standout}Updating to the latest version${normal}"

  # validate repository
  if [ ! -e "$INSTALLDIR/.git/" ]
  then
    echo "${red}Installation can't be updated because it wasn't found to be setup using git.${normal}
    ${gray}To have updates work, you will need to uninstall and reinstall
    by running 'setup.sh uninstall' then 'setup.sh install' to fix this${normal}"
    exit 1
  fi

  # update repository
  cd "$INSTALLDIR"
  local prevCommit=$(git rev-parse HEAD)
  git pull
  local ret=$?
  if [ $ret != 0 ]
  then
    # if it failed - revert changes and try again
    if [[ $(git status --porcelain --untracked-files=no) ]]; then
      git reset --hard
      git pull
      ret=$?
    fi
  fi

  # run install if there was an update
  if [ $ret == 0 ]
  then
    local currentCommit=$(git rev-parse HEAD)
    if [ "$prevCommit" != "$currentCommit" ]
    then
      echo "${blue}Updated found and downloaded.${normal}"
      echo "${gray}Installing...${normal}"
      ./setup.sh install
    else
      echo "${blue}No new version found.${normal}"
    fi
  else
    echo "${red}Your git repository could not be updated.  Update it manually and try this script again${normal}"
    exit 1
  fi

  echo "${green}Your Parental Controls are at the latest version.${normal}"
}

uninstall() {
  echo "${standout}Uninstalling Parental Control for RetroPie...${normal}"

  # does the folder exist
  echo "$INSTALLDIR"
  if [ ! -e "$INSTALLDIR" ]
  then
    echo "${red}Parental Controls not found, or already uninstalled${normal}"
    exit 1
  fi

  # remove website startup
  get_line "$AUTOSTART_LINE" $AUTOSTART
  if [ "$get_line_result" != 0 ]
  then
    remove_line $AUTOSTART $get_line_result
  fi

  # remove runcommand-onend.sh file
  rm $ONEND

  # remove runcommand support for Parental Control
  local run_find1="source \"\$ROOTDIR/lib/inifuncs.sh\""
  get_line "$RUN_LINE1" $RUNCOMMAND
  if [ "$get_line_result" != 0 ]
  then
    remove_line $RUNCOMMAND $get_line_result
  fi
  get_line "$RUN_LINE2" $RUNCOMMAND
  if [ "$get_line_result" != 0 ]
  then
    remove_line $RUNCOMMAND $get_line_result
  fi

  # remove folder
  rm -rf "$INSTALLDIR"

  echo "${blue}Parental Controls are have been uninstalled${normal}"
  echo "${bold}Please Reboot your RetroPie to complete its removal${normal}"
}

auto_choose_action() {
  echo "${gray}Verifying existing installation...${normal}"
  local installed=0
  if [ -f "$INSTALLDIR/runcommand-onend.sh" ] && [ -f "$ONEND" ]
  then
    local hardlink1=$(ls -i "$INSTALLDIR/runcommand-onend.sh" | cut -f1 -d" ")
    local hardlink2=$(ls -i "$ONEND" | cut -f1 -d" ")
    [ $hardlink1 == $hardlink2 ] && installed=1
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
  ${gray}
  In the future you can update to the latest release by running '${magenta}~/RetroPie-Parental/setup.sh update${gray}'
  or remove Parental Controls by running '${normal}${magenta}~/RetroPie-Parental/setup.sh uninstall${gray}'${normal}
"
}

show_help() {
  echo "
${blue}Setup script for adding Parental Controls to RetroPie${normal}

commands:
  ${magenta}install${normal}          ${gray}- download and install Parental Controls${normal}
  ${magenta}update${normal}           ${gray}- update to the lattest version${normal}
  ${magenta}uninstall${normal}        ${gray}- remove Parental Controls${normal}
"
}

#COMMANDS

setup_colors
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

