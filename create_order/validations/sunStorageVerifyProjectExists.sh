#!/usr/bin/expect
#
# $Header: dte/DTE/scripts/fusionapps/cli/dr/sunStorageVerifyProjectExists.sh /main/1 2015/09/25 01:24:35 kgudla Exp $
#
# Copyright (c) 2011, 2015, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      sunStorageVerifyProjectExists.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#
#    MODIFIED   (MM/DD/YY)
#    sampath    05/12/14 - Creation
#

proc expectAndSend {expectStr sendStr} {
   expect {
      "error:"       {puts stderr "Error: See logfile for transcript of expect session."; exit 1}
      "$expectStr"   {send "$sendStr\r"}
      timeout        {puts stderr "Timed out waiting for '$expectStr'"; exit 1}
   }
}

set timeout 600

if {[llength $argv] != 4} {
   puts "Usage: sunStorageVerifyProjectExists <user> <password> <server>  <projName>"
   exit
}

set USERNAME    [lindex $argv 0]
set PASSWORD    [lindex $argv 1]
set SERVER      [lindex $argv 2]
set PROJNAME    [lindex $argv 3]


#20111205: prompt may not match server used to connect if loadbalanced
#set PROMPT      "$SERVER:"
set ESCCHAR     [format %c 27]
set PROMPT      ">$ESCCHAR"

set LOGINSTRING "$USERNAME@$SERVER"

spawn /usr/bin/ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $LOGINSTRING

expect {
	"?assword:" {send "$PASSWORD\r"}
}

expect {
   "Password:"    {puts stderr "Wrong password."; exit 1}
   "Last login:"  {puts "Login Successful."}
   timeout        abort
}

expectAndSend "$PROMPT" "cd /"
expectAndSend "$PROMPT" "shares"


expect "$PROMPT"

#checking project exists or not
send "select $PROJNAME\r"

expect {
   "error: project \"$PROJNAME\" not found" {puts "Project : $PROJNAME not Present";}
   "$PROMPT"      { send "cd ..\r"; puts "Project : $PROJNAME Present";}
   timeout        abort
}


expectAndSend "$PROMPT" "exit"

