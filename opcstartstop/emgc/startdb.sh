#!/bin/sh

export ORACLE_HOME=$1
export ORACLE_SID=$2

$ORACLE_HOME/bin/lsnrctl start

$ORACLE_HOME/bin/sqlplus '/ as sysdba' <<EOF
startup
EOF
