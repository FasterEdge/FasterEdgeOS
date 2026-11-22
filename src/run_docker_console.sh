#!/bin/sh

set -e

clear() {
  if [ ! "`docker ps -a | grep fasteredgeos`" = "" ] ; then
    for id in $(docker ps -a | grep fasteredgeos | awk '{print $1}') ; do
      docker stop "$id"
      docker rm "$id"
    done
  fi

  if [ ! "`docker images -a | grep fasteredgeos`" = "" ] ; then
    for id in $(docker images -a | grep fasteredgeos | awk '{print $1}') ; do
      docker rmi "$id"
    done
  fi
}

run() {
  docker import fasteredgeos_image.tgz fasteredgeos:latest
  docker run -it fasteredgeos /bin/sh
}

clear
run
clear
