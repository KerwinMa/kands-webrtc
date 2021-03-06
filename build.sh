#!/bin/bash

function usage {
    echo "Usage:"
    echo ""
    echo "      build.sh [ -t, --target_arch (arm|arm64|ia32|x64|mipsel) ] [ -r, --revision rev_number ] [ -d, --debug ]"
    echo ""
    echo "           -t, --target_arch    Default target architecture. Default is arm"
    echo "           -r, --revision       Build release. Default is latest"
    echo "           -d, --debug          Build debug mode. By default release is build"
    echo ""
}

# Get input parameters
while [ "$1" != "" ]; do
    case $1 in
        -r | --revision )
            shift
            revision=$1
            ;;
        -t | --target_arch )
            shift
            # Valid target architectures : arm, arm64, ia32, x64, mipsel
            target_arch=$1
           ;;
        -d | --debug )
            # Activate debug mode
            BIN_DIR="out/Debug"
           ;;
        -h | --help )
            usage
            exit
            ;;
        * )
            usage
            exit 1
    esac
    shift
done

WORKING_PATH=$(cd $(dirname $0) ; pwd )
[ -n "$revision" ] && REVISION=" -r $revision"
[ -n "$target_arch" ] && TARGET_ARCH="target_arch=$target_arch"

# Get depot_tools
[ -d ./depot_tools ] || git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git || \
    { echo "Unable to download depot_tools"; exit 1; }
export PATH=$PATH:$WORKING_PATH/depot_tools

# Clean
rm -f libjingle_peerconnection*
(cd src/out/Debug; ninja -t clean)
(cd src/out/Release; ninja -t clean)

# Update
[ -z "$revision" ] && REV="latest" || REV=$revision
echo "Build: Synchronize repository to revision: $REV"
gclient sync $REVISION --force --nohooks|| { echo "Error: Unable to sync source code"; exit 1 ; }

echo "Build: Set android environment and run hooks"
source src/build/android/envsetup.sh || exit 1
#[[ $GYP_DEFINES =~ "build_with_libjingle" ]] || GYP_DEFINES=" build_with_libjingle=1 $GYP_DEFINES"
#[[ $GYP_DEFINES =~ "build_with_chromium" ]] || GYP_DEFINES=" build_with_chromium=0 $GYP_DEFINES"
#[[ $GYP_DEFINES =~ "libjingle_java" ]] || GYP_DEFINES=" libjingle_java=1 $GYP_DEFINES"
#[[ $GYP_DEFINES =~ "enable_tracing" ]] || GYP_DEFINES=" enable_tracing=1 $GYP_DEFINES"
[[ $GYP_DEFINES =~ "OS" ]] || GYP_DEFINES=" OS=android $GYP_DEFINES"
export GYP_DEFINES="$GYP_DEFINES $TARGET_ARCH"
echo "Build: GYP_DEFINES = $GYP_DEFINES"
gclient runhooks || { echo "Error: runhooks failed"; exit 1; }

[ -z "$BIN_DIR" ] && BIN_DIR="out/Release"
(
    cd src
    ninja -C $BIN_DIR libjingle_peerconnection_jar || { echo "Error: WebRTC compilation failed"; exit 1; }
)
cp src/$BIN_DIR/libjingle_peerconnection.jar . && \
cp src/$BIN_DIR/libjingle_peerconnection_so.so . || { echo "Error: Unable to find libjingle binaries"; exit 1 ; }