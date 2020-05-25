#!/bin/sh -e

# Help Functions

function joinStringComponents { 
	# https://zaiste.net/how_to_join_elements_of_an_array_in_bash/
	local IFS="$1"; shift; echo "$*"; 
}

function makeDirectoryIfNotExists {
	local dir=$1
	if [[ ! -d $dir ]]; then
		mkdir $dir
	fi
}

function removeDirectoryIfExists {
	local dir=$1
	if [[ -d $dir ]]; then
		# 删除历史残留文件
		rm -rf $dir
	fi
}

function removeFileIfExists {
	local file=$1
	if [[ -f $file ]]; then
		rm -rf $file
	fi
}

# Step 1: 读取配置文件，准备签名需要的资源
function readConfiguration() {

	echo "This shell read the re-signature information from a configuration plist file, make sure plist file contains following keys:\n\n \
🔸 RootWorkingDirectory: must, the absolute directory path which shell script works in, make sure your .ipa or .xcarchive exists in this directory.\n\n \
🔸 MobileprovisionPath: must, .mobileprovision absolute file path\n\n \
🔸 SignIdentity: must, like 【iPhone Distribution: COMPANY CORP (AABBCCDDEE)】, you can use command 'security find-identity' to list identities in your keychain\n\n \
🔸 NewNameForIPA: optional, if not provied, use ipa name appending by '-resigned'. eg, MyApp-resigned.ipa\n\n \
🔸 AppleID: optional, if not provided, will not upload re-signed ipa to app store\n\n \
🔸 AppleIDPassword: optional, if not provided, will not upload re-signed ipa to app store\n\n"

	until [[ $resign_configuration_path ]]; do
		read -p "🚦 Drag the re-signature configuration plist file to here: " resign_configuration_path
	done

	root_working_dir_path=`/usr/libexec/PlistBuddy -c "Print :RootWorkingDirectory" $resign_configuration_path`
	sign_identity=`/usr/libexec/PlistBuddy -c "Print :SignIdentity" $resign_configuration_path`
	new_profile_path=`/usr/libexec/PlistBuddy -c "Print :MobileprovisionPath" $resign_configuration_path`
	apple_id=`/usr/libexec/PlistBuddy -c "Print :AppleID" $resign_configuration_path`
	apple_id_password=`/usr/libexec/PlistBuddy -c "Print :AppleIDPassword" $resign_configuration_path`
	new_ipa_name=`/usr/libexec/PlistBuddy -c "Print :NewNameForIPA" $resign_configuration_path`
	
	if [[ ${root_working_dir_path} ]]; then
		root_working_dir_path=${root_working_dir_path%*/}
	else
		echo "‼️ no 【RootWorkingDirectory】 value provided in re-signature configuration plist file."
		exit 1
	fi

	if [[ ! ${new_profile_path} ]]; then
		echo "‼️ no 【MobileprovisionPath】 value provided in re-signature configuration plist file."
		exit 1
	fi

	if [[ ! ${sign_identity} ]]; then
		echo "‼️ no 【SignIdentity】 value provided in re-signature configuration plist file."
		exit 1
	fi
}

