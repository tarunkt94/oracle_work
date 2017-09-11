import os
import time
import sys
from java.io import File
from java.io import FileInputStream

# Starting the servers
def startMS(servers):
	global out
        for server in servers:
                if server.getName() != "AdminServer" :
                        try:
                                cd('/ServerLifeCycleRuntimes/' + server.getName())
                                serverState = get('State')
                        	if get('State') != "RUNNING": 
					out += server.getName()+ " is down\n"
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
adminURL=configProps.get("central_domain.admin.url")
adminUserName=configProps.get("central_domain.admin.userName")
adminPassword=configProps.get("central_domain.admin.password")
out = ""
try:
	connect(adminUserName,adminPassword,adminURL)
	domainConfig()
	servers = cmo.getServers()
	domainRuntime()
	startMS(servers)
	disconnect()
except WLSTException, e:
	out = "Central domain Admin Server is down\n"

adminURL=configProps.get("MyAccount.admin.url")
adminUserName=configProps.get("MyAccount.admin.userName")
adminPassword=configProps.get("MyAccount.admin.password")
try:
        connect(adminUserName,adminPassword,adminURL)
        domainConfig()
        servers = cmo.getServers()
        domainRuntime()
        startMS(servers)
        disconnect()

except WLSTException, e:
	out += "MyAccount Admin server is down\n"

fo = open("/net/slc03wlx/scratch/aime/tarun/status.txt","a");
fo.write("In the TAS Central host : \n"+out+"\n")
fo.close()
