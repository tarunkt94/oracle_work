#!/bin/sh
#
# $Header: dte/DTE/scripts/fusionapps/cli/order_scripts/gsi_bundle.sh /main/1 2016/03/24 07:50:38 ljonnala Exp $
#
# gsi_bundle.sh
#
# Copyright (c) 2012, 2016, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      gsi_bundle.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    ashkumak    09/02/14 - Adding GlobalDRConfig feature
#    apugalia    07/03/14 - Adding DR Order related code change
#    pande       06/21/12 - Creation
#
export ORACLE_HOME=/scratch/aime/work/oracle/product/11.2.0.4/dbhome_2
export ORACLE_SID=centraldb
rm comp.sql 2>/dev/null;
if [ $# -lt 3 ]
then
        echo "";
        echo "Usage: $0 <organizationid> <orderid> <fusion service group name> <DR Config> PROV_TEST_BEFORE_PROD/DEPLOY_TEST_INSTANCE_FALSE";
        echo "Some valid fusion service group names are CRM,HCM,RNOW etc";
        echo "Some valid DR Config values are ALL, TEST, PROD, NONE etc. By default this value is set as NONE";
        echo "If 'PROV_TEST_BEFORE_PROD' option is mentioned, then TEST instance will be seeded before PROD";
        echo "If 'DEPLOY_TEST_INSTANCE_FALSE' option is mentioned, then no TEST instance will be seeded";
        echo "Some valid inputs: ./gsi_bundle.sh 1000 100 HCM, ./gsi_bundle.sh 1000 100 HCM ALL, ./gsi_bundle.sh 1000 100 HCM PROD PROV_TEST_BEFORE_PROD etc."
        echo "";
        exit;
fi
clear;

# The following IF block decides DR_CONFIG values based on user input
if [ -z "$4" ]; then
  DR_OPTION=null;
elif [ "$4" == "PROD" ] || [ "$4" == "TEST" ] || [ "$4" == "NONE" ] || [ "$4" == "ALL" ]; then
        DR_OPTION=$4;
  else
        echo "";
        echo "Valid values for DR_CONFIG are ALL, TEST, PROD and NONE ";
        exit;
fi

# The following IF block Option for TEST instance based on user input
if [ "$5" == "PROV_TEST_BEFORE_PROD" ]; then
        OPT_FOR_TEST=$5;
   elif [ "$5" == "DEPLOY_TEST_INSTANCE_FALSE" ]; then
        OPT_FOR_TEST=$5;

   elif [ "$5" == "" ]; then
        OPT_FOR_TEST=0;
   else
        echo "";
        echo "Valid values are PROV_TEST_BEFORE_PROD and DEPLOY_TEST_INSTANCE_FALSE ";
        echo "";
        exit;
fi
echo " ";
echo "Submitting GSI bundle order .................";
echo " ";
echo "@submit_bundle.sql $1 $2 $3 $OPT_FOR_TEST"
$ORACLE_HOME/bin/sqlplus -S tas_gsi_bridge/Welcome1@${ORACLE_SID} <<END1
set heading off
set feedback on
set verify off
set serveroutput on
@submit_bundle.sql $1 $2 $3 $OPT_FOR_TEST
exit;
END1

echo "End of Submit Bundle"
itemid=`$ORACLE_HOME/bin/sqlplus -S tas/Welcome1@${ORACLE_SID} <<END2
set heading off
set feedback off
select id from tas_order_items where external_order_id='$1_$2';
exit;
END2`

pass=`$ORACLE_HOME/bin/sqlplus -S tas/Welcome1@${ORACLE_SID} <<END22
set heading off
set feedback off
select completion_passkey from tas_orders where external_order_id='$1_$2';
exit;
END22`

orderid=$1_$2;
sed "s/orderid/$orderid/" complete_bundle.sql >comp.sql;

echo " ";
echo "Completing the order .........................";
echo " ";
echo "@comp.sql $DR_OPTION ser${1}${2} $itemid $pass";
$ORACLE_HOME/bin/sqlplus -S cloudui/Welcome1@${ORACLE_SID} << END3
set heading off
set verify on
set feedback on
set serveroutput on
@comp.sql $DR_OPTION ser${1}${2} $itemid $pass
exit;
END3
rm comp.sql
exit;
