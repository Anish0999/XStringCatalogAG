#!/bin/bash

GREEN="\033[0;32m"
CLEAR="\033[0m"

if which xcodebuild > /dev/null; then
    echo -e "Gathering ${GREEN}xcodebuild sdk versions${CLEAR}..."
    BUILD_DIR=`pwd`/build
    LATEST_IOS_SDK_VERSION=`xcodebuild -showsdks | grep iphonesimulator | cut -d ' ' -f 4 | ruby -e 'puts STDIN.read.chomp.split("\n").last'`
    LATEST_IOS_VERSION=`xcrun simctl list | grep ^iOS | ruby -e 'puts /\(([0-9.]+).*\)/.match(STDIN.read.chomp.split("\n").last).to_a[1]'`
    LATEST_TVOS_SDK_VERSION=`xcodebuild -showsdks | grep appletvsimulator | cut -d ' ' -f 4 | ruby -e 'puts STDIN.read.chomp.split("\n").last'`
    LATEST_TVOS_VERSION=`xcrun simctl list | grep ^tvOS | ruby -e 'puts /\(([0-9.]+).*\)/.match(STDIN.read.chomp.split("\n").last).to_a[1]'`
    LATEST_WATCHOS_SDK_VERSION=`xcodebuild -showsdks | grep -e '-sdk watchos' | cut -d ' ' -f 2 | ruby -e 'puts STDIN.read.chomp.split("\n").last'`
    LATEST_WATCHOS_VERSION=`xcrun simctl list | grep ^watchOS | ruby -e 'puts /\(([0-9.]+).*\)/.match(STDIN.read.chomp.split("\n").last).to_a[1]'`
    LATEST_MACOS_SDK_VERSION=`xcodebuild -showsdks | grep -e '-sdk macosx' | cut -d ' ' -f 2 | ruby -e 'puts STDIN.read.chomp.split("\n").last'`
    BUILD_IOS_SDK_VERSION=${NIMBLE_BUILD_IOS_SDK_VERSION:-$LATEST_IOS_SDK_VERSION}
    RUNTIME_IOS_VERSION=${NIMBLE_RUNTIME_IOS_VERSION:-$LATEST_IOS_VERSION}
    BUILD_TVOS_SDK_VERSION=${NIMBLE_BUILD_TVOS_SDK_VERSION:-$LATEST_TVOS_SDK_VERSION}
    RUNTIME_TVOS_VERSION=${NIMBLE_RUNTIME_TVOS_VERSION:-$LATEST_TVOS_VERSION}
    BUILD_WATCHOS_SDK_VERSION=${NIMBLE_BUILD_WATCHOS_SDK_VERSION:-$LATEST_WATCHOS_SDK_VERSION}
    RUNTIME_WATCHOS_VERSION=${NIMBLE_RUNTIME_WATCHOS_VERSION:-$LATEST_WATCHOS_VERSION}
    BUILD_MACOS_SDK_VERSION=${NIMBLE_BUILD_MACOS_SDK_VERSION:-$LATEST_MACOS_SDK_VERSION}
fi

set -e

function color_if_overridden {
    local actual=$1
    local env_var=$2
    if [ -z "$env_var" ]; then
        printf "$actual"
    else
        printf "$GREEN$actual$CLEAR"
    fi
}

function print_env {
    echo "=== Environment ==="
    echo " iOS:"
    echo "   Latest iOS SDK: $LATEST_IOS_SDK_VERSION"
    echo "   Building with iOS SDK: `color_if_overridden $BUILD_IOS_SDK_VERSION $NIMBLE_BUILD_IOS_SDK_VERSION`"
    echo "   Running with iOS: `color_if_overridden $RUNTIME_IOS_VERSION $NIMBLE_RUNTIME_IOS_VERSION`"
    echo
    echo " tvOS:"
    echo "   Latest tvOS SDK: $LATEST_TVOS_SDK_VERSION"
    echo "   Building with tvOS SDK: `color_if_overridden $BUILD_TVOS_SDK_VERSION $NIMBLE_BUILD_TVOS_SDK_VERSION`"
    echo "   Running with tvOS: `color_if_overridden $RUNTIME_TVOS_VERSION $NIMBLE_RUNTIME_TVOS_VERSION`"
    echo
    echo " watchOS:"
    echo "   Latest watchOS SDK: $LATEST_WATCHOS_SDK_VERSION"
    echo "   Building with watchOS SDK: `color_if_overridden $BUILD_WATCHOS_SDK_VERSION $NIMBLE_BUILD_WATCHOS_SDK_VERSION`"
    echo "   Running with watchOS: `color_if_overridden $RUNTIME_WATCHOS_VERSION $NIMBLE_RUNTIME_WATCHOS_VERSION`"
    echo
    echo " macOS:"
    echo "   Latest macOS SDK: $LATEST_MACOS_SDK_VERSION"
    echo "   Building with macOS SDK: `color_if_overridden $BUILD_MACOS_SDK_VERSION $NIMBLE_BUILD_MACOS_SDK_VERSION`"
    echo
    echo "======= END ======="
    echo
}