# Step 2: 准备需要重签名的 App 内容
function prepareAppContents() {

	# 签名后的 ipa 存储在这个目录中
	ipa_output_directory="${root_working_dir_path}/ResignedIPAs"
	makeDirectoryIfNotExists $ipa_output_directory

	# 用于存放 ipa 文件解压出来的内容或者 xcarchive 包中的 app, SwiftSupport 等.
	app_contents_root_path="${root_working_dir_path}/AppContentsForResigning"
	payload_path="${app_contents_root_path}/Payload"

	# 删除历史残留文件
	removeDirectoryIfExists $app_contents_root_path
	makeDirectoryIfNotExists $app_contents_root_path

	local ipas=`find $root_working_dir_path -name "*.ipa" -depth 1`
	local archives=`find $root_working_dir_path -name "*.xcarchive" -depth 1`

	if [[ $ipas ]]; then
		prepareAppContentsFromIPA ${ipas[0]}
	elif [[ $archives ]]; then
		prepareAppContentsFromXCArchive ${archives[0]}
	else
		echo "‼️ Haven't found .ipa or .xcarchive, please put .ipa or xcarchive package into root working directory"
		exit 1
	fi

	# 找出制作 IPA 所需要的所有内容的根目录，如 Payload, SwiftSupport 等，排除隐藏文件，浅遍历
	app_root_contents=`find $app_contents_root_path ! -iname ".*"  -depth 1`

	# 查找 .app package
	local apps=`find $payload_path  -name "*.app" -depth 1`

	app_bundle_path=${apps[0]}
	app_infoplist_path="${app_bundle_path}/Info.plist"
	app_profile_path="${app_bundle_path}/embedded.mobileprovision"
	app_frameworks_path="${app_bundle_path}/Frameworks"
}

# Step 2 - ipa : 解压 ipa, 用于接下来的重签名
function prepareAppContentsFromIPA() {

	echo "\n>>>>>>>> Unzip ipa..."

	local ipa_path=$1

	# unzip .ipa to destination folder
	unzip -d $app_contents_root_path $ipa_path

	echo "🔹 Unzip ipa done!"
}

# Step 2 - xcarchive : 从 .xcarchive 中提取 app 及 SwiftSupport, 用于接下来的重签名
function prepareAppContentsFromXCArchive() {
	echo "\n>>>>>>>> Extract app contents from xcarchive..."

	# Payload
	#  	- *.app
	# SwiftSupport
	makeDirectoryIfNotExists $payload_path

	local archive_path=$1
	local apps=`find "${archive_path}/Products/Applications" -name "*.app" -depth 1`

	for app in $apps; do
		cp -rf $app $payload_path 
	done


	local swift_support_path="${archive_path}/SwiftSupport"
	if [[ -d $swift_support_path ]]; then
		cp -rf $swift_support_path $app_contents_root_path
	fi

	echo "🔹 Extract app contents from xcarchive done!"
}

# Step 3: 删除所有的 _CodeSignature 签名文件夹
function removeAllOldCodeSignature() {

	echo ">>>>>>>> Removing old code signatures..."

	oldSignatures=`find $app_contents_root_path -name "_CodeSignature"`

	for signature in $oldSignatures; do
		rm -rf $signature 
		echo "Removing ${signature}"
	done

	echo "🔹 Removing old code signatures done!"
}

# Step 4: 获取 entitlements.plsit
function getEntitlementsFromProfile() {

	echo "Generate entitlements.plist from ${new_profile_path}"

	## 从 Profile 中提取出来的 entitlements 信息存储路径
	entitlements_plist_path="${root_working_dir_path}/entitlements.plist"

	removeFileIfExists $entitlements_plist_path

	# 从 *.mobileprovision 文件中提取出 entitlements.plist
	security cms -D -i $new_profile_path > tempProfile.plist
	/usr/libexec/PlistBuddy -x -c 'Print :Entitlements' tempProfile.plist > $entitlements_plist_path

	# E6ABDGA.com.company.appresignature.test
	local app_identifier=`/usr/libexec/PlistBuddy -c "Print :application-identifier" $entitlements_plist_path`

	# https://stackoverflow.com/questions/10586153/split-string-into-an-array-in-bash
	IFS='.' read -r -a components <<< "${app_identifier}"
	
	# Remove `E6ABDGA`: https://askubuntu.com/questions/435996/how-can-i-remove-an-entry-from-a-list-in-a-shells-script
	unset components[0]
	
	new_bundle_id=`joinStringComponents "." "${components[@]}"`

	rm -rf tempProfile.plist

	echo "🔹 Generate entitlements.plist done at path: ${entitlements_plist_path}"
}

