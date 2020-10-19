#!/usr/bin/env bash

SEL_STATUS_URL="http://${SELENIUM_NODE_HOST}:${SELENIUM_MULTINODE_PORT}/wd/hub/status"

# set -e: exit asap if a command exits with a non-zero status
set -e

if [ "${MULTINODE}" != "true" ]; then
  echo "Won't start selenium multi-node (Chrome & Firefox) due to MULTINODE env var false"
  exit 0
fi

echo "Waiting for Selenium multi-node (Chrome & Firefox) to be ready..."

# Selenium <= 3.3.1 then: while ! curl -s "${SEL_STATUS_URL}" | jq '.state' | grep "success"; do
# SUCESS_CMD="jq .state | grep success"

# Selenium >= 3.5.0 then: while ! curl -s "${SEL_STATUS_URL}" | jq .value.ready | grep "true"; do
SUCESS_CMD="jq .value.ready | grep true"

while ! curl -s "${SEL_STATUS_URL}" | sh -c "${SUCESS_CMD}"; do
  if [ "${DEBUG}" != "false" ]; then
    if ! curl --verbose "${SEL_STATUS_URL}"; then
      sleep 0.2
      if ! wget --verbose --tries=1 "${SEL_STATUS_URL}"; then
        sleep 0.2
        netstat -tlnp
        if ! ps -A | grep -i java; then
          sleep 0.2
          ps -A
        fi
      fi
    fi
  else
    echo -n '.'
    sleep 0.1
  fi
done

echo "Done wait-selenium-multinode.sh"
