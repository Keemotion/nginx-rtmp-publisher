#!/bin/bash

case "$OSTYPE" in
  linux*)   echo "LINUX" ;;
  darwin*)  echo "OSX" ;; 
  win*)     echo "Windows" ;;
  cygwin*)  echo "Cygwin" ;;
  msys*)    echo "Msys" ;;
  bsd*)     echo "BSD" ;;
  solaris*) echo "SOLARIS" ;;
  *)        echo "unknown: $OSTYPE" ;;
esac

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
NGINX_INSTALL_PREFIX=$DIR/$NGINX_BASE
NGINX_CONFIGURATION_TEMPLATE=$DIR/nginx.$NGINX_SERVER.rtmp.conf
NGINX_SOURCE_BASE=nginx-$NGINX_VERSION
NGINX_SOURCE_PACKAGE=$NGINX_SOURCE_BASE.tar.gz
NGINX_SOURCE_URL=https://nginx.org/download/$NGINX_SOURCE_PACKAGE
NGINX_SOURCE_DIR=$DIR/src/$NGINX_SOURCE_BASE
NGINX_SOURCE_TGZ=$DIR/src/$NGINX_SOURCE_PACKAGE

# ensure src dir exists
mkdir -p $DIR/src

# nginx - download
if [ ! -f $NGINX_SOURCE_TGZ ]; then
  wget $NGINX_SOURCE_URL -O $NGINX_SOURCE_TGZ
else
  echo "Skip nginx download - source tarball found in $NGINX_SOURCE_TGZ"  
fi;
# nginx - unpack 
if [ ! -f $NGINX_SOURCE_DIR/auto/cc/sunc ]; then
  mkdir -p $NGINX_SOURCE_DIR
  tar -zxvf $NGINX_SOURCE_TGZ -C $DIR/src
else
  echo "Skip nginx unpack - source tarball contents found in $NGINX_SOURCE_DIR"
fi;

# nginx-rtmp-module
NGINX_RTMP_MODULE_SOURCE_BASE=nginx-rtmp-module
NGINX_RTMP_MODULE_SOURCE_PACKAGE=$NGINX_RTMP_MODULE_SOURCE_BASE.tar.gz
#NGINX_RTMP_MODULE_SOURCE_REPO=https://github.com/arut/nginx-rtmp-module.git
NGINX_RTMP_MODULE_SOURCE_REPO=https://github.com/iongion/nginx-rtmp-module.git
NGINX_RTMP_MODULE_SOURCE_DIR=$DIR/src/$NGINX_RTMP_MODULE_SOURCE_BASE
# nginx rtmp module - download
if [ ! -f $NGINX_RTMP_MODULE_SOURCE_DIR/config ]; then
  git clone $NGINX_RTMP_MODULE_SOURCE_REPO $NGINX_RTMP_MODULE_SOURCE_DIR
else
  echo "Skip nginx-rtmp-module download - repository found in $NGINX_RTMP_MODULE_SOURCE_DIR"  
fi;

echo "Entering in $NGINX_SOURCE_DIR to build at $NGINX_INSTALL_PREFIX"
cd $NGINX_SOURCE_DIR

echo "Configuring - Makefile not found in $NGINX_SOURCE_DIR/objs-$NGINX_SERVER"
NGINX_OBJS_PATH=$NGINX_SOURCE_DIR/objs-$NGINX_SERVER
if [ ! -d $NGINX_OBJS_PATH ]; then
  ./configure                                       \
    --builddir=$NGINX_OBJS_PATH                      \
    --prefix=$NGINX_INSTALL_PREFIX                  \
    --with-http_v2_module                           \
    --with-http_ssl_module                          \
    --with-http_flv_module                          \
    --with-http_mp4_module                          \
    --with-http_gunzip_module                       \
    --with-http_gzip_static_module                  \
    --with-http_auth_request_module                 \
    --with-http_secure_link_module                  \
    --with-http_degradation_module                  \
    --with-http_slice_module                        \
    --http-client-body-temp-path=temp/client_body   \
    --http-proxy-temp-path=temp/proxy_temp          \
    --http-fastcgi-temp-path=temp/fastcgi_temp      \
    --http-uwsgi-temp-path=temp/uwsgi_temp          \
    --http-scgi-temp-path=temp/scgi_temp            \
    --with-debug                                    \
    --with-pcre                                     \
    --add-module=$NGINX_RTMP_MODULE_SOURCE_DIR
else
  echo "Already configured for build in objs-$NGINX_SERVER"
fi;

if [ ! -d $NGINX_OBJS_PATH ]; then
  echo "Configuration did not complete successfully"
  exit 1;
else
  ls -all $NGINX_INSTALL_PREFIX/sbin/nginx.exe
  strip -s $NGINX_INSTALL_PREFIX/sbin/nginx.exe
fi

echo "Installing"
make -f $NGINX_OBJS_PATH/Makefile install
mkdir -p $NGINX_INSTALL_PREFIX/temp/client_body
mkdir -p $NGINX_INSTALL_PREFIX/temp/proxy_temp
mkdir -p $NGINX_INSTALL_PREFIX/temp/fastcgi_temp
mkdir -p $NGINX_INSTALL_PREFIX/temp/uwsgi_temp
mkdir -p $NGINX_INSTALL_PREFIX/temp/scgi_temp

# ensure temp dirs exist
directories=(client_body fastcgi_temp hls_temp proxy_temp scgi_temp uwsgi_temp)
for dir in "${directories[@]}"
do
	mkdir -p $NGINX_INSTALL_PREFIX/temp/$dir
done;

# backup default configuration
rm -f $NGINX_INSTALL_PREFIX/conf/nginx.conf.previous
cp $NGINX_INSTALL_PREFIX/conf/nginx.conf $NGINX_INSTALL_PREFIX/conf/nginx.conf.previous
rm -f $NGINX_INSTALL_PREFIX/conf/nginx.conf
REPLACE_EXPRESSION="s|\${SERVER_ROOT}|`realpath $NGINX_INSTALL_PREFIX`|g"
sed $REPLACE_EXPRESSION $NGINX_CONFIGURATION_TEMPLATE > $NGINX_INSTALL_PREFIX/conf/nginx.conf

echo "Configuration replaced"
