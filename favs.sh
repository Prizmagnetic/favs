#!/bin/bash

#in github codespaces env use:
#bash /workspaces/favs_dev/favs.sh

#default.txt - default command list
#favs.txt - user saved commands
#favs.conf - configuration file for colors and other settings

#bugs: 
#f -r INDEX  is kinda useless now with groups changing the index numbers

#nice things to have TODO:
#allow edit to work with other text editors
#favs.txt - maybe should trim trailling new lines
#have update/power/etc work on other distros

# Favs is a small interactive command menu. It loads a list of commands from
# favs.txt (or a default example list when no personal file exists), lets the
# user run, group, edit, or save commands, and exposes a few helper actions like
# reboot/shutdown and package updates.

# Define default color codes used when printing the menu and status output.
RED='\033[0;31m'
GREEN='\033[0;32;1m'
YELLOW='\033[1;33m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Resource files live beside the script, while saved commands run from the
# directory where the script was invoked.
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
favsFile="$scriptDir/favs.txt"
configFile="$scriptDir/favs.conf"
defaultFile="$scriptDir/default.txt"
instructionEndMarker='# === END FAVS INSTRUCTIONS ==='

# Override the default colors when a config file exists.
if [ -e "$configFile" ]; then
  source "$configFile"
fi

# Disable all color escape sequences when requested in favs.conf.
case "${USE_COLORS,,}" in
  false|no|off|0)
    RED=''
    GREEN=''
    YELLOW=''
    GRAY=''
    NC=''
    ;;
esac

#load favs.txt if it exists, otherwise load default.txt
refreshInput()
{
  if [ -e "$favsFile" ]; then
    input="$favsFile"
  else
    input="$defaultFile"
  fi
}

refreshInput

initializeFavsFile()
{
  if [ -e "$favsFile" ]; then
    return 0
  fi

  cat > "$favsFile" <<EOF
# favs.txt is your personal command list.
# Lines beginning with # are comments and are not executable.
# Add commands below the instruction marker. Review commands before running them.
$instructionEndMarker

EOF
}


# Open the command list in the user's configured editor so commands can be
# added, removed, or revised directly in the saved file.
edit() #Edit command list
{
  initializeFavsFile || return 1
  refreshInput
  echo "editing: $favsFile"
  "${FAVS_EDITOR:-${EDITOR:-nano}}" "$favsFile"
  return $?
}

# Pull the repository copy of this script and its example files to sync local
# changes with the project root.
gitUpdate() #update favs from git
{
  echo "Updating from Git"
  git -C "$scriptDir" pull
}

#System power shortcuts
power()
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
  return 0
}

# Save a single new command into favs.txt without executing it first. This is
# used by the interactive prompt and the -s CLI option.
save() #Save new Command
{
  if [ ! -e "$favsFile" ]; then #if favs hasnt been created yet
    echo "Creating $favsFile"
    initializeFavsFile || return 1
  fi

  if [[ -s "$favsFile" && $(tail -c 1 "$favsFile" | wc -l) -eq 0 ]]; then
    echo >> "$favsFile"
  fi
  printf '%s\n' "$1" >> "$favsFile"
  refreshInput

  echo "$1"
  echo -e "${GREEN}Command saved!${NC}"
}

# Replace a command already stored in the file by its global index. This is used
# when editing an existing command from the menu and then saving it back.
saveCommandAt() #Replace one saved command without running it
{
  local targetIndex="$1"
  local replacement="$2"
  local tmpFile
  local commandIndex=0
  local replaced=false
  local line
  local savedCommand

  # Materialize the examples only when the user explicitly saves an edit.
  if [ ! -e "$favsFile" ]; then
    initializeFavsFile || {
      echo "error: could not create $favsFile" >&2
      return 1
    }
    if [[ "$input" != "$favsFile" ]]; then
      cat "$input" >> "$favsFile" || {
        echo "error: could not copy example commands to $favsFile" >&2
        return 1
      }
    fi
    refreshInput
  fi

  tmpFile=$(mktemp "${favsFile}.tmp.XXXXXX") || {
    echo "error: could not create temporary file" >&2
    return 1
  }

  while IFS= read -r line || [[ -n "$line" ]]
  do
    if [[ -n "$line" && ${line:0:1} != "#" ]]; then
      if [[ $commandIndex -eq $targetIndex ]]; then
        printf '%s\n' "$replacement" >> "$tmpFile"
        replaced=true
      else
        printf '%s\n' "$line" >> "$tmpFile"
      fi
      ((commandIndex++))
    else
      printf '%s\n' "$line" >> "$tmpFile"
    fi
  done < "$favsFile"

  if [[ $replaced != true ]]; then
    rm -f "$tmpFile"
    echo "error: invaild input! int out of range!" >&2
    return 1
  fi

  mv "$tmpFile" "$favsFile" || {
    rm -f "$tmpFile"
    echo "error: could not update $favsFile" >&2
    return 1
  }

  savedCommand=$(readCommandAt "$targetIndex") || {
    echo "error: could not read back the updated command" >&2
    return 1
  }

  echo "Command updated!"
  echo "Read back from favs.txt:"
  printf '%s\n' "$savedCommand"
}

