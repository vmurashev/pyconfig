#!/bin/bash

set -e
SELF_SCRIPT="$0"
if [ -L "$SELF_SCRIPT" ]; then
    SELF_SCRIPT=$(readlink -e $SELF_SCRIPT)
fi
DIR_HERE=$(cd $(dirname $SELF_SCRIPT) && pwd)
DIR_HOME=$(cd ~ && pwd)

DIR_DOWNLOADS="$DIR_HERE/downloads"

DIR_OBJ="$DIR_HERE/obj"
mkdir -p $DIR_OBJ

DIR_SRC="$DIR_HERE/src"
mkdir -p $DIR_SRC

source "$DIR_HERE/conf.sh"

PYTHON_FOR_BUILD=$(which python 2>/dev/null)

# $1 msg
abort()
{
    echo "ERROR: $1"
    exit 1
}

# $1: URL
download_once()
{
    local URL=$1
    local ARC_NAME=$(basename $URL)
    local DL_RET
    mkdir -p $DIR_DOWNLOADS
    if [ ! -f "$DIR_DOWNLOADS/$ARC_NAME" ]; then
        echo "Downloading $ARC_NAME ..."
        set +e
        curl -L --fail -o "$DIR_DOWNLOADS/$ARC_NAME" $URL
        DL_RET="$?"
        set -e
        if [ "$DL_RET" != "0" ] ; then
            rm -rf "$DIR_DOWNLOADS/$ARC_NAME"
            abort "URL '$URL' is not ready"
        fi
    fi
}

# $1: URL
# $2: Destination dir
# $3: Number of strip depth
unpack_downloaded()
{
    local URL=$1
    local DEST_DIR="$2"
    local STRIP_PREFIX
    if [ -n "$3" ]; then
        STRIP_PREFIX="--strip-components=$3"
    fi
    local ARC_NAME=$(basename $URL)
    local STAMP_FILE="$DIR_OBJ/${ARC_NAME}.stamp"
    local DEST_PATH="$DIR_SRC/$DEST_DIR"
    if [ ! -f "$STAMP_FILE" ]; then
        rm -rf $DEST_PATH
        mkdir -p $DEST_PATH
        echo "Extracting $ARC_NAME ..."
        tar xzf "$DIR_DOWNLOADS/$ARC_NAME" $STRIP_PREFIX -C $DEST_PATH
        touch "$STAMP_FILE"
    fi
}

# $1: src dir
# $2: build dir
configure_python_native()
{
    local SRC_DIR=$1
    local BUILD_DIR=$2
    local PYTHON2_MAJOR_VERSION=$(cat "$DIR_SRC/python2/Include/patchlevel.h" | sed -n 's/#define[ \t]*PY_MAJOR_VERSION[ \t]*\([0-9]*\).*/\1/p')

    rm -rf $BUILD_DIR
    mkdir -p $BUILD_DIR

    local CONFIGURE_WRAPPER="$BUILD_DIR/configure.sh"
    {
        echo "#!/bin/bash"
        echo 'set -e'
        echo ''
        echo 'cd $(dirname $0)'
        echo ''
        if [ "$PYTHON_MAJOR_VERSION" = "2" ]; then
            echo "exec $SRC_DIR/configure \\"
            echo "    --prefix=$BUILD_DIR/install \\"
            echo "    --with-threads \\"
            echo "    --with-computed-gotos \\"
            echo "    --enable-ipv6 \\"
            echo "    --enable-unicode=ucs4 \\"
            echo "    --without-ensurepip"
        else
            echo "exec $SRC_DIR/configure \\"
            echo "    --prefix=$BUILD_DIR/install \\"
            echo "    --with-threads \\"
            echo "    --with-computed-gotos \\"
            echo "    --enable-ipv6 \\"
            echo "    --without-ensurepip"
        fi
    } >$CONFIGURE_WRAPPER
   chmod +x $CONFIGURE_WRAPPER

   $CONFIGURE_WRAPPER
}

