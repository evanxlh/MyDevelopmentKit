#!/bin/sh -e

function readConfiguration() {

	echo "This shell read the re-signature information from a configuration plist file, make sure plist file contains following keys:\n \
▸ rootWorkingPath: must, the absolute directory path which contains original ipa file.\n \
▸ signIdentity: must, like 【iPhone Distribution: COMPANY CORP (AABBCCDDEE)】, you can use command 'security find-identity' to list identities in your keychain\n \
▸ mobileprovisionFilePath: must, .mobileprovision absolute file path\n \
▸ entitlementsPlistFilePath: must, the absolute file path of your app entitlements.plist\n \
▸ newBundleID: option, if not provided, use original bundle id\n \
▸ newNameForIPA: option, don't include '.ipa' suffix. If not provided, use original IPA name.\n \
	"

	until [[ $resign_configuration_path ]]; do
		read -p "🟠 Drag the re-signature configuration plist file to here: " resign_configuration_path
	done

	root_working_path=`/usr/libexec/PlistBuddy -c "Print :rootWorkingPath" $resign_configuration_path`
	sign_identity=`/usr/libexec/PlistBuddy -c "Print :signIdentity" $resign_configuration_path`
	new_profile_path=`/usr/libexec/PlistBuddy -c "Print :mobileprovisionFilePath" $resign_configuration_path`
	entitlements_plist_path=`/usr/libexec/PlistBuddy -c "Print :entitlementsPlistFilePath" $resign_configuration_path`
	new_bundle_id=`/usr/libexec/PlistBuddy -c "Print :newBundleID" $resign_configuration_path`
	new_ipa_name=`/usr/libexec/PlistBuddy -c "Print :newNameForIPA" $resign_configuration_path`
	
	if [[ ${root_working_path} ]]; then
		root_working_path=${root_working_path%*/}
	else
		echo "🔴 no 【rootWorkingPath】 value provided in re-signature configuration plist file."
		exit 1
	fi

	if [[ ! ${new_profile_path} ]]; then
		echo "🔴 no 【mobileprovisionFilePath】 value provided in re-signature configuration plist file."
		exit 1
	fi

	if [[ ! ${entitlements_plist_path} ]]; then
		echo "🔴 no 【entitlementsPlistFilePath】 value provided in re-signature configuration plist file."
		exit 1
	fi

	if [[ ! ${sign_identity} ]]; then
		echo "🔴 no 【signIdentity】 value provided in re-signature configuration plist file."
		exit 1
	fi
}

function unzipIPA() {

	payload_path="${root_working_path}/Payload"

	rm -rf $payload_path

	# Find ipa file
	ipas=`find $root_working_path -name "*.ipa"`
	if [[ ${ipas[0]} ]]; then
		ipa_path=${ipas[0]}
	else
		echo "🔴 Can not find .ipa file in ${root_working_path}\n"
		exit 1
	fi

	# unzip .ipa to destination folder
	unzip -d $root_working_path $ipa_path

	# Find .app package
	
	apps=`find $payload_path  -name "*.app"`

	app_bundle_path=${apps[0]}
	app_framework_path="${app_bundle_path}/Frameworks"
	app_infoplist_path="${app_bundle_path}/Info.plist"
	app_profile_path="${app_bundle_path}/embedded.mobileprovision"

	echo "🟢 Unzip ipa done!\n"
}

function changeBundleID() {

	if [[ $new_bundle_id ]]; then
		plutil -replace CFBundleIdentifier -string $new_bundle_id $app_infoplist_path
		echo "🟢 Change app bundle id done!\n"
	else
		echo "🟢 Skip changing app bundle id.\n"
	fi
}

function resignatureApp() {

	cp $new_profile_path $app_profile_path

	# Remove old code signature
	rm -r "${app_bundle_path}/_CodeSignature"
	
	codesign -f -s "${sign_identity}" --entitlements "${entitlements_plist_path}" "${app_bundle_path}"

	echo "🟢 Re-sign app Done!\n"
}

function resignatureEmbeddedFramework() {

	frameworks=`find "${app_framework_path}" -name "*.framework"`

	for framework in $frameworks; do

		rm -r "${framework}/_CodeSignature"
		codesign -f -s "${sign_identity}" $framework

		echo "🟢 Re-sign embedded frameworks: ${framework##*/} Done!\n"
	done
}

function remakeIPA() {

	echo "🟢 Remaking IPA ...\n"

	rm -rf $ipa_path
	cd $root_working_path

	if [[ ! $new_ipa_name ]]; then
		new_ipa_name=${ipa_path##*/}
	else
		new_ipa_name="${new_ipa_name}.ipa"
	fi

	zip -qr $new_ipa_name Payload/ -x "*.DS_Store"
	echo "🟢 Remake IPA Done!\n"
}

function startResignature() {

	echo "\n###### IPA Re-signature Program"
	echo "Will start re-signing...\n"

	readConfiguration
	unzipIPA
	changeBundleID
	resignatureApp
	resignatureEmbeddedFramework
	remakeIPA

	echo "🟢 Haha, the whole re-signature finished!\n"
}

startResignature



