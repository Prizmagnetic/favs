# favs

`favs` is an interactive Bash helper for keeping and running frequently used
terminal commands. It is designed to be sourced, so commands such as `cd`
can change the current shell.

## Install the `f` command

From the project directory, run:

```bash
bash favs.sh -i
source ~/.bashrc
```

The installer adds an idempotent `f()` function to `~/.bashrc`. The function
definition is loaded when Bash starts, but `favs.sh` and `favs.txt` are loaded
again every time you run `f`. Changes to `favs.txt` therefore take effect in
the current terminal session; restarting Bash is not required.

## Test suite

The project includes a regression script at [test/test_favs.sh](test/test_favs.sh). It exercises the main CLI paths, menu behavior, note filtering, grouped commands, installer behavior, and editor launch flow. Run it with:

```bash
bash test/test_favs.sh
```

## Use it

Run the interactive menu:

```bash
f
```

You can also source the script directly:

```bash
source /path/to/favs.sh
```

Direct execution is available for non-shell-changing operations:

```bash
bash /path/to/favs.sh -l
bash /path/to/favs.sh -s 'git status'
```

Only sourcing can change the caller's current directory. Running
`bash favs.sh` in a child process cannot change the parent shell.

## Command files

The files beside `favs.sh` have distinct roles:

- `default.txt` contains example commands and is not modified by `favs`.
- `favs.txt` contains the user's personal commands.
- `favs.conf` contains color settings.

When `favs.txt` does not exist, `favs` reads `default.txt`. Saving a command or
opening the editor creates `favs.txt` with a comment-only instruction header.
The header ends at:

```text
# === END FAVS INSTRUCTIONS ===
```

Comments before that marker are hidden from the menu but remain visible when
editing `favs.txt`. Standalone comments after the marker are displayed as
unnumbered notes. They do not affect command indexes. Comments inside a
`## Group Name` section are shown in that group's submenu.

To add an example to your personal list, copy it from `default.txt` into
`favs.txt` or save an edited example through the menu.

## Options

```text
-e              Edit command list
-g              Update favs from its Git repository
-i              Install the f() function in ~/.bashrc
-l              List commands without opening the menu
-p              Power, reboot, or shutdown shortcuts
-r INDEX        Run a command by its current index
-s COMMAND      Save a command without running it
-u              Run apt update and upgrade
-h              Display help
```

Interactive selection is preferred over `-r INDEX`, because adding or
reordering groups can change indexes.

## Configuration

Set `USE_COLORS=false` in `favs.conf` to disable color output. Set
`FAVS_EDITOR` or `EDITOR` to choose the editor used by `-e`; `nano` is the
fallback.
