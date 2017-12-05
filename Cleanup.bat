Echo Warning! This will cleanup the automation test trails
ping localhost -n 5
Del /S /F /Q F:\*.*
Del /S /F /Q C:\CopTrax-Backup\*.*
rmdir /S /Q C:\CoptraxTest\
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\coptrax\"
rmdir /S /Q "C:\Users\coptraxadmin\AppData\Local\IncaX_Limited\"
netsh wlan delete profile name="ACI-CopTrax"
schtasks /Delete /TN Automation /F
ping localhost -n 10