#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Res_Description=Automation test server
#AutoIt3Wrapper_Res_Fileversion=2.11.29.6
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#pragma compile(Icon, clouds.ico)
;
; Test Server for CopTrax
; Version: 1.0
; Language:       AutoIt
; Platform:       Win8 or Win10
; Script Function:
;	Read test case from file
;   Listen for the target CopTrax box, waiting its powerup and connection to the server;
;   Send test commands from the test case to individual target(client);
;	Receive test results from the target(client), verify it passed or failed, log the result;
;	Drop the connection to the client when the test completed.
; Author: George Sun
; Nov., 2017
;

#include <Constants.au3>
#include <Timers.au3>
#include <File.au3>
#include <Date.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>

HotKeySet("!{Esc}", "HotKeyPressed") ; Alt-Esc to stop testing

Global Const $max_connections = 10	; define the max client numbers
Local $ipServer = @IPAddress1
Local $port = 16869
Global $workDir = "C:\CopTraxTest\"

TCPStartup() ; Start the TCP service.
OnAutoItExitRegister("OnAutoItExit")	; Register OnAutoItExit to be called when the script is closed.
Global $TCPListen = TCPListen ($ipServer, $port, $max_connections)

Local $testCaseFile = $workDir & "test_case.txt"
Global $testCommands = "hold " & readTestCase($testCaseFile); globally store the commands in test case

MsgBox($MB_OK, "CopTrax Remote Test Server", "The test cases shall be in " & $testCaseFile & @CRLF & "The server is " & $ipServer & ":" & $port, 5)

Dim $Sockets[$max_connections + 1], $logFiles[$max_connections + 3], $commands[$max_connections + 1]
Dim $commandTimers[$max_connections + 1], $connectionTimers[$max_connections + 1], $transFiles[$max_connections + 1]
Dim $byteCounter[$max_connections + 1], $fileToBeSent[$max_connections + 1], $heartBeatTimers[$max_connections + 1]
Dim $hGUI[$max_connections + 3], $gGUI[$max_connections + 3]
Dim $offsetX[$max_connections + 3], $offsetY[$max_connections + 3]
Dim $testRslt[$max_connections + 1], $boxID[$max_connections + 1]

Local $i
For $i = 0 To $max_connections
   $Sockets[$i] = 0	; Stores the sockets for each client
   $connectionTimers[$i] = 0
   $commandTimers[$i] = 0
   $heartBeatTimers[$i] = 0
   $transFiles[$i] = ""
   $fileToBeSent[$i] = ""
Next

For $i = 1 To 4
   Local $x = ($i - 1 - Floor(($i-1)/4)*3) * 480
   $offsetX[$i] = $x
   $offsetY[$i] = 0
   $offsetX[$i+5] = $x
   $offsetY[$i+5] = 360*2
Next
$offsetX[5] = $offsetX[1]
$offsetY[5] = 360
$offsetX[6] = $offsetX[4]
$offsetY[6] = 360
$offsetX[11] = $offsetX[2]
$offsetY[11] = 360
$offsetX[12] = $offsetX[3]
$offsetY[12] = 360			; arrage the 12 windows in the right places

; the window 11 will display the main test result
$hGUI[11] = GUICreate("Server " & $ipServer & ":" & $port, 480,360)
$gGUI[11] = GUICtrlCreateEdit("", 2, 2, 475, 355, $WS_VSCROLL)
GUICtrlSetFont($gGUI[11], 9, 400, 0, "Courier New")
GUISetState(@SW_SHOW)
WinMove($hGUI[11], "", $offsetX[11], $offsetY[11])
$logFiles[11] =FileOpen($workDir & "log\automationtest.log", 1+8) 	; Clear the client name for future updating from the client

Global $hTimer = TimerInit()	; global timer handle
Global $leakMsg = ""
Global $testEnd = False

