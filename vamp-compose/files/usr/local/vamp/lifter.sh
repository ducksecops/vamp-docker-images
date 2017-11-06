#!/usr/bin/env sh

export LANG=en_US.UTF-8

LOG_CONFIG=/usr/local/vamp/logback.xml
APP_CONFIG=/usr/local/vamp/lifter/application.conf

if [ -e "/usr/local/vamp/conf/logback.xml" ] ; then
    LOG_CONFIG=/usr/local/vamp/conf/logback.xml
fi

echo "running Vamp Lifter"

if [ -e "${APP_CONFIG}" ] ; then
    java -Dlogback.configurationFile=${LOG_CONFIG} \
         -Dconfig.file=${APP_CONFIG} \
         -cp "/usr/local/vamp/lifter/*:/usr/local/vamp/lifter/lib/*" \
         io.vamp.lifter.Lifter
else
    java -Dlogback.configurationFile=${LOG_CONFIG} \
         -cp "/usr/local/vamp/lifter/*:/usr/local/vamp/lifter/lib/*" \
         io.vamp.lifter.Lifter
fi