function run {
    echo -e "$GREEN==>$CLEAR $@"
    "$@"
}

function test_ios {
    run set -o pipefail && xcodebuild -project Nimble.xcodeproj -scheme "Nimble" -configuration "Debug" -destination "generic/platform=iOS" OTHER_SWIFT_FLAGS='$(inherited) -suppress-warnings' build | xcpretty

    run osascript -e 'tell app "Simulator" to quit'
    run set -o pipefail && xcodebuild -project Nimble.xcodeproj -scheme "Nimble" -configuration "Debug" -sdk "iphonesimulator$BUILD_IOS_SDK_VERSION" -destination "name=iPhone SE (3rd generation),OS=$RUNTIME_IOS_VERSION" OTHER_SWIFT_FLAGS='$(inherited) -suppress-warnings' build-for-testing test-without-building | xcpretty
}

function test_tvos {
    run set -o pipefail && xcodebuild -project Nimble.xcodeproj -scheme "Nimble" -configuration "Debug" -destination "generic/platform=tvOS" OTHER_SWIFT_FLAGS='$(inherited) -suppress-warnings' build | xcpretty

    run osascript -e 'tell app "Simulator" to quit'
    run set -o pipefail && xcodebuild -project Nimble.xcodeproj -scheme "Nimble" -configuration "Debug" -sdk "appletvsimulator$BUILD_TVOS_SDK_VERSION" -destination "name=Apple TV,OS=$RUNTIME_TVOS_VERSION" OTHER_SWIFT_FLAGS='$(inherited) -suppress-warnings' build-for-testing test-without-building | xcpretty
}

function test_watchos {
    run set -o pipefail && xcodebuild -project Nimble.xcodeproj -scheme "Nimble" -configuration "Debug" -destination "generic/platform=watchOS" OTHER_SWIFT_FLAGS='$(inherited) -suppress-warnings' build | xcpretty

    run osascript -e 'tell app "Simulator" to quit'
    run set -o pipefail && xcodebuild -project Nimble.xcodeproj -scheme "Nimble" -configuration "Debug" -sdk "watchsimulator$BUILD_WATCHOS_SDK_VERSION" -destination "name=Apple Watch Series 6 (40mm),OS=$RUNTIME_WATCHOS_VERSION" OTHER_SWIFT_FLAGS='$(inherited) -suppress-warnings' build-for-testing test-without-building | xcpretty
}

function test_macos {
    run set -o pipefail && xcodebuild -project Nimble.xcodeproj -scheme "Nimble" -configuration "Debug" -sdk "macosx$BUILD_MACOS_SDK_VERSION" OTHER_SWIFT_FLAGS='$(inherited) -suppress-warnings' build-for-testing test-without-building | xcpretty
}

function test_xcode_spm_macos {
    mv Nimble.xcodeproj Nimble.xcodeproj.bak
    trap 'mv Nimble.xcodeproj.bak Nimble.xcodeproj' EXIT
    run set -o pipefail && xcodebuild -scheme "Nimble" -configuration "Debug" -sdk "macosx$BUILD_MACOS_SDK_VERSION" -destination "platform=macOS" OTHER_SWIFT_FLAGS='$(inherited) -suppress-warnings' build-for-testing test-without-building | xcpretty
}

function test_xcode_spm_ios {
    run osascript -e 'tell app "Simulator" to quit'
    mv Nimble.xcodeproj Nimble.xcodeproj.bak
    trap 'mv Nimble.xcodeproj.bak Nimble.xcodeproj' EXIT
    run set -o pipefail && xcodebuild -scheme "Nimble" -configuration "Debug" -sdk "iphonesimulator$BUILD_IOS_SDK_VERSION" -destination "name=iPhone SE (3rd generation),OS=$RUNTIME_IOS_VERSION" OTHER_SWIFT_FLAGS='$(inherited) -suppress-warnings' build-for-testing test-without-building | xcpretty
}

function test_xcode_spm_tvos {
    run osascript -e 'tell app "Simulator" to quit'
    mv Nimble.xcodeproj Nimble.xcodeproj.bak
    trap 'mv Nimble.xcodeproj.bak Nimble.xcodeproj' EXIT
    run set -o pipefail && xcodebuild -scheme "Nimble" -configuration "Debug" -sdk "appletvsimulator$BUILD_TVOS_SDK_VERSION" -destination "name=Apple TV,OS=$RUNTIME_TVOS_VERSION" OTHER_SWIFT_FLAGS='$(inherited) -suppress-warnings' build-for-testing test-without-building | xcpretty
}

