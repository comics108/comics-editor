# Windows `.comics` registration

An installer can register Comics Editor for the current user without elevation:

```powershell
.\Register-ComicsFileAssociation.ps1 -ExecutablePath "C:\Apps\Comics Editor\comics_editor.exe"
```

Preview all writes safely with `-WhatIf`. The helper adds an OpenWith ProgID and
Default Apps capabilities; it does not replace an explicit Windows default.
Run `Unregister-ComicsFileAssociation.ps1` during uninstall to remove only the
keys and values owned by Comics Editor.
