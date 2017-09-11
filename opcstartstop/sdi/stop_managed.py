import os
import time
import sys
from java.io import File
from java.io import FileInputStream

# Stopping the servers
def stopMS(servers):
        for server in servers:
                if server.getName() != "AdminServer" :
                        try:
                                print '============================================='
                                cd('/ServerLifeCycleRuntimes/' + server.getName())
                                print server.getName() + ': ' + get('State')
                                serverState = get('State')
                                if serverState == "RUNNING" or serverState == "ADMIN" :
                                        shutdown(server.getName(),'Server',force='true')

                                while get('State') == "FORCE_SHUTTING_DOWN":
                                        print '\nWaiting for the server to shut down'
                                        java.lang.Thread.sleep(10000)
                                if get('State') != "SHUTDOWN" :
                                        print server.getName()+' has not been SHUTDOWN properly, it is in'+ get('State')+'\nLook into it, disconnecting from Admin Server\n'
                                        disconnect()
                                        sys.exit(1)
                                else:
                                        print server.getName() + 'has been shutdown successfully\n'
                        except WLSTException,e:
                                print dumpStack()
                                sys.exit(1)

        print '============================================='
        cd('/ServerLifeCycleRuntimes/AdminServer')
        print ' AdminServer : ' + get('State')
        print 'Shutting down Admin Server\n'
        shutdown('AdminServer','Server',force='true')
        disconnect()

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
stopMS(servers)

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
stopMS(servers)


