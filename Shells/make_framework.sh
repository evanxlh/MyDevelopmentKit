#!/bin/sh -e

REVEAL_FRAMEWORK_IN_FINDER=true

BUILD_DIR="${PROJECT_DIR}/Build"
FREAMEWORK_NAME="${PROJECT_NAME}"
FREAMEWORK_OUTPUT_DIR="${PROJECT_DIR}/Distribution"
ARCHIVE_PATH_IOS_DEVICE="${BUILD_DIR}/ios_device.xcarchive"
ARCHIVE_PATH_IOS_SIMULATOR="${BUILD_DIR}/ios_simulator.xcarchive"
# ARCHIVE_PATH_MACOS="./build/macos.xcarchive"

function archiveOnePlatform {
    echo "▸ Starts archiving the scheme: ${1} for destination: ${2};\n▸ Archive path: ${3}"

    xcodebuild archive \
        -scheme "${1}" \
        -destination "${2}" \
        -archivePath "${3}" \
        VALID_ARCHS="${4}" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES | xcpretty

    # sudo gem install -n /usr/local/bin xcpretty
    # xcpretty makes xcode compile information much more readable.
}

function archiveAllPlatforms {

    # https://www.mokacoding.com/blog/xcodebuild-destination-options/

    # Platform                Destination
    # iOS                    generic/platform=iOS
    # iOS Simulator            generic/platform=iOS Simulator
    # iPadOS                generic/platform=iPadOS
    # iPadOS Simulator        generic/platform=iPadOS Simulator
    # macOS                    generic/platform=macOS
    # tvOS                    generic/platform=tvOS
    # watchOS                generic/platform=watchOS
    # watchOS Simulator        generic/platform=watchOS Simulator
    # carPlayOS                generic/platform=carPlayOS
    # carPlayOS Simulator    generic/platform=carPlayOS Simulator

    SCHEME=${1}

    archiveOnePlatform $SCHEME "generic/platform=iOS Simulator" ${ARCHIVE_PATH_IOS_SIMULATOR} "x86_64"
    archiveOnePlatform $SCHEME "generic/platform=iOS" ${ARCHIVE_PATH_IOS_DEVICE} "armv7 arm64"
    # archiveOnePlatform $SCHEME "generic/platform=macOS" ${ARCHIVE_PATH_MACOS}
}

function makeUniversalFramework {

    FRAMEWORK_RELATIVE_PATH="Products/Library/Frameworks"
    SIMULATOR_FRAMEWORK="${ARCHIVE_PATH_IOS_SIMULATOR}/${FRAMEWORK_RELATIVE_PATH}/${FREAMEWORK_NAME}.framework"
    DEVICE_FRAMEWORK="${ARCHIVE_PATH_IOS_DEVICE}/${FRAMEWORK_RELATIVE_PATH}/${FREAMEWORK_NAME}.framework"

    OUTPUT_FRAMEWORK="${FREAMEWORK_OUTPUT_DIR}/${FREAMEWORK_NAME}.framework"

    mkdir -p "${OUTPUT_FRAMEWORK}"

    # Copy all the contents of iphoneos framework to output framework dir.
    cp -rf "${DEVICE_FRAMEWORK}/." "${OUTPUT_FRAMEWORK}"

    lipo "${SIMULATOR_FRAMEWORK}/${FREAMEWORK_NAME}" "${DEVICE_FRAMEWORK}/${FREAMEWORK_NAME}" \
        -create -output "${OUTPUT_FRAMEWORK}/${FREAMEWORK_NAME}"

    # For Swift framework, Swiftmodule needs to be copied in the universal framework
    if [ -d "${SIMULATOR_FRAMEWORK}/Modules/${FRAMEWORK_NAME}.swiftmodule/" ]; then
        cp -f "${SIMULATOR_FRAMEWORK}/Modules/${FRAMEWORK_NAME}.swiftmodule/*" "${OUTPUT_FRAMEWORK}/Modules/${FRAMEWORK_NAME}.swiftmodule/" | echo
    fi
    if [ -d "${DEVICE_FRAMEWORK}/Modules/${FRAMEWORK_NAME}.swiftmodule/" ]; then
        cp -f "${DEVICE_FRAMEWORK}/Modules/${FRAMEWORK_NAME}.swiftmodule/*" "${OUTPUT_FRAMEWORK}/Modules/${FRAMEWORK_NAME}.swiftmodule/" | echo
    fi
}

echo "#####################"
echo "▸ Cleaning Framework output dir: ${FREAMEWORK_OUTPUT_DIR}"
rm -rf "$FREAMEWORK_OUTPUT_DIR"

#### Make Dynamic Framework

echo "▸ Archive framework: ${FREAMEWORK_NAME}"
archiveAllPlatforms "$FREAMEWORK_NAME"

echo "▸ Make universal framework: ${FREAMEWORK_NAME}.framework"
makeUniversalFramework

# Clean Build
rm -rf "{$BUILD_DIR}"

if [ ${REVEAL_FRAMEWORK_IN_FINDER} = true ]; then
    open "${FREAMEWORK_OUTPUT_DIR}/"
fi
