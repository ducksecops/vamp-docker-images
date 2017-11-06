#!/usr/bin/env sh

export LANG=en_US.UTF-8

# Wait for http reachable dependency before starting Vamp.
while true; do
  status=$(curl -s -w %{http_code} ${VAMP_WAIT_FOR} -o /dev/null)
  if [ ${status} -eq 200 ]; then
    break
  else
    echo "waiting for ${VAMP_WAIT_FOR}"
  fi
  sleep 5
done

LOG_CONFIG=/usr/local/vamp/logback.xml
APP_CONFIG=/usr/local/vamp/conf/application.conf

VAMP_JAVA_ARGS=${VAMP_JAVA_ARGS:-"-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:MaxRAMFraction=1"}

if [ -e "/usr/local/vamp/conf/logback.xml" ] ; then
    LOG_CONFIG=/usr/local/vamp/conf/logback.xml
fi

java ${VAMP_JAVA_ARGS} \
     -Dlogback.configurationFile=${LOG_CONFIG} \
     -Dconfig.file=${APP_CONFIG} \
     -cp "/usr/local/vamp/bin/*:/usr/local/vamp/bin/lib/*" \
     io.vamp.bootstrap.Boot