# Return the raw command text for a saved item by its visible index in the list.
readCommandAt() #Read one saved command by its displayed index
{
  local targetIndex="$1"
  local commandIndex=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]
  do
    if [[ -n "$line" && ${line:0:1} != "#" ]]; then
      if [[ $commandIndex -eq $targetIndex ]]; then
        printf '%s\n' "$line"
        return 0
      fi
      ((commandIndex++))
    fi
  done < "$favsFile"

  return 1
}

updater() #Update packages on system
{
  echo "Attempting package updates..."
  sudo apt update && sudo apt upgrade -y
  return $?
}

testColors() #Print the configured colors
{
  echo "Color test (configured in $configFile):"
  echo -e "${RED}RED${NC}     errors and warnings"
  echo -e "${GREEN}GREEN${NC}   command numbers and status"
  echo -e "${YELLOW}YELLOW${NC}  edit prompts"
  echo -e "${GRAY}GRAY${NC}    comments"
  echo "If a color is hard to see, change it in favs.conf."
}

# Parse the command file into a few arrays so the main menu can display grouped
# entries, notes, and ungrouped commands in a consistent order.
loadCommands() #Load commands and assign them to groups
{
  unset cmds cmdGroups cmdLocals groupNames groupCommandCount
  unset topLevelTypes topLevelValues topLevelDisplayTypes topLevelDisplayValues
  local currentGroup=-1
  local commandIndex=0
  local topLevelIndex=0
  local topLevelDisplayIndex=0
  local instructionsEnded=false
  local line
  local groupName

  groupCount=0
  topLevelCount=0

  while IFS= read -r line || [[ -n "$line" ]]
  do
    if [[ "$line" == "$instructionEndMarker" ]]; then
      instructionsEnded=true
    elif [[ ${line:0:2} == "##" ]]; then
      groupName="${line:2}"
      groupName="${groupName# }"
      if [[ -z "$groupName" ]]; then
        # A standalone ## closes the current group.
        currentGroup=-1
      else
        groupNames[$groupCount]="$groupName"
        groupCommandCount[$groupCount]=0
        topLevelTypes[$topLevelIndex]=group
        topLevelValues[$topLevelIndex]=$groupCount
        topLevelDisplayTypes[$topLevelDisplayIndex]=group
        topLevelDisplayValues[$topLevelDisplayIndex]=$topLevelIndex
        currentGroup=$groupCount
        ((groupCount++))
        ((topLevelIndex++))
        ((topLevelDisplayIndex++))
      fi
    elif [[ $instructionsEnded == true && $currentGroup -eq -1 &&
            ${line:0:1} == "#" ]]; then
      topLevelDisplayTypes[$topLevelDisplayIndex]=note
      topLevelDisplayValues[$topLevelDisplayIndex]="$line"
      ((topLevelDisplayIndex++))
    elif [[ -n "$line" && ${line:0:1} != "#" ]]; then
      cmds[$commandIndex]="$line"
      cmdGroups[$commandIndex]="$currentGroup"
      if [[ $currentGroup -ge 0 ]]; then
        cmdLocals[$commandIndex]="${groupCommandCount[$currentGroup]}"
        groupCommandCount[$currentGroup]=$((groupCommandCount[$currentGroup] + 1))
      else
        # Commands outside a group are direct top-level entries.
        topLevelTypes[$topLevelIndex]=command
        topLevelValues[$topLevelIndex]=$commandIndex
        topLevelDisplayTypes[$topLevelDisplayIndex]=command
        topLevelDisplayValues[$topLevelDisplayIndex]=$topLevelIndex
        ((topLevelIndex++))
        ((topLevelDisplayIndex++))
      fi
      ((commandIndex++))
    fi
  done < "$input"

  topLevelCount=$topLevelIndex
}

