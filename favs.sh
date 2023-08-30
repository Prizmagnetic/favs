#!/bin/bash

#bugs:
#favs.txt doesnt read the last line. needs a blank at the end
#   also should trim trailling new lines

#nice things to have TODO:
#separate default cmds list, showing spaces and comments working etc.
#make file locations not hard coded
#have update/power/etc work on other distros
#allow edit to work with other text editors

#stored commands location
input=~/favs/favs.txt

edit() #Edit command list
{
  nano $input 
  exit
}

power() #System power shortcuts
{
  echo "(r)estart (s)hutdown (c)ancel"
  echo -n "Input: "
  read choice
  if [[ $choice == "r" ]]; then
    sudo reboot
  elif [[ $choice == "s" ]]; then
    sudo shutdown -h now
  elif [[ $choice == "c" ]]; then
    echo "canceled"
  else 
    echo "Invalid input, canceling"
  fi
  exit
}

updater() #Update packages on system
{
  echo "Attempting package updates..."
  sudo apt update && sudo apt upgrade -y
  exit
}

readFavs() #Read cmd file, optionaly print output
{
  # cmd list header
  if [[ $1 == print ]]; then
    echo "(e)dit (p)ower (u)pdate (h)elp"
  fi
  #pull list of commands from input file
  i=0
  while IFS= read -r line
  do
    if [[ -z "$line" ]]; then #If the line is blank
      if [[ $1 == print ]]; then
        echo ''
      fi
    elif [[ ${line:0:1} == "#" ]]; then #if line is a comment
      if [[ $1 == print ]]; then
        echo $line
      fi
    else #IF the line is assumed to be a command
      if [[ $1 == print ]]; then
        echo $i")" "$line"
      fi
      cmds[i]="$line"
      ((i++))
    fi
  done < "$input" #Load file with the list of commands as input
}

runPrompt() #Prompt user for a command to run
{
  #run prompt
  echo -n "run: "
  read choice
  #take opts in run input
  if [[ $choice == "e" ]]; then
      edit
  elif [[ $choice == "p" ]]; then
      power
  elif [[ $choice == "u" ]]; then
      updater
  elif [[ $choice == "h" ]]; then
      usage
  fi
}

runCMD() #Run selected command
{
  #checks input and runs selection
  re='^[0-9]+$'

  #if choice is a number
  if ! [[ $choice =~ $re ]]; then 
    echo "error: Not a number" >&2; exit 1
  fi
  #if choice is a number in the range of cmds
  if [[ $choice -ge 0  && ${#cmds[@]} -gt $choice ]]; then
    echo running: ${cmds[$choice]}
    eval ${cmds[$choice]}
  else
    echo "error: invaild input! int out of range!"  >&2; exit 1
  fi
}

usage() #Display this help text and exit
{
  echo "Usage: ~/favs/favs.sh [-egilpu] [ -s newCMD ] [ -r CMD_index ]"
  echo "-e              Edit command list"
  echo "-g              Update Favs from Git repo"
  echo "-i              'Install' via ~/.bash_aliases"
  echo "-l              List saved commands"
  echo "-p              Power, reboot, shutdown"    
  echo "-r              Run saved command using index number"
  echo "-s              Save newCMD into favs.txt"
  echo "-u              Run apt-get update && upgrage"
  echo "-h              Display this help text and exit"
  exit 2
}

while getopts ':egilpr:s:u?h' c
do
  case $c in
    e) edit  ;;
    g) echo "cmd to update favs from git goes here"
       cd ~/favs/
       git pull
       exit  ;;
    i) echo "alias f='~/favs/favs.sh'" >> ~/.bash_aliases
       echo "Relogin to finish"
       exit  ;;
    l) readFavs "print"  
       exit;;
    p) power ;;
    r) choice=$OPTARG 
       readFavs
       runCMD
       exit  ;;
    s) echo $OPTARG >> $input
       echo $OPTARG 
       echo Command saved! 
       exit ;;
    u) updater ;;
    h|?) usage ;;
  esac
done

#when no options or arguments are given
readFavs "print"
runPrompt
runCMD
