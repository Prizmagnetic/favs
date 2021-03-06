#!/bin/bash

input=~/favs/favs.txt

ACTION="normal"

usage()
{
  echo "Usage: ~/favs/favs.sh [-lei] [ -s newCMD ] [ -r CMD_index ]"
  echo "-s              Save newCMD into favs.txt" 
  echo "-r              Run saved command using index number"
  echo "-l              List saved commands"
  echo "-e              Edit command list"
  echo "-i              'Install' via ~/.bash_aliases"
  echo "-h              display this help text and exit"
  exit 2
}

while getopts ':s:r:l:e:i?h' c
do
  case $c in
    s) ACTION=save
       echo $OPTARG >> $input
       echo $OPTARG 
       echo Command saved! 
       exit ;;
    r) ACTION=run 
       choice=$OPTARG ;;
    l) ACTION=list ;;
    e) nano $input 
       exit  ;;
    i) echo "alias f='~/favs/favs.sh'" >> ~/.bash_aliases
       echo "Relogin to finish"
       exit  ;;
    h|?) usage  ;;
    :) ACTION=empty ;;
  esac
done

#pull list of commands from input file
i=0
while IFS= read -r line
do
  if [[ $line ]];  #If the line isnt blank
  then
    if [[ $ACTION == list || $ACTION == normal ]]; then
      echo $i")" "$line"
    fi
    cmds[i]="$line"
    ((i++))
  else
    if [[ $ACTION == list || $ACTION == normal ]]; then
      echo
    fi
  fi
done < "$input"

if [[ $ACTION == normal ]]; then
  echo -n "run: "
  read choice
fi

if [[ $ACTION == run || $ACTION == normal ]]; then
  #checks input and runs selection
  if [[ $choice -ge 0  && ${#cmds[@]} -gt $choice ]]; then
    echo running: ${cmds[$choice]}
    #eval ${cmds[$choice]}
    eval ${cmds[$choice]}
  else
    echo invaild input! int out of range!
  fi
fi