# $1: src dir
# $2: build dir
# $3: ABI
# $4: PYTHON_MAJOR_VERSION
configure_python_for_abi()
{
    local SRC_DIR=$1
    local BUILD_DIR=$2
    local ABI=$3
    local PYTHON_MAJOR_VERSION=$4

    case $ABI in
            x86_64)
                XT_DIR="$HOME/x-tools/x86_64-unknown-linux-gnu/bin"
                XT_TARGET='x86_64-unknown-linux-gnu'
                ;;
            x86)
                XT_DIR="$HOME/x-tools/i686-unknown-linux-gnu/bin"
                XT_TARGET='i686-unknown-linux-gnu'
                ;;
            arm64)
                XT_DIR="$HOME/x-tools/aarch64-unknown-linux-gnueabi/bin"
                XT_TARGET='aarch64-unknown-linux-gnueabi'
                ;;
            arm)
                XT_DIR="$HOME/x-tools/arm-unknown-linux-gnueabi/bin"
                XT_TARGET='arm-unknown-linux-gnueabi'
                ;;
            *)
                abort "Unknown ABI: '$ABI'"
                ;;
    esac
    if [ ! -d "$XT_DIR" ]; then
        abort "cross-tools not configured for ABI '$ABI', directory '$XT_DIR' not found."
    fi

    local CC="${XT_DIR}/${XT_TARGET}-gcc"
    local CPP="${XT_DIR}/${XT_TARGET}-gcc -E"
    local AR="${XT_DIR}/${XT_TARGET}-ar"
    local RANLIB="${XT_DIR}/${XT_TARGET}-ranlib"
    local READELF="${XT_DIR}/${XT_TARGET}-readelf"

    rm -rf $BUILD_DIR
    mkdir -p $BUILD_DIR

    BUILD_ON_PLATFORM=$($SRC_DIR/config.guess)

    local CONFIG_SITE="$BUILD_DIR/config.site"
    {
        echo 'ac_cv_little_endian_double=yes'
        echo 'ac_cv_file__dev_ptmx=yes'
        echo 'ac_cv_file__dev_ptc=no'
        echo 'ac_cv_func_gethostbyname_r=yes'
    } >$CONFIG_SITE

    local CONFIGURE_WRAPPER="$BUILD_DIR/configure.sh"
    {
        echo "#!/bin/bash"
        echo 'set -e'
        echo ''
        echo "export CC='$CC'"
        echo "export CPP='$CPP'"
        echo "export AR='$AR'"
        echo "export RANLIB='$RANLIB'"
        echo "export READELF='$READELF'"
        echo "export PYTHON_FOR_BUILD='$PYTHON_FOR_BUILD'"
        echo "export CONFIG_SITE='$CONFIG_SITE'"
        echo ''
        echo 'cd $(dirname $0)'
        echo ''
        if [ "$PYTHON_MAJOR_VERSION" = "2" ]; then
            echo "exec $SRC_DIR/configure \\"
            echo "    --host=$XT_TARGET \\"
            echo "    --build=$BUILD_ON_PLATFORM \\"
            echo "    --prefix=$BUILD_DIR/install \\"
            echo "    --with-threads \\"
            echo "    --enable-ipv6 \\"
            echo "    --enable-unicode=ucs4 \\"
            echo "    --without-ensurepip"
        else
            echo "exec $SRC_DIR/configure \\"
            echo "    --host=$XT_TARGET \\"
            echo "    --build=$BUILD_ON_PLATFORM \\"
            echo "    --prefix=$BUILD_DIR/install \\"
            echo "    --with-threads \\"
            echo "    --enable-ipv6 \\"
            echo "    --without-ensurepip"
        fi
    } >$CONFIGURE_WRAPPER
   chmod +x $CONFIGURE_WRAPPER

   $CONFIGURE_WRAPPER
}

MACHINE_TYPE=$(uname -m)

