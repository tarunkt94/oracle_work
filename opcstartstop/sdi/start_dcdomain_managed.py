#!/usr/bin/python

import os
import time
import sys
import socket
from java.io import File
from java.io import FileInputStream

# Starting the servers
def startMS(servers):
        for server in servers:
                if server.getName() != "AdminServer" :
			cd('/ServerLifeCycleRuntimes/' + server.getName())
                        servername = server.getName()
			serverstate = get('State')
			print servername + 'is in ' + get('State')+ " state \n"
                        if serverstate == "SHUTDOWN" or serverstate == "FAILED_NOT_RESTARTABLE":
				print "\nStarting  managed server : \n" + servername
                        	start(server.getName(),'Server')

	allup = False
	exitcode=0
	comingup = ["STARTING","RESUMING"]
	while not allup :
		allup=True
		java.lang.Thread.sleep(20000)
		print "Bringing up the managed servers\n"
		for server in servers:
			cd('/ServerLifeCycleRuntimes/' + server.getName())
			servername = server.getName()
			serverstate = get('State')
			print servername+' is in '+serverstate + " state \n"
			if serverstate in comingup:
				allup = False
			if serverstate == "ADMIN":
				print servername+" is in ADMIN state ! Look into it\n."
				exitcode = 1
	print "Brought up all the managed servers\n"
	sys.exit(exitcode)


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
		print '\nSeems like the admin server'+adminURL+" is not running or the credentials are wrong\n"
		sys.exit(1)
	domainConfig()
	servers = cmo.getServers()
	domainRuntime()
	startMS(servers)
	disconnect()