function test_xcode_spm_watchos {
    run osascript -e 'tell app "Simulator" to quit'
    mv Nimble.xcodeproj Nimble.xcodeproj.bak
    trap 'mv Nimble.xcodeproj.bak Nimble.xcodeproj' EXIT
    run set -o pipefail && xcodebuild -scheme "Nimble" -configuration "Debug" -sdk "watchsimulator$BUILD_WATCHOS_SDK_VERSION" -destination "name=Apple Watch Series 6 (40mm),OS=$RUNTIME_WATCHOS_VERSION" OTHER_SWIFT_FLAGS='$(inherited) -suppress-warnings' build-for-testing test-without-building | xcpretty
}

function test_podspec {
    echo "Gathering CocoaPods installation information..."
    run bundle exec pod --version
    echo "Linting podspec..."
    run bundle exec pod lib lint Nimble.podspec --skip-import-validation --verbose
}

function test_carthage {
    echo "Gathering Carthage installation information..."
    run carthage version
    echo "Verifying that Carthage artifacts build"
    run carthage build --no-skip-current --use-xcframeworks --verbose
}

function test_swiftpm {
    if [ -d .build ]; then
        run swift package clean
    fi
    run swift build -Xswiftc -suppress-warnings && swift test -Xswiftc -suppress-warnings --enable-test-discovery
}

function test_swiftpm_docker {
    run docker build -t nimble-tests -f Dockerfile.test --no-cache .
    run docker run -it --privileged=true nimble-tests
}

function test() {
    test_macos
    test_ios
    test_tvos
    test_watchos

    if xcodebuild --help 2>&1 | grep xcframework > /dev/null; then
        test_xcode_spm_macos
        test_xcode_spm_ios
        test_xcode_spm_tvos
        test_xcode_spm_watchos
    else
        echo "Not testing with Swift Package Manager version of Xcode because it requires at least Xcode 11"
    fi

    if which swift-test; then
        test_swiftpm
    else
        echo "Not testing with the Swift Package Manager because swift-test is not installed"
    fi

    if which docker; then
        test_swiftpm_docker
    else
        echo "Not testing linux in docker container since docker is not in PATH!"
    fi
}

function clean {
    run rm -rf ~/Library/Developer/Xcode/DerivedData\; true
}

function help {
    echo "Usage: $0 COMMANDS"
    echo
    echo "COMMANDS:"
    echo " all               - Runs the all tests of macos, ios and tvos"
    echo " clean             - Cleans the derived data directory of Xcode. Assumes default location"
    echo " help              - Displays this help"
    echo " macos             - Runs the tests on macOS 10.10 (Yosemite and newer only)"
    echo " macos_xcodespm    - Runs the tests on macOS using the Swift Package Manager version of Xcode"
    echo " ios               - Runs the tests as an iOS device"
    echo " ios_xcodespm      - Runs the tests as an iOS device using the Swift Package Manager version of Xcode"
    echo " tvos              - Runs the tests as an tvOS device"
    echo " tvos_xcodespm     - Runs the tests as an tvOS device using the Swift Package Manager version of Xcode"
    echo " watchos           - Runs the tests as an watchOS device"
    echo " watchos_xcodespm  - Runs the tests as an watchOS device using the Swift Package Manager version of Xcode"
    echo " podspec           - Runs pod lib lint against the podspec to detect breaking changes"
    echo " carthage          - Runs verifyies that the carthage artifacts build"
    echo " swiftpm           - Runs the tests built by the Swift Package Manager"
    echo " swiftpm_docker    - Runs the tests built by the Swift Package Manager in a docker linux container"
    echo
    exit 1
}

function main {
    print_env
    for arg in $@
    do
        case "$arg" in
            clean) clean ;;
            ios) test_ios ;;
            ios_xcodespm) test_xcode_spm_ios ;;
            tvos) test_tvos ;;
            tvos_xcodespm) test_xcode_spm_tvos ;;
            watchos) test_watchos ;;
            watchos_xcodespm) test_xcode_spm_watchos ;;
            macos) test_macos ;;
            macos_xcodespm) test_xcode_spm_macos ;;
            podspec) test_podspec ;;
            carthage) test_carthage ;;
            test) test ;;
            all) test ;;
            swiftpm) test_swiftpm ;;
            swiftpm_docker) test_swiftpm_docker ;;
            help) help ;;
        esac
    done

    if [ $# -eq 0 ]; then
        clean
        test
    fi
}

main $@
