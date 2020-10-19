#!/usr/bin/env bash

# set -e: exit asap if a command exits with a non-zero status
# set -x: print each command right before it is executed
set -xe

echoerr() { printf "%s\n" "$*" >&2; }

# print error and exit
die () {
  echoerr "ERROR: $1"
  # if $2 is defined AND NOT EMPTY, use $2; otherwise, set to "160"
  errnum=${2-160}
  exit $errnum
}

# Required params or defaults
[ -z "${NUM_NODES}" ] && die "Required env var NUM_NODES"
[ -z "${PARAL_TESTS}" ] && die "Required env var PARAL_TESTS"
[ -z "${WAIT_ALL_DONE}" ] && export WAIT_ALL_DONE="40s"
[ -z "${PAUSE_SECS_BETWEEN_RUN_TEST}" ] && export PAUSE_SECS_BETWEEN_RUN_TEST="0"
[ -z "${SLEEP_TIME}" ] && die "Required env var SLEEP_TIME"

# Ensure clean
docker-compose -f ${COMPOSE_FILE} -p grid down || true

# Compose up!
if [ "${DO_COMPOSE_UP}" = "true" ]; then
  docker-compose -f ${COMPOSE_FILE} -p grid up -d
fi

# Compose scale!
docker-compose -f ${COMPOSE_FILE} -p grid scale mock=1 hub=1 chrome=${NUM_NODES} firefox=${NUM_NODES}

# FIXME: We still need to wait a bit because the nodes registration is not
#        being waited on wait_all_done script :(
#        mabe related to issue #83
sleep ${SLEEP_TIME}

# Wait then show errors, if any
if ! docker-compose -f ${COMPOSE_FILE} -p grid exec --index=1 hub wait_all_done ${WAIT_ALL_DONE}; then
  docker-compose -f ${COMPOSE_FILE} -p grid exec --index=1 hub errors || docker ps -a
  docker-compose -f ${COMPOSE_FILE} -p grid logs hub
  die "$0 Failed to start the Hub"
fi

for i in $(seq 1 ${NUM_NODES}); do
  if ! docker-compose -f ${COMPOSE_FILE} -p grid exec --index ${i} chrome wait_all_done ${WAIT_ALL_DONE}; then
    docker-compose -f ${COMPOSE_FILE} -p grid logs chrome
    docker-compose -f ${COMPOSE_FILE} -p grid exec --index ${i} chrome errors || true
    die "Failed to start Node chrome ${i}"
  fi
  if ! docker-compose -f ${COMPOSE_FILE} -p grid exec --index ${i} firefox wait_all_done ${WAIT_ALL_DONE}; then
    docker-compose -f ${COMPOSE_FILE} -p grid logs firefox
    docker-compose -f ${COMPOSE_FILE} -p grid exec --index ${i} firefox errors || true
    die "Failed to start Node firefox ${i}"
  fi
done

# FIXME: We still need to wait a bit because the nodes registration is not
#        being waited on wait_all_done script :(
#        mabe related to issue #83
sleep ${SLEEP_TIME}

# Tests can run anywere, in the hub, in the host, doesn't matter
for i in $(seq 1 ${PARAL_TESTS}); do
  # Need to sleep a bit between tests to avoid
  #  https://github.com/SeleniumHQ/selenium/issues/2442
  sleep ${PAUSE_SECS_BETWEEN_RUN_TEST}
  # Docker-ompose exec is giving me error:
  #  in dockerpty/io.py", line 42, in set_blocking
  #  ValueError: file descriptor cannot be a negative integer (-1)
  # docker-compose -f ${COMPOSE_FILE} -p grid exec --index 1 hub run_test &
  docker-compose -f ${COMPOSE_FILE} -p grid exec --index=1 hub selenium_test chrome &
  docker-compose -f ${COMPOSE_FILE} -p grid exec --index=1 hub selenium_test firefox &
done

# sleep a moment to let the UI tests start
sleep ${SLEEP_TIME}

# not so verbose from here
set +x

# http://jeremy.zawodny.com/blog/archives/010717.html
FAIL_COUNT=0
for job in `jobs -p`; do
  wait $job || let "FAIL_COUNT+=1"
done

# Show logs also
docker-compose -f ${COMPOSE_FILE} -p grid logs hub
docker-compose -f ${COMPOSE_FILE} -p grid logs chrome
docker-compose -f ${COMPOSE_FILE} -p grid logs firefox
# for i in $(seq 1 ${NUM_NODES}); do
#   docker logs grid_chrome_${i}
#   docker logs grid_firefox_${i}
# done

# Cleanup
docker-compose -f ${COMPOSE_FILE} -p grid down

# Results
if [ "$FAIL_COUNT" == "0" ]; then
  echo "Awesome! $PARAL_TESTS tests succeeded and $FAIL_COUNT tests failed"
else
  die "In total $FAIL_COUNT tests failed"
fi
