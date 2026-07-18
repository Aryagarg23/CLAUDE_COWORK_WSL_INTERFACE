' cowork-wsl-bridge — hidden launcher.
' Starts the bridge daemon in WSL with no visible window.
' Safe to run repeatedly: runner.sh has a single-instance guard.
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
Set sh = CreateObject("WScript.Shell")
sh.Run "wsl.exe --cd """ & scriptDir & """ -e bash runner.sh", 0, False
