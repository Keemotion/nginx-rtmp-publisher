#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR=`realpath "$( cd -P "$( dirname "$SOURCE" )" && pwd )"`

MOVIE_INPUT=

# parse options
TEMP=`getopt -o i:: --long input:: -n 'extract.sh' -- "$@"`
eval set -- "$TEMP"
while true ; do
    case "$1" in
      -i|--input)
          case "$2" in
              *) MOVIE_INPUT=$2 ; shift 2 ;;
          esac;;
      *) break;;
    esac
done

if [ -f $MOVIE_INPUT ]; then
  echo "Extracting elementary stream - audio"
  ffmpeg -y -i $MOVIE_INPUT -c:a copy -c:v none tmp/$(basename ${MOVIE_INPUT%.*}).ac3
  sha1sum tmp/$(basename ${MOVIE_INPUT%.*}).ac3 | awk '{print $1}' > tmp/$(basename ${MOVIE_INPUT%.*}).ac3.sha1
  echo "Extracting elementary stream - video"
  ffmpeg -y -i $MOVIE_INPUT -c:v copy -c:a none tmp/$(basename ${MOVIE_INPUT%.*}).h264
  sha1sum tmp/$(basename ${MOVIE_INPUT%.*}).h264 | awk '{print $1}' > tmp/$(basename ${MOVIE_INPUT%.*}).h264.sha1
else
  echo "$MOVIE_INPUT movie file is not accessible"
fi;
