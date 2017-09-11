#!/usr/bash
#
# Copyright (c) 2011, 2016, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      unregister_em_services.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    Notes
#      This script should be executed before rollback the OPatch 
#
function usage()
{
        echo "Usage: sh unregister_em_services.sh -oms_home=<working_dir> -em_user=<user> -em_password=<password> -version_to_unreg=<version_to_unreg>"
        echo "Example: sh unregister_em_services.sh -oms_home=/scratch/aime/software/oracle/midware/oms -em_user=sysman -em_password=welcome1 -version_to_unreg=1.8.4.0.0"
}

function paramLookUp()
{
        key=$1;shift
        paramSpecialLookup "$key" "" "$*"
}

function paramSpecialLookup()
{
        key=$1;shift
        delimiter=$1;shift
        value=""
        read -ra l_params <<< "$*"
        for l_param in "${l_params[@]}"
        do
                l_key=$(echo "$l_param" |awk -F "=" '{print $1}' | sed -e 's/^[ \t]*//g' -e 's/[ \t]*$//g')
                 if [ "$key" == "$l_key" ];
                 then
                         value=$(echo "$l_param" |awk -F "=" '{$1="";print $0}' | sed -e 's/^[ \t]*//g' -e 's/[ \t]*$//g')
                         break
                 fi
        done
        if [ "$delimiter" != "" ];
        then
                value=$(echo "$value" | tr "$delimiter" " ")
        fi
        echo "$value"
}


inputParams="$*"

OMS_HOME=$(paramLookUp -oms_home "$inputParams")
USER_TO_UNREG_EM_SERVICES=$(paramLookUp -em_user "$inputParams")
USER_PWD=$(paramLookUp -em_password "$inputParams")
VERSION_TO_UNREG=$(paramLookUp -version_to_unreg "$inputParams")

if [ ${#OMS_HOME} -eq 0 ] ||  [ ${#USER_TO_UNREG_EM_SERVICES} -eq 0 ] || [ ${#USER_PWD} -eq 0 ];
then
  usage
  exit 1
fi;

export  ORACLE_HOME=$OMS_HOME
export  OPATCH=$ORACLE_HOME/OPatch
export  EM_BIN=$ORACLE_HOME/bin
export  META_DATA=$ORACLE_HOME/$USER_TO_UNREG_EM_SERVICES/metadata
echo "************************** Entry to deregister S/W library service **********************************"
while read swlib           
do           
    #echo "Going to deregister ..... $ORACLE_HOME/$USER_TO_UNREG_EM_SERVICES/metadata/$swlib"         
    echo "$META_DATA/$swlib" | awk -F "/" '{print $NF}' 
    echo "$USER_PWD" | $EM_BIN/emctl deregister oms metadata -service swlib -core -file $META_DATA/$swlib -no_old_file
    if [ "$?" == "0" ]
    then
       echo " "
       #echo "$META_DATA/$swlib deregistered successfully"
    else
       echo "Failed to deregister $META_DATA/$swlib"
       exit 1
    fi 
done < $META_DATA/swlib/contentmgmt/$VERSION_TO_UNREG/FILELIST_pbu_swlib_core_disasterrecovery
echo "=========================== Exit  deregister S/W library service ======================================="


echo -e "\n************************   Entry to deregister Procedure service *************************************"
while read procedure
do 
   echo "$META_DATA/$procedure" | awk -F "/" '{print $NF}'
   #echo  "Going to deregister ..... $META_DATA/$procedure"
   echo "$USER_PWD" | $EM_BIN/emctl deregister oms metadata -service procedures -core -file $META_DATA/$procedure -no_old_file
    if [ "$?" == "0" ]
    then
       echo " "
       #echo "$ORACLE_HOME/$USER_TO_UNREG_EM_SERVICES/metadata/$procedure deregistered successfully"
    else
       echo "Failed to deregister $ORACLE_HOME/$USER_TO_UNREG_EM_SERVICES/metadata/$procedure"
       exit 1
    fi
done < $META_DATA/procedures/contentmgmt/$VERSION_TO_UNREG/FILELIST_pbu_procedures_core_disasterrecovery
echo "=========================== Exit  deregister Procedure service ==========================================="

echo -e "\n************************** Entry to deregister Job service *********************************************"
while read job
do 
   echo "$META_DATA/$job" | awk -F "/" '{print $NF}' 
   #echo "Going to deregister ..... $ORACLE_HOME/$USER_TO_UNREG_EM_SERVICES/metadata/$job"
   echo "$USER_PWD" | $EM_BIN/emctl deregister oms metadata -service jobTypes -core -file $META_DATA/$job -no_old_file
   if [ "$?" == "0" ]
   then
       echo " "
       #echo "$ORACLE_HOME/$USER_TO_UNREG_EM_SERVICES/metadata/$job"
   else
       echo "Failed to deregister $META_DATA/$job "
   fi
done < $META_DATA/jobs/contentmgmt/$VERSION_TO_UNREG/FILELIST_pbu_jobs_core_disasterrecovery
echo "============================ Exit  deregister Job service ================================================="