# Python2
if [ -n "$PYTHON2_URL" ]; then
    download_once $PYTHON2_URL
    unpack_downloaded $PYTHON2_URL "python2" 1
    if [ "$MACHINE_TYPE" = 'x86_64' ]; then
        set +e
        GCC_VERSION=$(gcc --version 2>/dev/null | grep ^gcc)
        set -e
        if [ -n "$GCC_VERSION" ]; then
            if [ ! -f "$DIR_OBJ/python2-config-native.stamp" ]; then
                echo "$GCC_VERSION"
                configure_python_native "$DIR_SRC/python2" "$DIR_OBJ/python2-native"
                touch "$DIR_OBJ/python2-config-native.stamp"
            fi
            $PYTHON_FOR_BUILD "$DIR_HERE/xpatch.py" --input "$DIR_OBJ/python2-native/pyconfig.h" --output "$DIR_OBJ/python2-native/pyconfig_patched.h" --abi x86_64
        fi
    fi
    for abi in $(echo $ABI_ALL | tr ',' ' '); do
        if [ ! -f "$DIR_OBJ/python2-config-${abi}.stamp" ]; then
            configure_python_for_abi "$DIR_SRC/python2" "$DIR_OBJ/python2-$abi" $abi 2
            touch "$DIR_OBJ/python2-config-${abi}.stamp"
        fi
        PYTHON2_MINOR_VERSION=$(cat "$DIR_SRC/python2/Include/patchlevel.h" | sed -n 's/#define[ \t]*PY_MINOR_VERSION[ \t]*\([0-9]*\).*/\1/p')
        PYTHON2_OUTPUT_DIR="$DIR_HERE/output/python-2.${PYTHON2_MINOR_VERSION}"
        case $abi in
            x86)
                PYTHON2_OUTPUT_FILE='pyconfig_linux_i686.h'
                ;;
            arm64)
                PYTHON2_OUTPUT_FILE='pyconfig_linux_aarch64.h'
                ;;
            *)
                PYTHON2_OUTPUT_FILE="pyconfig_linux_${abi}.h"
                ;;
        esac
        mkdir -p $PYTHON2_OUTPUT_DIR
        $PYTHON_FOR_BUILD "$DIR_HERE/xpatch.py" --input "$DIR_OBJ/python2-$abi/pyconfig.h" --output "$PYTHON2_OUTPUT_DIR/$PYTHON2_OUTPUT_FILE" --abi $abi
    done
fi

# Python3
if [ -n "$PYTHON3_URL" ]; then
    download_once $PYTHON3_URL
    unpack_downloaded $PYTHON3_URL "python3" 1
    if [ "$MACHINE_TYPE" = 'x86_64' ]; then
        set +e
        GCC_VERSION=$(gcc --version | grep ^gcc)
        set -e
        if [ -n "$GCC_VERSION" ]; then
            if [ ! -f "$DIR_OBJ/python3-config-native.stamp" ]; then
                echo "$GCC_VERSION"
                configure_python_native "$DIR_SRC/python3" "$DIR_OBJ/python3-native"
                touch "$DIR_OBJ/python3-config-native.stamp"
            fi
            $PYTHON_FOR_BUILD "$DIR_HERE/xpatch.py" --input "$DIR_OBJ/python3-native/pyconfig.h" --output "$DIR_OBJ/python3-native/pyconfig_patched.h" --abi x86_64
        fi
    fi
    for abi in $(echo $ABI_ALL | tr ',' ' '); do
        if [ ! -f "$DIR_OBJ/python3-config-${abi}.stamp" ]; then
            configure_python_for_abi "$DIR_SRC/python3" "$DIR_OBJ/python3-$abi" $abi 2
            touch "$DIR_OBJ/python3-config-${abi}.stamp"
        fi
        PYTHON3_MINOR_VERSION=$(cat "$DIR_SRC/python3/Include/patchlevel.h" | sed -n 's/#define[ \t]*PY_MINOR_VERSION[ \t]*\([0-9]*\).*/\1/p')
        PYTHON3_OUTPUT_DIR="$DIR_HERE/output/python-3.${PYTHON3_MINOR_VERSION}"
        case $abi in
            x86)
                PYTHON3_OUTPUT_FILE='pyconfig_linux_i686.h'
                ;;
            arm64)
                PYTHON3_OUTPUT_FILE='pyconfig_linux_aarch64.h'
                ;;
            *)
                PYTHON3_OUTPUT_FILE="pyconfig_linux_${abi}.h"
                ;;
        esac
        mkdir -p $PYTHON3_OUTPUT_DIR
        $PYTHON_FOR_BUILD "$DIR_HERE/xpatch.py" --input "$DIR_OBJ/python3-$abi/pyconfig.h" --output "$PYTHON3_OUTPUT_DIR/$PYTHON3_OUTPUT_FILE" --abi $abi
    done
fi