# Print the commands inside a specific group, including inline comments and
# numbering local to that group.
printGroupCommands() #Print commands within one group
{
  local targetGroup="$1"
  local currentGroup=-1
  local explicitGroup=0
  local commandIndex=0
  local line
  local beforeComment
  local comment
  local groupName

  while IFS= read -r line || [[ -n "$line" ]]
  do
    if [[ ${line:0:2} == "##" ]]; then
      groupName="${line:2}"
      groupName="${groupName# }"
      if [[ -z "$groupName" ]]; then
        currentGroup=-1
      else
        currentGroup=$explicitGroup
        ((explicitGroup++))
      fi
    elif [[ -z "$line" ]]; then
      if [[ $currentGroup -eq $targetGroup ]]; then
        echo ''
      fi
    elif [[ ${line:0:1} == "#" ]]; then
      if [[ $currentGroup -eq $targetGroup ]]; then
        echo -e "${GRAY}${line}${NC}"
      fi
    else
      if [[ $currentGroup -eq $targetGroup ]]; then
        beforeComment="${line%%#*}"
        comment="${line#*$beforeComment}"
        echo -e "${YELLOW}${cmdLocals[$commandIndex]}]${NC} ${beforeComment}${GRAY}${comment}${NC}"
      fi
      ((commandIndex++))
    fi
  done < "$input"
}

#Find a command by group and submenu index
findGlobalCommand() 
{
  local targetGroup="$1"
  local targetLocal="$2"
  local commandIndex

  for ((commandIndex = 0; commandIndex < ${#cmds[@]}; commandIndex++))
  do
    if [[ ${cmdGroups[$commandIndex]} == "$targetGroup" &&
          ${cmdLocals[$commandIndex]} == "$targetLocal" ]]; then
      printf '%s\n' "$commandIndex"
      return 0
    fi
  done

  return 1
}

readEditedCommand() #Read a prepopulated, editable command
{
  local initialCommand="$1"
  local promptText="$2"

  if [[ "${USE_COLORS,,}" =~ ^(false|no|off|0)$ ]]; then
    read -e -i "$initialCommand" -p "$promptText" editedCommand
  else
    read -e -i "$initialCommand" \
      -p "$(printf '\001%b\002%s\001%b\002' "$YELLOW" "$promptText" "$NC")" \
      editedCommand
  fi
}

runCommandAt() #Run a loaded command by its global index
{
  local commandIndex="$1"

  if [[ "$commandIndex" -ge 0 && "$commandIndex" -lt "${#cmds[@]}" ]]; then
    echo -e "${GREEN}running:${NC} ${cmds[$commandIndex]}"
    eval "${cmds[$commandIndex]}"
  else
    echo "error: invalid command index" >&2
    return 1
  fi
}

runGroup() #Open a groups command submenu
{
  local groupIndex="$1"
  local groupInput
  local localIndex
  local globalIndex
  local action
  local promptText

  while true
  do
    echo -e "${YELLOW}--- ${groupNames[$groupIndex]} ---${NC}"
    printGroupCommands "$groupIndex"
    echo "Enter a command number, e/s plus a number to edit, or b to go back"
    echo -ne "${GREEN}${groupNames[$groupIndex]}: ${NC}"
    read groupInput

    case "${groupInput,,}" in
      b)
        return 0
        ;;
      c)
        echo -e "${GREEN}Goodbye${NC}"
        return 2
        ;;
      h)
        usage
        ;;
    esac

    if [[ $groupInput =~ ^([0-9]+)[[:space:]]*[eE]$ ]]; then
      localIndex="${BASH_REMATCH[1]}"
      action=edit
    elif [[ $groupInput =~ ^[eE][[:space:]]*([0-9]+)$ ]]; then
      localIndex="${BASH_REMATCH[1]}"
      action=edit
    elif [[ $groupInput =~ ^([0-9]+)[[:space:]]*[sS]$ ]]; then
      localIndex="${BASH_REMATCH[1]}"
      action=save
    elif [[ $groupInput =~ ^[sS][[:space:]]*([0-9]+)$ ]]; then
      localIndex="${BASH_REMATCH[1]}"
      action=save
    elif [[ $groupInput =~ ^[0-9]+$ ]]; then
      localIndex="$groupInput"
      action=run
    else
      echo "error: enter a command number, e/s plus a number, or b" >&2
      continue
    fi

    if [[ "$localIndex" -lt 0 ||
          "$localIndex" -ge "${groupCommandCount[$groupIndex]}" ]]; then
      echo "error: invalid command number for this group" >&2
      continue
    fi

    globalIndex=$(findGlobalCommand "$groupIndex" "$localIndex") || {
      echo "error: could not find that command" >&2
      continue
    }

    if [[ $action == edit || $action == save ]]; then
      if [[ $action == save ]]; then
        promptText="save/no-run: "
      else
        promptText="edit/run: "
      fi

      readEditedCommand "${cmds[$globalIndex]}" "$promptText"

      if [[ $action == save ]]; then
        saveCommandAt "$globalIndex" "$editedCommand" || return 1
        return 2
      else
        cmds[$globalIndex]="$editedCommand"
      fi
    fi

    runCommandAt "$globalIndex"
    return 2
  done
}

