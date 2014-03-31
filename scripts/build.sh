#!/bin/bash

downloadSDK() {
   if [ "$1" = curl ]
   then
      curl -o ${ATLAS_SDK_TGZ} -skLf ${ATLAS_SDK_URL}
   elif [ "$1" = wget ]
   then
      wget --no-check-certificate -O ${ATLAS_SDK_TGZ} ${ATLAS_SDK_URL}
   else 
      #echo "unable to execute:   wget --no-check-certificate -O ${ATLAS_SDK_TGZ} ${ATLAS_SDK_URL}"
      echo bogus download method: $1
      exit 1
   fi
}

usage() {
   echo "build.sh  [<mavenPhase>]"
   echo "example:  build.sh"
   echo "   build.sh install"
   echo "   build.sh deploy (default)"
}

if [ $# -lt 1 ]
then
   MVN_PHASE=install
elif [ $# -eq 1 ]
then
   MVN_PHASE=$1
else
   echo "invalid number or args" 1>&2
   usage
   exit 1
fi

if [ -z "${JAVA_HOME}" ]
then
   export JAVA_HOME=/usr
fi


CURL=$(which curl)
if [ -z "${CURL}" ]
then
   WGET=$(which wget)
   if [ -z "${WGET}" ]
   then
      echo "I give up, as I cannot find curl nor wget and no way to download the atlassian sdk :(" 1>&2
      exit 1
   fi
   downloadMethod=wget
else
   downloadMethod=curl
fi

RUNDECK_PLUGIN_NAME=bamboo-rundeck-plugin

RUNDECK_PLUGIN_SCM_URL=git://github.com/connaryscott/${RUNDECK_PLUGIN_NAME}.git
ATLAS_SDK=atlassian-plugin-sdk
ATLAS_SDK_VERSION=4.1
ATLAS_SDK_TGZ=${ATLAS_SDK}-${ATLAS_SDK_VERSION}.tar.gz
ATLAS_SDK_URL=https://maven.atlassian.com/content/repositories/atlassian-public/com/atlassian/amps/${ATLAS_SDK}/${ATLAS_SDK_VERSION}/${ATLAS_SDK_TGZ}

ATLAS_SDK_ROOT=$HOME/${ATLAS_SDK}
ATLAS_SDK_HOME=${ATLAS_SDK_ROOT}/${ATLAS_SDK}-${ATLAS_SDK_VERSION}
ATLAS_MVN=${ATLAS_SDK_HOME}/bin/atlas-mvn
if [ ! -f ${ATLAS_MVN} ]
then
   rm -rf ${ATLAS_SDK_HOME}
   if ! mkdir -p ${ATLAS_SDK_HOME}
   then
      echo "unable to create directory: ${ATLAS_SDK_HOME}" 1>&2
      exit 1
   fi
   pushd ${ATLAS_SDK_ROOT} || { echo "unable to pushd into ${ATLAS_SDK_ROOT}" 1>&2; exit 1; }
      if ! downloadSDK ${downloadMethod} 
      then
         echo "unable to download ${ATLAS_SDK_URL} to $(pwd)/${ATLAS_SDK_TGZ}" 1>&2
         exit 1
      fi

      if ! (gunzip -c ${ATLAS_SDK_TGZ} | tar xvf -)
      then
         echo "unable to extract ${ATLAS_SDK_TGZ} into $(pwd)" 1>&2
         exit 1
      fi
   popd
   if [ ! -f ${ATLAS_MVN} ]
   then
      echo "atlas mvn command: ${ATLAS_MVN} does not appear to exist, perhaps ${ATLAS_SDK_TGZ} was not installed" 1>&2
      exit 1
   fi
fi

#
# set default settings.xml if not defined
#
if [ -z "${M2_SETTINGS_XML}" ]
then
   export M2_SETTINGS_XML=${ATLAS_SDK_HOME}/apache-maven/conf/settings.xml
   export M2_HOME=${ATLAS_SDK_HOME}/apache-maven
fi

export PATH=${ATLAS_SDK_ROOT}/bin:${PATH}
export ATLAS_HOME=${ATLAS_SDK_HOME}

if ! ${ATLAS_MVN} -s ${M2_SETTINGS_XML} -Dmaven.test.skip=false clean ${MVN_PHASE}
then
      echo "failed executing ${ATLAS_MVN} -Dmaven.test.skip=false clean ${MVN_PHASE}" 1>&2
      exit 1
fi
