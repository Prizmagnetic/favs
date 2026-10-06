# Developer notes

## Runtime model

`favs.sh` is both executable and sourceable. The `f()` function installed in
`~/.bashrc` sources the script on every invocation, so `favs.txt`, `favs.conf`,
and `default.txt` are resolved at use time rather than only at shell startup.
The script deliberately calls `main` when sourced because sourcing is an
interactive user action, not a library-only load.

Resource files are located beside `favs.sh`. Commands execute in the caller's
current directory when the script is sourced, and in the child process's
current directory when it is executed with `bash`.

## favs.txt format

A newly created `favs.txt` starts with comment-only instructions and the exact
marker `# === END FAVS INSTRUCTIONS ===`. Comments before the marker are hidden
from the menu. Standalone comments after the marker are visible notes and do
not receive indexes. Comments in a group are displayed in that group's
submenu. Command lines are still evaluated as Bash through `eval`, so saved
commands must be treated as trusted input.

`default.txt` is the example/template file. A normal first save creates a
personal file without copying all examples. Saving an edited default command
is an explicit action and materializes the examples into the personal file,
while preserving the instruction header.

## Testing

Run the focused shell tests from the repository root:

```bash
bash test/test_favs.sh
```

The test harness uses a temporary script directory and temporary `HOME`. It
sets `FAVS_EDITOR=true` for editor paths so tests never start `nano` or wait
for interactive input. Keep tests in clean non-interactive Bash where possible:
container shell startup hooks can add unrelated output or tracing.

## Installer behavior

`-i` manages a marked block in `~/.bashrc`. The `FAVS_RC_FILE` environment
variable is supported for isolated tests and troubleshooting. Running `-i`
again replaces only the marked favs block and leaves unrelated rc content
alone.

## Follow-up work

- Add an explicit command for copying selected examples from `default.txt`.
- Consider replacing `eval` with a more constrained execution model if the
  project ever accepts untrusted command files.
- Improve portability for package update and power shortcuts on non-Debian
  systems.
- Revisit index-based `-r` behavior if group editing becomes more common.
