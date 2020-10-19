#!/usr/bin/env bash

# set -e: exit asap if a command exits with a non-zero status
set -e

echoerr() { printf "%s\n" "$*" >&2; }

# print error and exit
die () {
  echoerr "ERROR: $1"
  # if $2 is defined AND NOT EMPTY, use $2; otherwise, set to "150"
  errnum=${2-115}
  exit $errnum
}

# Required params
[ -z "${XMANAGER}" ] && die "Need env var set \$XMANAGER"

# It happens that the process name of the X manager is the same as
#  the $XMANAGER variable so this just works `ps -A | grep "${XMANAGER}"`
echo "Waiting for X Manager '${XMANAGER}' to be ready..."
while ! ps -A | grep "${XMANAGER}" >/dev/null 2>&1; do
  echo -n '.'
  sleep 0.1
done

# Found a way to wait for an X Manager
while ! xsetroot -cursor_name left_ptr -fg white -bg black > /dev/null 2>&1; do
  echo -n '.'
  sleep 0.1
done

echo "Done wait-xmanager.sh"
