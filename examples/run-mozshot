#!/bin/bash

if test -z "$DISPLAY"; then
  echo "You need to set DISPLAY env" >&2
  exit 1
elif [ "$DISPLAY" = ":0.0" ]; then
  echo "You really want to run uner DISPLAY :0.0?" >&2
  exit 1
fi

TEMP=/tmp/mozshot
TMP=/tmp/mozshot
: ${MOZSHOT_DAEMON_SOCK:=druby://localhost:7524}
: ${MOZILLA_FIVE_HOME=/usr/lib/xulrunner}
export MOZILLA_FIVE_HOME MOZSHOT_DAEMON_SOCK TEMP TMP
unset XAUTHORITY
unset GNOME_KEYRING_SOCKET
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
unset SSH_AUTH_SOCK
unset GNOME_KEYRING_SOCKET
unset GPG_AGENT_INFO
unset GTK_IM_MODULE
unset XMODIFIERS

if test -z "$1"; then
  id=${DISPLAY#:}
else
  id=$1
fi

cd `dirname $0`/.. || exit 1
while :; do
  ruby -r timestamp.rb mozshot.rb >> ~/data/log/mozshot-${id}.log 2>&1
  sleep 0.3
done