# Step 5: 替换新的签名 profile, 即 .mobileprovision 文件
function replaceWithNewProfile() {

	cp $new_profile_path $app_profile_path

	echo "🔹 Replacing mobileprovision file done!"
}

# Step 6: 更改 bundle id
function changeBundleID() {

	if [[ $new_bundle_id ]]; then
		plutil -replace CFBundleIdentifier -string $new_bundle_id $app_infoplist_path
		echo "🔹 Change app bundle id done!"
	else
		echo "🔹 Skip changing app bundle id."
	fi
}

# Step 7: 对 *.app/Frameworks 下的每个库进行签名
function resignFrameworksInAppBundle() {

	echo ">>>>>>>>  Will re-sign frameworks and dynamic libraries..."

	local frameworks=`find $app_frameworks_path -name "*.framework" -o -name "*.dylib"`

	for framework in $frameworks; do
		codesign -f -s "${sign_identity}" $framework
	done

	echo "🔹 Re-sign frameworks and dynamic libraries done!"
}

# Step 8: 对 Payload 目录下的所有文件资源进行签名，但不包括对 frameworks 中的文件资源进行签名
function resignAppBundle() {

	echo ">>>>>>>>  Will re-sign app resource..."

	codesign -f -s "${sign_identity}" --entitlements "${entitlements_plist_path}" $app_bundle_path
	
	echo "🔹 Re-sign app resource done!"
}

# Step 9: 验证签名
function verifyAppAfterResigned() {
	# https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html#//apple_ref/doc/uid/TP40005929-CH4-SW9
	codesign --verify --deep --strict --verbose=2 $app_bundle_path
}

# Step 10: 重新制作 ipa 包
function remakeIPA() {

	echo "Remaking IPA ..."

	if [[ ! $new_ipa_name ]]; then
		new_ipa_name="$(basename $ipa_path .ipa)-resigned.ipa"
 	else
 		# new_ipa_name=${ipa_path##*/}
 		new_ipa_name="${new_ipa_name}.ipa"
 	fi

 	# if [[ -d $swiftsupport_path ]]; then
		# zip -qr $new_ipa_name Payload/ SwiftSupport/ -x "*.DS_Store"
 	# else
 	# 	zip -qr $new_ipa_name Payload/ -x "*.DS_Store"
 	# fi

 	local root_content_names=`ls $app_contents_root_path`
 	local contents_will_zipped=""
 	for name in $root_content_names; do
 		contents_will_zipped+="$name "
 	done

 	cd $app_contents_root_path
 	zip -qr $new_ipa_name $contents_will_zipped -x "*.DS_Store"
 	mv $new_ipa_name $ipa_output_directory

 	reigned_ipa_path="${ipa_output_directory}/${new_ipa_name}"
	
	echo "🔹 Remake ipa done at path: ${ipa_output_directory}/${new_ipa_name}"
}

function startWorkingFlow() {
	readConfiguration
	prepareAppContents
	removeAllOldCodeSignature
	getEntitlementsFromProfile
	replaceWithNewProfile
	changeBundleID
	resignFrameworksInAppBundle
	resignAppBundle
	verifyAppAfterResigned
	remakeIPA
}

function validateResignedIpa() {

	if [[ $apple_id && $apple_id_password ]]; then
		echo "Validating re-signed ipa...\n"

		xcrun altool --validate-app -f $reigned_ipa_path -t iOS -u $apple_id -p $apple_id_password

		echo "🔹 Validate re-signed ipa Done!"

	fi
}

function uploadResignedIpaToAppStore() {

	if [[ $apple_id && $apple_id_password ]]; then

		echo "Uploading re-signed app to AppStore..."

		xcrun altool --upload-app -f $reigned_ipa_path -t iOS -u $apple_id -p $apple_id_password

		echo "🔹 Uploading re-signed app Done!"

	fi
}

startWorkingFlow
uploadResignedIpaToAppStore




