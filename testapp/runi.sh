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

case `/bin/uname -s` in
    CYGWIN*)  NODEEXEC="cmd /c" ;;
    *)        NODEEXEC=""       ;;
esac

echo -e "${RED}Run on default ios device (executing scripts using '$NODEEXEC')..."

if [ -d platforms/ios/cordova/plugins/uk.org.dsf.cordova.media ]; then
    echo -e "${GRN}Plugman uninstall...${WHT}"
    $NODEEXEC plugman uninstall --platform ios --project "platforms/ios" --plugin "uk.org.dsf.cordova.media" || exit 1
    echo -e "${GRN}OK"
fi

echo -e "${GRN}Plugman install...${WHT}"
$NODEEXEC plugman install --platform ios --project "platforms/ios" --plugin "../mediacentre" || exit 1
echo -e "${GRN}OK"

echo -e "${GRN}Build...${WHT}"
$NODEEXEC cordova build ios || exit 1
echo -e "${GRN}Build OK${WHT}"

echo -e "${GRN}Run...${WHT}"
$NODEEXEC cordova run ios --noprepare --nobuild