While Not $testEnd
   _Accept_Connection()	; accept new client's connection requist

   Local $i, $Recv
   Local $currentTime = TimerDiff($hTimer)	; get current timer elaspe
   For $i = 1 To $max_connections
	  If $Sockets[$i] <> 0 Then
		 $Recv = TCPRecv($Sockets[$i],1000000)
		 If $Recv <> "" Then
			processReply($i, $leakMsg & $Recv)
			$connectionTimers[$i] = $currentTime + 2000*60 ; renew the heart-beat check timer
		 EndIf

		 If $currentTime > $commandTimers[$i] Then	; check if it is time for next command
			parseCommand($i)	; get the new test command executed, the new timer is set in it
		 EndIf

		 If ($currentTime > $heartBeatTimers[$i]) And ($currentTime < $commandTimers[$i] - 50*1000) Then ; check the heart-beat timer
			sendCommand($i, "status")	; send a command for heart_beat
			pushCommand($i, "hold")	; hold any new command from executing only after get a continue response from the client
			$heartBeatTimers[$i] = $currentTime + 60*1000;
			logWrite($i, "(Server) Send status command to client.")
		 EndIf

		 If $currentTime > $connectionTimers[$i] Then	; test if the client is alive
			logWrite($i, "(Server) Connection to client lost.")
			logWrite(11, $boxID[$i] & " connection lost.")
			closeConnection($i)
		 EndIf
	  EndIf
   Next
   Sleep (100)
 WEnd

OnAutoItExit()

Exit

Func closeConnection($n)
	Local $s = "==================================="
	$s &= $s & $s
	logWrite($n, $s)
	logWrite($n, " ")
	FileClose($logFiles[$n])	; Close the log file
	GUIDelete($hGUI[$n])
	TCPCloseSocket($Sockets[$n])	; Close the TCP connection to the client
	$Sockets[$n] = 0	; clear the soket index
	$Sockets[0] -= 1 ; reduce the total number of connection
	logWrite(11, "Current " & $Sockets[0] & " connected.")
EndFunc

