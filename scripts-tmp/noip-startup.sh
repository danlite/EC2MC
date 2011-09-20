#! /bin/sh
case "$1" in
  start)
    echo "Starting noip2."
    /usr/local/bin/noip2
    ;;
  stop)
    echo -n "Shutting down noip2."
    pkill -TERM -f /usr/local/bin/noip2
    ;;
  *)
    echo "Usage: $0 {start|stop}"
    exit 1
  esac
exit 0