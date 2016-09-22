#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR=`realpath "$( cd -P "$( dirname "$SOURCE" )" && pwd )"`

NGINX_OS=`uname -o`
NGINX_VERSION=1.11.4
NGINX_SERVER=origin

# parse options
TEMP=`getopt -o v::s:: --long version::,server:: -n 'build.sh' -- "$@"`
eval set -- "$TEMP"
while true ; do
    case "$1" in
      -v|--version)
          case "$2" in
              *) NGINX_VERSION=$2 ; shift 2 ;;
          esac;;
      -s|--server)
          case "$2" in
              *) NGINX_SERVER=$2 ; shift 2 ;;
          esac;;
      *) break;;
    esac
done

# nginx server
NGINX_BASE=$NGINX_VERSION-$OSTYPE-$NGINX_SERVER
NGINX_SERVER_ROOT=$DIR/builds/$NGINX_BASE
if [ -f $NGINX_SERVER_ROOT/sbin/nginx ]; then
  echo "nginx binary is being launched"
  cd $NGINX_SERVER_ROOT && ./sbin/nginx && cd $DIR
else
  echo "nginx binary does not exist or is inaccessible"
fi;
