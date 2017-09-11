import os
import time
import sys
import socket
from java.io import File
from java.io import FileInputStream

# Stopping the servers
def stopMS(servers):
	upStatus = ["RUNNING","ADMIN"]
	for server in servers : 
		cd('/ServerLifeCycleRuntimes/' + server.getName())
		serverstate = get('State')
		servername = server.getName()
		if (serverstate in upStatus) and servername != "AdminServer":
			shutdown(servername,'Server',force='true')
	alldown = False
	while not alldown :
		java.lang.Thread.sleep(10000)
		print "Waiting for managed serves to shut down\n"
		alldown = True
		for server in servers:
	                cd('/ServerLifeCycleRuntimes/' + server.getName())
        	        serverstate = get('State')
                	servername = server.getName()
			print servername + " is in " + serverstate + " State\n"
			if(serverstate == "FORCE_SHUTTING_DOWN"):
				alldown = False
	print "All the managed servers have been shut down\n"
			


        print '============================================='
        cd('/ServerLifeCycleRuntimes/AdminServer')
        print ' AdminServer : ' + get('State')
        print 'Shutting down Admin Server\n'
        shutdown('AdminServer','Server',force='true')
        disconnect()

# Main
if __name__== "main":
	domainName='dc_domain'
	hostname = socket.gethostname().split('.')[0]
	adminURL='t3://'+hostname+'.us.oracle.com:7001'
	adminUserName='weblogic'
	adminPassword='Welcome1'
	try:
	        connect(adminUserName,adminPassword,adminURL)
	except WLSTException, e:
	        print '\nSeems like the admin server '+adminURL+' is not running or the credentials are wrong\nCheck and try again\n'
		sys.exit(1)

	domainConfig()
	servers = cmo.getServers()
	domainRuntime()
	stopMS(servers)
	disconnect()	
