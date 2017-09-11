
# set up wls home
WL_HOME="/scratch/aime/work/CLOUDTOP/Middleware/wlserver_10.3"

# set up common environment
. "${WL_HOME}/server/bin/setWLSEnv.sh"

"${JAVA_HOME}/bin/java" weblogic.WLST $*