readFavs() #Read cmd file, optionaly print output
{
  loadCommands

  if [[ $1 == print ]]; then
    echo "(e)dit (p)ower (s)ave (t)est colors (u)pdate (g)itUpdate (c)ancel (h)elp"
    echo "Choose a group number to open its command submenu, or choose an ungrouped command"

    displayIndex=0
    for ((displayIndex = 0; displayIndex < ${#topLevelDisplayTypes[@]}; displayIndex++))
    do
      if [[ ${topLevelDisplayTypes[$displayIndex]} == note ]]; then
        echo -e "${GRAY}${topLevelDisplayValues[$displayIndex]}${NC}"
      else
        topIndex="${topLevelDisplayValues[$displayIndex]}"
        if [[ ${topLevelTypes[$topIndex]} == group ]]; then
          groupIndex="${topLevelValues[$topIndex]}"
          echo -e "${YELLOW}${topIndex}]~[ ${groupNames[$groupIndex]} ]${NC} (${groupCommandCount[$groupIndex]} commands)"
        else
          commandIndex="${topLevelValues[$topIndex]}"
          beforeComment="${cmds[$commandIndex]%%#*}"
          comment="${cmds[$commandIndex]#*$beforeComment}"
          echo -e "${GREEN}${topIndex})${NC} ${beforeComment}${GRAY}${comment}${NC}"
        fi
      fi
    done

    if [[ $topLevelCount -eq 0 ]]; then
      echo "No saved commands"
    fi
  fi
}

runPrompt() #Prompt user for a group to open
{
  while true
  do
    echo -ne "${GREEN}run: ${NC}"
    read choiceInput

    case "${choiceInput,,}" in
      c)
        echo -e "${GREEN}Goodbye${NC}"
        return 0
        ;;
      e)
        edit
        return $?
        ;;
      g)
        gitUpdate
        ;;
      p)
        power
        ;;
      s)
        echo -en "${YELLOW}Enter command:${NC} "
        read cInput
        save "$cInput"
        return $?
        ;;
      t)
        testColors
        return $?
        ;;
      u)
        updater
        ;;
      h)
        usage
        ;;
    esac

    if [[ $choiceInput =~ ^([0-9]+)[[:space:]]*[eE]$ ]]; then
      topAction=edit
      topIndex="${BASH_REMATCH[1]}"
    elif [[ $choiceInput =~ ^[eE][[:space:]]*([0-9]+)$ ]]; then
      topAction=edit
      topIndex="${BASH_REMATCH[1]}"
    elif [[ $choiceInput =~ ^([0-9]+)[[:space:]]*[sS]$ ]]; then
      topAction=save
      topIndex="${BASH_REMATCH[1]}"
    elif [[ $choiceInput =~ ^[sS][[:space:]]*([0-9]+)$ ]]; then
      topAction=save
      topIndex="${BASH_REMATCH[1]}"
    else
      topAction=
    fi

    if [[ -n "$topAction" ]]; then
      if [[ "$topIndex" -ge 0 && "$topIndex" -lt "$topLevelCount" ]]; then
        if [[ ${topLevelTypes[$topIndex]} != command ]]; then
          echo "error: e/s only work on ungrouped commands; open the group first" >&2
          continue
        fi

        commandIndex="${topLevelValues[$topIndex]}"
        if [[ $topAction == save ]]; then
          promptText="save/no-run: "
        else
          promptText="edit/run: "
        fi

        readEditedCommand "${cmds[$commandIndex]}" "$promptText"

        if [[ $topAction == save ]]; then
          saveCommandAt "$commandIndex" "$editedCommand" || return 1
          return 0
        else
          cmds[$commandIndex]="$editedCommand"
          runCommandAt "$commandIndex"
          return $?
        fi
      else
        echo "error: invalid top-level number" >&2
        continue
      fi
    fi

    if [[ $choiceInput =~ ^[0-9]+$ ]]; then
      if [[ "$choiceInput" -ge 0 && "$choiceInput" -lt "$topLevelCount" ]]; then
        topLevelType="${topLevelTypes[$choiceInput]}"
        topLevelValue="${topLevelValues[$choiceInput]}"
        if [[ $topLevelType == group ]]; then
          runGroup "$topLevelValue"
          groupStatus=$?
          if [[ $groupStatus -eq 2 ]]; then
            return 0
          fi
          readFavs "print"
        else
          runCommandAt "$topLevelValue"
          return $?
        fi
      else
        echo "error: invalid top-level number" >&2
      fi
    else
      echo "error: enter a group number" >&2
    fi
  done
}

