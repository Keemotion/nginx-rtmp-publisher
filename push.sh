#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR=`realpath "$( cd -P "$( dirname "$SOURCE" )" && pwd )"`

MOVIE_NAME=bipbop
MOVIE_VERSION=gear3
MOVIE_STREAM=$MOVIE_NAME-$MOVIE_VERSION
MOVIE_MP4=tmp/$MOVIE_STREAM.mp4
MOVIE_URL=https://s3-eu-west-1.amazonaws.com/km-webapp-common/testing/$MOVIE_NAME/$MOVIE_VERSION/video.mp4
# download movie sample
if [ ! -f $MOVIE_MP4 ]; then
  mkdir -p $(dirname "$MOVIE_MP4")
  wget $MOVIE_URL -O $MOVIE_MP4
else
  echo "Skip movie download - already found"  
fi;

# push movie to rtmp origin server
ffmpeg -i $MOVIE_MP4 \
  -c:a copy \
  -c:v copy \
  -f flv "rtmp://localhost/dvr/$MOVIE_STREAM"
