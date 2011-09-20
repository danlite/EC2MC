#! /bin/sh
case "$1" in
  start)
    /home/ec2-user/bin/mc start;;
  stop)  
    /home/ec2-user/bin/mc stop;;
  *)
    echo "Usage: $0 {start|stop}"
    exit 1
esac
