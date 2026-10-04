Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
folder = fso.GetParentFolderName(WScript.ScriptFullName)
If fso.FileExists(folder & "\dist\WeTypeCompanion\WeTypeCompanion.exe") Then
  shell.Run """" & folder & "\dist\WeTypeCompanion\WeTypeCompanion.exe""", 0, False
Else
  shell.Run "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & folder & "\App.ps1""", 0, False
End If