Func parseCommand($n)
	Local $newCommand = popCommand($n)

	If $newCommand = "" Then 	; no command left to be precessed
		logWrite($n, "All tests passed.")
		logWrite(11, $boxID[$n] & " all tests passed.")
		closeConnection($n)
		Return
	EndIf

	Local $currentTime = TimerDiff($hTimer)
	$commandTimers[$n] =  $currentTime + 10*1000 ; time for next command to be executed

	Local $nn, $mm
	Switch $newCommand	; process the new command
		Case "record"
			sendCommand($n, $newCommand)	; send new test command to client

			$mm = int(popCommand($n))
			$nn = int(popCommand($n))
			If $nn > 1 Then
				$nn -= 1;
				pushCommand($n, "hold endrecord " & $newCommand & " " & $mm & " " & $nn)
			Else
				pushCommand($n, "hold endrecord")	; hold any new command from executing only after get a continue response from the client
			EndIf
			$commandTimers[$n] += ($mm * 60 - 10) * 1000	; set the next command timer xx minutes later
			logWrite($n, "(Server) Sent " & $newCommand & " command to client. The stop record command will be sent in " & $mm & " mins.")

		Case "endrecord"
			sendCommand($n, $newCommand)	; send new test command to client
			pushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			$commandTimers[$n] +=  10 * 60 * 1000	; set the next command timer 10 mins later
			logWrite($n, "(Server) Sent " & $newCommand & " command to client. Pause for 10 mins till next command.")

		Case "settings", "login"
			$mm = popCommand($n)
			$nn = popCommand($n)
			sendCommand($n, $newCommand & " " & $mm & " " & $nn)	; send new test command to client
			pushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			logWrite($n, "(Server) Sent " & $newCommand & " " & $mm & " " & $nn & " command to client.")
			$commandTimers[$n] += 5*1000	; add 5 more seconds

		Case "camera", "upload"
			$nn = popCommand($n)
			sendCommand($n, $newCommand & " " & $nn)	; send new test command to client
			pushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			logWrite($n, "(Server) Sent " & $newCommand & " " & $nn & " command to client.")
			$commandTimers[$n] += 10*1000	; add 10 more seconds for upload function to be activiate

		Case "pause"
			$nn = popCommand($n)
			$commandTimers[$n] +=  Int($nn) * 60 * 1000	; set the next command timer $nn mins later
			logWrite($n, "(Server) Pause for " & $nn & " minutes.")

		Case "review", "photo", "info", "status", "eof", "checkrecord", "restart", "radar", "quit", "stopapp", "runapp", "cleanup"
			sendCommand($n, $newCommand)	; send new test command to client
			pushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			logWrite($n, "(Server) Sent " & $newCommand & " command to client.")

		Case "synctime"
			$nn = @YEAR & @MON & @MDAY & @HOUR & @MIN & @SEC
			sendCommand($n, $newCommand & " " & $nn)	; send new test command to client
			pushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			logWrite($n, "(Server) Sent " & $newCommand & " " & $nn & " command to client.")

		Case "synctmz"
			$nn = _Date_Time_GetTimeZoneInformation ( )
			$mm = $nn[2]
			sendCommand($n, $newCommand & " " & $mm)	; send new test command to client
			pushCommand($n, "hold")	; hold any new command from executing only after get a continue response from the client
			logWrite($n, "(Server) Sent " & $newCommand & " " & $mm & " command to client.")

		Case "update"
			Local $fileName = popCommand($n)
			Local $file
			Local $netFileName = StringSplit($fileName, "\")
			Local $sourceFileName = $workDir & "latest\" & $netFileName[$netFileName[0]]	; all file need to be update shall sit in \latest folder
			If FileGetSize($sourceFileName) > 50000 Then
				$file = FileOpen($sourceFileName,16)	; open file for read only in binary mode
			Else
				$file = FileOpen($sourceFileName,0)	; open file for read only in binary mode
			EndIf
			$fileToBeSent[$n] = FileRead($file)
			FileClose($file)
			Local $fLen = StringLen($fileToBeSent[$n])
			$newCommand &= " " & $fileName & " " & $fLen
			sendCommand($n, $newCommand)	; send new test command to client
			logWrite($n, "(Server) Sent " & $newCommand & " command to client.")
			logWrite($n, "(Server) Sending " & $sourceFileName & " in server to update " & $fileName & " in client.")
			pushCommand($n, "hold send hold")	; hold any new command from executing only after get a continue response from the client

		Case "send"
			sendCommand($n, $fileToBeSent[$n])	; send file to client
			logWrite($n,"(Server) File sent to client.")

		Case "hold"
			pushCommand($n, "hold")	; the hold command can only be released by receive a contiue reply from the client

   EndSwitch
EndFunc

Func logWrite($n,$s)
	If $n <= $max_connections + 1 Then _FileWriteLog($logFiles[$n],$s)
	GUICtrlSetData($gGui[$n], $s & @crlf, 1)
EndFunc

Func readTestCase($fileName)
   Local $testFile = FileOpen($fileName,0)	; for test case reading, readonly
   Local $fileEnds = False
   Local $aLine, $commands
   Local $m, $n
   Do
	  $aLine = StringSplit(StringLower(FileReadLine($testFile)), " ")

	  Switch $aLine[1]
		 Case "record", "settings", "login"
			If $aLine[0] < 2 Then
			   $m = "1"
			Else
			   $m = StringLeft($aLine[2],5)
			EndIf

			If $aLine[0] < 3 Then
			   $n = "1"
			Else
			   $n = StringLeft($aLine[3],8)
			EndIf

			$commands &= $aLine[1] & " " & $m & " " & $n & " "

		 Case "camera", "upload", "update", "pause"
			If $aLine[0] < 2 Then
			   $m = "1"
			Else
			   $m = $aLine[2]
			EndIf
			$commands &= $aLine[1] & " " & $m & " "

		 Case "review", "photo", "settings", "info", "status", "checkrecord", "restart", "stopapp", "radar", "quit", "runapp", "synctime", "synctmz", "cleanup"
			$commands &= $aLine[1] & " "
		 EndSwitch
   Until $aLine[1] = ""

   FileClose($testFile)
   Return $commands
EndFunc

Func processReply($n, $reply)
	Local $msg = StringSplit($reply, " ")
	Local $len
	If $transFiles[$n] <> "" Then	; This indicates the coming message shall be saved in file
		FileWrite($transFiles[$n], $reply)
		$len = StringLen($reply)
		logWrite($n, "(Server) Received " & $len & " bytes, write them to file.")
		$byteCounter[$n] -= $len

		If $byteCounter[$n] <= 10 Then
			FileClose($transFiles[$n])	; get and save the file
			$transFiles[$n] = ""	;clear the flag when file transfer ends
			sendCommand($n, "eof")	; send "eof" command to client
			logWrite($n,"(Server) Send eof to client.")
		EndIf
		Return
	EndIf

	If StringLen($reply) < 10 Then
		logWrite($n, "(Client) Sent " & $reply & " message to server. ")	; write the returned results into the log file
	Else
		logWrite($n, "(Client) " & $reply)	; write the returned results into the log file
	EndIf

	Switch StringLower($msg[1])
		Case "failed"
			popCommand($n)	; unhold the test command by delete the first 5 letters from commands
			$testRslt[$n] = False
			logWrite(11, $boxID[$n] & " " & $reply)

		Case "quit"
			$testRslt[$n] = False
			logWrite(11, $boxID[$n] & " quit test.")
			closeConnection($n)

		Case "continue", "passed"
			popCommand($n)	; unhold the test command by delete the first 5 letters from commands
			ConsoleWrite($commands[$n] & @crlf)

		Case "file"
			Local $fileName = $msg[2]
			Local $len =  Int($msg[3])
			Local $netFileName = StringSplit($fileName, "\")
			Local $destFileName = $workDir & "ClientFiles\" & $netFileName[$netFileName[0]]
			logWrite($n, $fileName & " from client is going to be saved as " & $destFileName & " in server.")
			logWrite($n, "Total " & $len & " bytes need to be stransfered.")
			$transFiles[$n] = FileOpen($destFileName,16+2)	; open file for over-write
			$byteCounter[$n] = $len
			pushCommand($n,"hold")
			sendCommand($n, "send")	; send "send" command to client to trigger the file transfer
			logWrite($n, "(Server) sent send command to client.")

		Case "name"
			Local $filename = $workDir & "log\" & $msg[2] & ".log"
			$logFiles[$n] = FileOpen($filename, 1+8) ; open log file for append write in text mode
			$boxID[$n] = $msg[2]	; get the boxID from client
			Local $boxUser = $msg[3]	; get the CopTrax App current user
			Local $clientVersion = $msg[4]	; get the App length
			Local $latestVersion = FileGetVersion($workDir & "latest\CopTraxTestClient.exe")
			Local $clientIP = SocketToIP($Sockets[$n])
			logWrite(11, $boxID[$n] & " connected on " & $clientIP & ".")

			$hGUI[$n] = GUICreate($boxID[$n], 480,360)
			$gGUI[$n] = GUICtrlCreateEdit("", 2, 2, 475, 355, $WS_VSCROLL)
			GUICtrlSetFont($gGUI[$n], 9, 400, 0, "Courier New")
			GUISetState(@SW_SHOW)
			WinMove($hGUI[$n], "", $offsetX[$n], $offsetY[$n])

			$filename = $workdir & $boxID[$n] & ".txt"	; try to find if any individual test case exits
			Local $iCommands = readTestCase($filename)
			If $iCommands <> "" Then
				$commands[$n] = $iCommands	; Stores the whole test case
			Else
				popCommand($n)
			EndIf

			Local $s = "==================================="
			$s &= $s & $s
			logWrite($n, " ")
			logWrite($n, $s)
			logWrite($n, " Automation test for CopTrax DVR box " & $boxID[$n])
			logWrite($n, " Current user of the box : " & $boxUser)
			logWrite($n, " The test case is : ")
			logWrite($n, $commands[$n])
			logWrite($n, $s)
			logWrite($n, "(Client) " & $reply)	; write the returned results into the log file
			If $clientVersion <> $latestVersion Then
				pushCommand($n, "update C:\CopTraxTest\tmp\CopTraxTestClient.exe update c:\coptraxtest\tmp\restartclient.bat restart")
				logWrite($n, "Updating the automation tester to " & $latestVersion & ". Test will restart.")
			EndIf

	EndSwitch
EndFunc

Func OnAutoItExit()
   TCPShutdown() ; Close the TCP service.
   Local $i
   For $i = 0 To $max_connections
	  If $logFiles[$i] <> 0 Then
		 FileClose($logFiles[$i])
		 $logFiles[$i] = 0
	  EndIf
   Next
   FileClose($logFiles[11])
EndFunc   ;==>OnAutoItExit

Func _Accept_Connection ()
	If $Sockets[0] = $max_connections Then Return
	;Makes sure no more Connections can be made.
	Local $Accept = TCPAccept($TCPListen)     ;Accepts incomming connections.
	If $Accept = -1 Then Return

	Local $currentTime = TimerDiff($hTimer)
	Local $pattern = ""
	For $i = 1 To $max_connections
		If $Sockets[$i] = 0 Then	;Find the first open socket.
			$heartBeatTimers[$i] = $currentTime + 1000*60
			$Sockets[$i] = $Accept	;assigns that socket the incomming connection.
			$logFiles[$i] = ""	; Clear the client name for future updating from the client
			$commands[$i] = $testCommands	; Stores the whole test case that will let the target machine run. When empty indicates that the target has completed all the test
			$commandTimers[$i] = $currentTime + 1000	; Set command timer to be 1s later
			$connectionTimers[$i] = $currentTime + 2000*60	; Set connection lost timer to be 2mins later
			$Sockets[0] += 1   ;adds one to the Socket list.
			$testRslt[$i] = True	; initialize the result true until any failure
			logWrite(11, "Current " & $Sockets[0] & " connected. " & $pattern)
			Return
		EndIf
		$pattern += "x"
	Next
EndFunc

Func popCommand($n)
   Local $newCommand = StringSplit(StringLower($commands[$n]), " ")
   If $newCommand[0] > 1 Then
	  Local $lengthCommand = StringLen($newCommand[1] & " ")
	  $commands[$n] = StringTrimLeft($commands[$n],$lengthCommand)
	  return $newCommand[1]
   Else
	  return ""
   EndIf
EndFunc

Func pushCommand($n, $newCommand)
   $commands[$n] = $newCommand & " " & $commands[$n]
EndFunc

Func sendCommand($n, $command)
	 TCPSend($Sockets[$n], $command)
	 $heartBeatTimers[$n] = TimerDiff($hTimer) + 60 * 1000
EndFunc

Func HotKeyPressed()
   Switch @HotKeyPressed ; The last hotkey pressed.
	  Case "!{Esc}" ; KeyStroke is the {ESC} hotkey. to stop testing and quit
	  $testEnd = True	;	Stop testing marker

    EndSwitch
 EndFunc   ;==>HotKeyPressed

Func SocketToIP($iSocket)
    Local $tSockAddr = 0, $aRet = 0
    $tSockAddr = DllStructCreate("short;ushort;uint;char[8]")
    $aRet = DllCall("Ws2_32.dll", "int", "getpeername", "int", $iSocket, "struct*", $tSockAddr, "int*", DllStructGetSize($tSockAddr))
    If Not @error And $aRet[0] = 0 Then
        $aRet = DllCall("Ws2_32.dll", "str", "inet_ntoa", "int", DllStructGetData($tSockAddr, 3))
        If Not @error Then Return $aRet[0]
    EndIf
    Return 0
EndFunc   ;==>SocketToIP
