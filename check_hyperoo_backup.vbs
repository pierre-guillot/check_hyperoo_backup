' =========================================================
' check_hyperoo
' =========================================================

' Required Variables
Const PROGNAME = "check_hyperoo"
Const VERSION = "0.1.2"


' Default settings
threshold_warning = 10
threshold_critical = 20
alias = "default"
programData = "C:\ProgramData\HyperooSoftware\Hyperoo2.0\Client\Logs\"
successAllFileHaveBeenReceived = false
successcompletedFileTransfered = false
successSuccessfullyCalledDeleteSnapshotSet = false

' ---------------- Variables
Dim logInfoFind(3)
logInfoFind(0) = "allFileHaveBeenReceived"
logInfoFind(1) = "completedFileTransfered"
logInfoFind(2) = "SuccessfullyCalledDeleteSnapshotSet"

Dim dictLog
Set dictLog = CreateObject("Scripting.Dictionary")
dictLog.Add "allFileHaveBeenReceived", "All files have been received"
dictLog.Add "completedFileTransfered", "Completed file transfer"
dictLog.Add "SuccessfullyCalledDeleteSnapshotSet", "Successfully called DeleteSnapshotSet"

Dim dictLogSuccess
Set dictLogSuccess = CreateObject("Scripting.Dictionary")
dictLogSuccess.Add "allFileHaveBeenReceived", false
dictLogSuccess.Add "completedFileTransfered", false
dictLogSuccess.Add "SuccessfullyCalledDeleteSnapshotSet", false

' Add nagiosplugins library
Function Include(vbsFile)
    Dim fso, f, s
    Set fso = CreateObject("Scripting.FileSystemObject")
    Set f = fso.OpenTextFile(vbsFile)
    s = f.ReadAll()
    f.Close 
    ExecuteGlobal s
End Function

Include "scripts\lib\NagiosPlugins.vbs"

' Create the NagiosPlugin object
Set np = New NagiosPlugin

' Define what args that should be used
np.add_arg "backup", "Name Of the Backup", 1
np.add_arg "warning", "Number of hours since last backup (Warn)", 1
np.add_arg "critical", "Number of hours since last backup (Crit)", 1

' If we have no args or arglist contains /help or not all of the required arguments are fulfilled show the usage output,.
If Args.Count < 1 Or Args.Exists("help") Or np.parse_args = 0 Then
	np.Usage
End If

' If we define /warning /critical on commandline it should override the script default.
If Args.Exists("warning") Then threshold_warning = Args("warning")
If Args.Exists("critical") Then threshold_critical = Args("critical")
If Args.Exists("alias") Then alias = Args("alias")
np.set_thresholds threshold_warning, threshold_critical

' ---------------- Find the most recent backup logfile
Dim fso, path, file, recentDate, recentFile
Set fso = CreateObject("Scripting.FileSystemObject")
Set recentFile = Nothing
For Each file in fso.GetFolder(programData).Files

	if (InStr(file,Args.Item("backup")) > 0 ) then 	' Filter for get log file for specified backup
		If (recentFile is Nothing) Then
			Set recentFile = file
		ElseIf (file.DateLastModified > recentFile.DateLastModified) Then
			Set recentFile = file
			dateFile = recentFile.DateLastModified
		End If
	End If
Next


if (recentFile is Nothing) then
	return_code = 3
	msg = "Logfile for backup "  & Args.Item("backup") & " is missing"
	np.nagios_exit msg, return_code
End If 

' ---------------- Control the date of the last file (ie, last backup)
' Set the msg output to be used (OK/WARNING/CRITICAL/UNKNOWN will be applied automaticly)
return_code = np.check_threshold(DateDiff("h",dateFile,Now()))
If ( return_code > 0 ) then
	return_code = 2
	msg = "Backup "  & Args.Item("backup") & " is " & DateDiff("h",dateFile,Now()) & " hours old"
	np.nagios_exit msg, return_code
End If


' ---------------- Read log file
Set fso = CreateObject("Scripting.FileSystemObject")
Set f = fso.OpenTextFile(recentFile)
do while not f.AtEndOfStream
	ligne = f.readLine
	For i = 0 To (UBound(logInfoFind)-1)
			If InStr(1, ligne , dictLog(logInfoFind(i))) > 0 then
				dictLogSuccess(logInfoFind(i)) = true
				rem Wscript.Echo ""
			End If

	Next
loop 
f.close

if((dictLogSuccess("allFileHaveBeenReceived")) and (dictLogSuccess("completedFileTransfered")) and (dictLogSuccess("SuccessfullyCalledDeleteSnapshotSet"))) then
	return_code = 0
	msg = "backup " & Args.Item("backup") & " is OK"
Else
	return_code = 2
	msg = "Errors on backup " & Args.Item("backup") & " was detected!"
End If

' Nice Exit with msg and exitcode
np.nagios_exit msg, return_code
