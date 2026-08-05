# Linux `.comics` registration

Install the metadata for the current user with an absolute executable path:

```sh
./install-user.sh "/opt/Comics Editor/comics_editor"
```

The helper installs into `${XDG_DATA_HOME:-$HOME/.local/share}`, refreshes MIME
and desktop caches when their utilities are available, and registers Comics
Editor as a candidate without changing the user's default application. Run
`uninstall-user.sh` to remove only these two metadata files.
