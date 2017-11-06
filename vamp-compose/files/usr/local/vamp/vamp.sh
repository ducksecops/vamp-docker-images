#!/usr/bin/env sh

export LANG=en_US.UTF-8

if [[ -n ${VAMP_WAIT_FOR} ]] ; then
  # Wait for http reachable dependency before starting Vamp.
  while true; do
    status=$(curl -s -w %{http_code} ${VAMP_WAIT_FOR} -o /dev/null)
    if [ ${status} -eq 200 ]; then
      break
    else
      echo "Waiting for ${VAMP_WAIT_FOR}"
    fi
    sleep 5
  done
fi

LOG_CONFIG=/usr/local/vamp/logback.xml
APP_CONFIG=/usr/local/vamp/conf/application.conf

if [ -e "/usr/local/vamp/conf/logback.xml" ] ; then
    LOG_CONFIG=/usr/local/vamp/conf/logback.xml
fi

java -Dlogback.configurationFile=${LOG_CONFIG} \
     -Dconfig.file=${APP_CONFIG} \
     -cp "/usr/local/vamp/bin/*:/usr/local/vamp/bin/lib/*" \
     io.vamp.bootstrap.Boot
