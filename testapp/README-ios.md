# Building in iOS

Building the test application for iOS requires:

* XCode 8 or above, along with the xcode command line tools (run
  `xcode-select --install` after installing the main XCode package)
* A configured developer account and development team (see developer.apple.com
  for details)
* The cordova-cli tools (which require node.js; see [the Apache Cordova
  site](https://cordova.apache.org/docs/en/latest/guide/cli) for instructions)
* The cordova `plugman` tool (`npm install --global plugman`)
* The `ios-deploy` tool (`npm install --global ios-deploy`)
* A [build.json file with details of your accounts and
  certificates](https://cordova.apache.org/docs/en/7.x/guide/platforms/ios/index.html#using-buildjson).

 Once all of these are available, run the `runi.sh` shell script to install
 the plugin, build and deploy the application.
 
