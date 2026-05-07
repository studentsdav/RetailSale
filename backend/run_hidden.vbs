Set objShell = CreateObject("Wscript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Get the exact folder where this VBScript is located
strPath = objFSO.GetParentFolderName(WScript.ScriptFullName)

' Set the working directory to that folder
objShell.CurrentDirectory = strPath

' Run server.exe silently (0) from that exact folder
objShell.Run chr(34) & strPath & "\server.exe" & chr(34), 0, False

Set objShell = Nothing
Set objFSO = Nothing