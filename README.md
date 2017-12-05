# CopTraxAutomation
Automation Test for CopTrax Project
CopTrax Automation Test Tool Set
This automated test tool set is designed for the regression test of CopTrax project. The objective is to help the developer to locate the hidden software or hardware bugs before the product release. It can also help the manufactures to do the last test and setup before massive shipment.
The tool set is server-client structured. One server may support and control the automated test for at least 10 boxes. 
The setup of the networks
The server and the client shall have the access to local Ethernet networks, so that they may talk over TCP/IP protocol. The test tool set occupies the port 16869. Check with the network administrator to make sure this port is not conflict with any other settings in the networks. Typically, there is no conflict. Currently, communication over internet is not supported.
The setup of the automation test server
The server need to be a Windows based machine or virtual machine running an OS Win7, Win8+, or Win10, with memory at least 8G and a disk space at least 500G. 
1.	Make a folder C:\CopTraxTest and its sub-folder C:\CopTraxTest\log and C:\CopTraxTest\latest
2.	Copy CopTraxTestServer.exe and test_case.txt to the folder C:\CopTraxTest
3.	Create a test case by editing the test_case.txt with a text editor.
4.	Run CopTraxTestServer.exe. The automation starts.
5.	The server will read the general test case from test_Case.txt. The file can be modified manually by any text editor. 
6.	Write down the IP address shows on the screen. This IP address is used for clients to communicate with the server.
7.	The log files and all other files that the clients send to the server are stored under C:\CopTraxTest\log. The log file has a filename of its Serial Number and .txt 
8.	In each log files, every line begins with a time stamp.
9.	In case there will be files sending to the client, the files are stored in C:\CopTraxTest\latest. Typically, the latest client software is placed here, so that the client software will be automatically updated to the latest version.
10.	When a new client is connected, if there exists a file with its serialnumber.txt, the server will read it as the individual test case.
The setup of the client
1.	Make a folder C:\CopTraxTest and its sub-folder C:\CopTraxTest\tmp
2.	Copy CopTraxTestClient.exe and config.cfg to the folder C:\CopTraxTest; copy restartclient.bat to C:\CopTraxTest\tmp
3.	The file client.cfg contains the basic configuration of server IP address, port and client SN for the automation test. It can be edited by text editor. Make sure the IP address and the port are identical to the server.
4.	Run CopTraxTestClient.exe, and the automation test will start.
5.	The client is of self-updated. It will check with the server for the latest version of the software. In case there is an update in the server, the client will automatically download the latest version and restart.
The test case scripts 
All test cases are written in text. A test case contains a serial test commands or instructions that will be executed in series. The supported test commands are as following. All of them are case insensitive.
Record min n	
This command will let the client to record for min minutes and repeat it for n times. There will be 10 minutes pause after each record.
Camera n	
This command will let the client switch camera and then click n times on the screen to change the front-seat or back-seat camera. The screen snaps will be taken and upload to the server later during the idle period.
Review		
This command will trigger the review window and then close it.
Photo		
This will trigger the photo taken window and then close it.
Radar		
This will trigger the radar window and then take a snap of the window. The captured file will be upload to the server automatically later during the idle period.
Settings pre chunk	
This command will set the pre-event time to pre seconds and Chunk time to chunk minutes. The box SN and the firmware version will also be reported.
CheckChunk	
This command will check the last recorded files to verify the chunk time and other issues.
Status
This command will let the client box report its memory and CPU usage. This command will be send to the client during idle period as the heart beat check between the client and the server.
Login user pwd 
This command will allow a new user to register, they user name is 4-5 characters 
Upload filename_with_path_in_client 
This command will upload the file in the client to the server. The filename shall have the full path in the client. The uploaded file will be saved in C:\CopTraxTest\log
Upgrade filename_with_path_in-client
This command will upgrade the file in the client by the one in the server. The filename shall have the full path in the client. The file will be read from the server in C:\CopTraxTest\latest folder.
SyncTMZ
	This command will sync the box’s time zone to the server’s.
SyncTime
	This command will sync the box’s time to the server’s.
Pause m
	This command will let the client wait m minutes before next command may be send.
RunApp
	This command will run the CopTrax App.
StopApp
This command will terminate the running of CopTrax App. It is used when try to update the CopTrax App.
Restart
	This command will let the automation client to restart. It is used in the auto-update procedure.
Quit
	This command will let the automation client to stop.

A sample test case is like this
SyncTMZ
SyncTime
Radar
camera 1
review
camera 0
photo
settings 15 10
record 1 2
login usr1 coptraxr
record 20 5

Each line contains a single command. Any other word will be recognized as comments. 