runCMD() #Run selected command
{
  #checks input and runs selection
  re='^[0-9]+$'

  #if choice is a number
  if ! [[ $choice =~ $re ]]; then 
    echo "error: Not a number" >&2; return 1
  fi
  #if choice is a number in the range of cmds
  if [[ $choice -ge 0  && ${#cmds[@]} -gt $choice ]]; then
    echo -e "${GREEN}running:${NC} ${cmds[$choice]}"
    eval ${cmds[$choice]}
  else
    echo "error: invaild input! int out of range!"  >&2; return 1
  fi
}

usage() #Display this help text and exit
{
  echo "Usage: favs.sh [-egilpu] [-s newCMD] [-r CMD_index]"
  echo "-e              Edit command list"
  echo "-g              Update Favs from Git repo"
  echo "-i              Install the f() function in ~/.bashrc"
  echo "-l              List saved commands"
  echo "-p              Power, reboot, shutdown"    
  echo "-r              Run saved command using index number"
  echo "-s              Save newCMD into favs.txt"
  echo "-u              Run apt-get update && upgrage"
  echo "-h              Display this help text and exit"
  return 2
}

installFunction() #Install or update the interactive shell function
{
  local rcFile="${FAVS_RC_FILE:-$HOME/.bashrc}"
  local startMarker='# >>> favs shell function >>>'
  local endMarker='# <<< favs shell function <<<'
  local tmpFile

  mkdir -p "$(dirname "$rcFile")" || return 1
  touch "$rcFile" || return 1
  tmpFile=$(mktemp "${rcFile}.tmp.XXXXXX") || return 1

  awk -v startMarker="$startMarker" -v endMarker="$endMarker" '
    $0 == startMarker { skipping=1; found=1; next }
    $0 == endMarker { skipping=0; next }
    !skipping { print }
    END { if (found) print "" }
  ' "$rcFile" > "$tmpFile" || {
    rm -f "$tmpFile"
    return 1
  }

  cat >> "$tmpFile" <<EOF

$startMarker
unalias f 2>/dev/null || true
f() {
  source "$scriptDir/favs.sh" "\$@"
}
$endMarker
EOF

  mv "$tmpFile" "$rcFile" || {
    rm -f "$tmpFile"
    return 1
  }

  echo "Installed f() in $rcFile"
  echo "Run: source $rcFile"
}

# Entry point: parse CLI flags and either run one-off actions like -l or -s, or
# fall back to the interactive menu when no option is supplied.
main()
{
  local OPTIND=1

  #options when running command (ie. f -l)
  while getopts ':egilpr:s:u?h' c
  do
    case $c in
      e) edit
        readFavs "print"
        return $? ;;
      g) gitUpdate; return $? ;;
      i) installFunction; return $? ;;
      l) readFavs "print"
         return  ;;
      p) power; return $? ;;
      r) choice=$OPTARG
         readFavs
         runCMD
         return $? ;;
      s) save "$OPTARG"
         return $? ;;
      u) updater; return $? ;;
      h|?) usage; return $? ;;
    esac
  done

  #when no options or arguments are given
  readFavs "print"
  runPrompt
}

main "$@"
