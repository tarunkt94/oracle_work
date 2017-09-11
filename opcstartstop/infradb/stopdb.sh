#!/bin/sh

export ORACLE_HOME=$1
export ORACLE_SID=$2


$ORACLE_HOME/bin/sqlplus '/ as sysdba' <<EOF
shutdown immediate
EOF

$ORACLE_HOME/bin/lsnrctl stop
