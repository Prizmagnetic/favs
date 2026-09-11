# favs
bash script for storing and using your favorite bash commands


# Install
`git clone https://github.com/Prizmagnetic/favs.git`


# Save alias to run favs as "f"
`echo "alias f='~/favs/favs.sh'" >> ~/.bash_aliases`

need to relogin to take effect

# Run in the current shell
`source ./favs.sh`

Sourcing opens the same interactive prompt as `bash ./favs.sh`, while commands
such as `cd` affect the current shell. Use `c` to return to the shell without
exiting it.
