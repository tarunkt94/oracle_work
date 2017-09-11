import os
import time
import sys
from java.io import File
from java.io import FileInputStream

# Starting the servers
def startMS(servers):
        for server in servers:
                if server.getName() != "AdminServer" :
                        try:
                                print '============================================='
                                cd('/ServerLifeCycleRuntimes/' + server.getName())
                                print server.getName() + ': ' + get('State')
                                serverState = get('State')
                                if serverState == "SHUTDOWN" or serverState == "FAILED_NOT_RESTARTABLE":
                                        start(server.getName(),'Server')

                                while get('State') == "STARTING":
                                        java.lang.Thread.sleep(10000)
                                if get('State') != "RUNNING" :
                                        print server.getName()+' has not STARTED  properly, it is in ' +get('State')+'\n Look into it, disconnecting from Admin Server\n'
                                        disconnect()
                                        sys.exit(1)
                                else:
                                        print server.getName()+'has been started successfully\n'
                        except :
                                print dumpStack()
                                sys.exit(1)


# Main
if __name__== "main":
	global s,x
# Read properties file
propInputStream = FileInputStream("wls.properties")
configProps = Properties()
configProps.load(propInputStream)
domainName=configProps.get("domain.name")
adminURL=configProps.get("dc_domain.admin.url")
adminUserName=configProps.get("dc_domain.admin.userName")
adminPassword=configProps.get("dc_domain.admin.password")
try:
	connect(adminUserName,adminPassword,adminURL) 
except WLSTException, e:
	print '\nSeems like the admin server'+adminURL+' is not running or the credentials in the prop file are wrong\nCheck and try again\n'
	sys.exit(1)
domainConfig()
servers = cmo.getServers()
domainRuntime()
startMS(servers)
disconnect()

adminURL=configProps.get("MyServices.admin.url")
adminUserName=configProps.get("MyServices.admin.userName")
adminPassword=configProps.get("MyServices.admin.password")
try:
        connect(adminUserName,adminPassword,adminURL)
except WLSTException, e:
        print '\nSeems like the admin server'+adminURL+' is not running or the credentials in the prop file are wrong\nCheck and try again\n'
	sys.exit(1)
domainConfig()
servers = cmo.getServers()
domainRuntime()
startMS(servers)
disconnect()
