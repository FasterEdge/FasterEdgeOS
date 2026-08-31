#!/bin/sh

set -e

clear() {
  if [ ! "`docker ps -a | grep fasteredgeos`" = "" ] ; then
    docker stop `docker ps -a | grep fasteredgeos | awk '{print $1}'`
    docker rm `docker ps -a | grep fasteredgeos | awk '{print $1}'`
  fi

  if [ ! "`docker images -a | grep fasteredgeos`" = "" ] ; then
    docker rmi `docker images -a | grep fasteredgeos | awk '{print $1}'`
  fi
}

run() {
  docker import fasteredgeos_image.tgz fasteredgeos:latest
  docker run fasteredgeos /bin/cat /etc/motd
}

clear
run
clear

cat << CEOF

  测试通过 - 干得漂亮！

CEOF
