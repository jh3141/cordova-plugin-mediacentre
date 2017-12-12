#!/bin/bash

# Script for building and executing the sample with the current version of the plugin on an android device.
# If a parameter is specified, it should be an ip-address:port pair for an android device running ADB-over-wireless
# Otherwise a single local USB device is expected to be connected.

RED='\033[1;31m'
GRN='\033[0;32m'
WHT='\033[0m'

# if running under cygwin, we need to make sure we run the windows .bat versions of node commands
# rather than the unix-style shell scripts, because the latter get confused by cygwin paths
#
# ... of course, we can't actually run the ios build under cygwin, but leaving this in here
# for potential future use (?), as it does no actual harm at this point.

UNAME=/bin/uname
if [ -x /usr/bin/uname ]; then UNAME=/usr/bin/uname; fi
case `$UNAME -s` in
    CYGWIN*)  NODEEXEC="cmd /c" ;;
    *)        NODEEXEC=""       ;;
esac

echo -e "${RED}Run on default ios device (executing scripts using '$NODEEXEC')..."

if [ -d platforms/ios/Media\ Test/Plugins/uk.org.dsf.cordova.media ]; then
    echo -e "${GRN}cordova plugin rm...${WHT}"
    $NODEEXEC cordova plugin rm "uk.org.dsf.cordova.media" || exit 1
    echo -e "${GRN}rm -rf node_modules/cordova-plugin-mediacentre...${WHT}"
    rm -rf node_modules/cordova-plugin-mediacentre
    echo -e "${GRN}OK"
fi

echo -e "${GRN}cordova plugin add...${WHT}"
$NODEEXEC cordova plugin add --force "../mediacentre" || exit 1
echo -e "${GRN}OK"

echo -e "${GRN}Build...${WHT}"
$NODEEXEC cordova build ios || exit 1
echo -e "${GRN}Build OK${WHT}"

echo -e "${GRN}Run...${WHT}"
$NODEEXEC cordova run ios --noprepare --nobuild
