Echo Automation test on the new manuafactered box
cd c:\CopTraxTest
netsh wlan add profile filename="C:\CopTraxTest\automation.xml"
ping localhost -n 5
start  /d C:\CopTraxTest coptraxtestclient.exe