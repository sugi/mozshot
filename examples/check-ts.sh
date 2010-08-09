#!/bin/bash

#pid=`pidof -x ts.rb`
pid=`< /home/sugi/www/mozshot/ts.pid`
restart=false

if ! timeout -k 1 2 ruby ~/www/mozshot/utils/ping-ts.rb druby://:7524; then
  echo "ts.rb not respond ping, restarting..."
  restart=true
fi

if test -z "$pid"; then
  echo "ts.rb not found"
  exit 1
fi

size=`cut -d' ' -f1 /proc/$pid/statm`
size=$((size*4/1024))

if [ "$size" -gt 300 ]; then
  echo "ts.rb memory size is over 300M, restarting..."
  ps axuw | egrep '[t]s.rb'
  restart=true
fi

if [ "$restart" = "true" ]; then
  kill -HUP $pid
  sleep 1
  kill -KILL $pid > /dev/null 2>&1
fi

exit 0
