#!/bin/sh -e

function unzipIPA() {

	# Wait for ipa root folder input
	until [[ $root_folder ]]; do
		read -p "🟠 Drag the folder where your .ipa file locates (the parent folder of your .ipa file):" root_folder
	done

	# Find ipa file
	ipas=`find $root_folder -name "*.ipa"`
	if [[ ${ipas[0]} ]]; then
		ipa_path=${ipas[0]}
	else
		echo "🔴 Can not find .ipa file."
		exit 1
	fi

	payload_path="${root_folder}/Payload"

	# unzip .ipa to destination folder
	unzip -d $root_folder $ipa_path

	# Find .app package
	
	apps=`find $payload_path  -name "*.app"`

	app_bundle_path=${apps[0]}
	app_framework_path="${app_bundle_path}/Frameworks"
	app_infoplist_path="${app_bundle_path}/Info.plist"
	app_profile_path="${app_bundle_path}/embedded.mobileprovision"

	echo "🟢 Unzip ipa done!\n"
}

function changeBundleID() {

	read -p "🟠 Enter your new bunder id (If keep the origin bundle id, just press return): " bundle_id

	if [[ $bundle_id ]]; then
		plutil -replace CFBundleIdentifier -string $bundle_id $app_infoplist_path
		echo "🟢 Change app bundle id done!\n"
	else
		echo "🟢 Skip changing app bundle id.\n"
	fi
}

function replaceProvisioningProfile() {

	until [[ $new_profile_path ]]; do
		read -p "🟠 Drag your .mobileprovision file to here: " new_profile_path
	done
	
	cp $new_profile_path $app_profile_path
}

function resignatureApp() {

	until [[ $entitlement_plist_path ]]; do
		read -p "🟠 Drag your app entitlements.plist file to here: " entitlement_plist_path
	done

	# Remove old code signature
	rm -r "${app_bundle_path}/_CodeSignature"

	# List existed certifications in your keychain
	echo `security find-identity`
	echo "\n"

	until [[ $sign_identity ]]; do
		read -p "🟠 Copy your distribution sign identity from above list \
			(eg. iPhone Distribution: COMPANY CORP (E695D9MPGR) ): " sign_identity
	done
	
	codesign -f -s "${sign_identity}" --entitlements "${entitlement_plist_path}" "${app_bundle_path}"

	echo "🟢 Re-sign app Done!\n"
}

function resignatureEmbeddedFramework() {

	frameworks=`find "${app_framework_path}" -name "*.framework"`

	for framework in $frameworks; do
		rm -r "${framework}/_CodeSignature"
		codesign -f -s "${sign_identity}" $framework
	done

	echo "🟢 Re-sign embedded frameworks Done!\n"
}

function remakeIPA() {
	rm -rf $ipa_path
	cd $root_folder

	zip -qr "${ipa_path##*/}" Payload/ -x "*.DS_Store"
	echo "🟢 Remake IPA Done!\n"
}

function startResignature() {

	echo "\n###### IPA Re-signature Program\n"
	echo "Will start re-signing...\n"

	unzipIPA
	changeBundleID
	replaceProvisioningProfile
	resignatureApp
	resignatureEmbeddedFramework
	remakeIPA

	echo "🟢 Haha, Re-signature Done!\n"
}

startResignature



