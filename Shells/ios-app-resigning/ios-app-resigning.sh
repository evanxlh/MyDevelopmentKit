#!/bin/sh -e

## 注意：所有文件或文件夹路径中不能有空格

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

	echo "请确认你的重签名参数配置文件中包含以下几项关键字:\n \
🔸 RootWorkingDirectory: 必须，签名工作的根目录，ipa或xcarchive，provisioning profile文件需要放在这个根目录中。\n \
🔸 SignIdentity: 必须，如[iPhone Distribution: xxx CORP]。可以在命令行用'security find-identity'列出钥匙串中的签名身份信息。\n \
🔸 NewNameForIPA: 可选，如果没有提供则使用.app包的名字加上 '-resigned'. eg, MyApp-resigned.ipa.\n \
🔸 AppleID: 可选，如果没有提供，就不会将重签名的ipa上传到iTnues Connect。\n \
🔸 AppleIDPassword: 可选，如果没有提供，就不会将重签名的ipa上传到iTnues Connect。\n"

	until [[ $resign_configuration_path ]]; do
		read -p "🚦 请将重签名参数配置文件拖动到这里: " resign_configuration_path
	done

	root_working_dir_path=`/usr/libexec/PlistBuddy -c "Print :RootWorkingDirectory" $resign_configuration_path`
	sign_identity=`/usr/libexec/PlistBuddy -c "Print :SignIdentity" $resign_configuration_path`
	apple_id=`/usr/libexec/PlistBuddy -c "Print :AppleID" $resign_configuration_path`
	apple_id_password=`/usr/libexec/PlistBuddy -c "Print :AppleIDPassword" $resign_configuration_path`
	new_ipa_name=`/usr/libexec/PlistBuddy -c "Print :NewNameForIPA" $resign_configuration_path`
	
	if [[ ${root_working_dir_path} ]]; then
		root_working_dir_path=${root_working_dir_path%*/}
	else
		echo "‼️ 重签名参数配置文件【RootWorkingDirectory】内容为空。"
		exit 1
	fi

	if [[ ! ${sign_identity} ]]; then
		echo "‼️ 重签名参数配置文件【SignIdentity】内容为空。"
		exit 1
	fi

	local profiles=`find $root_working_dir_path -name "*.mobileprovision" -depth 1`

	if [[ $profiles ]]; then
		new_profile_path=${profiles[0]}
	else
		echo "‼️ 在 ${root_working_dir_path} 目录下没有找到.mobileprovision文件。"
		exit 1
	fi
}

# Step 2: 准备需要重签名的 App 内容
function prepareAppContents() {

	# 签名后的 ipa 存储在这个目录中
	ipa_output_directory="${root_working_dir_path}/ResignedIPAs"
	makeDirectoryIfNotExists $ipa_output_directory

	# 用于存放 ipa 文件解压出来的内容或者 xcarchive 包中的 app, SwiftSupport 等.
	app_contents_root_path="${root_working_dir_path}/AppContents"
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
		echo "‼️ 在 ${root_working_dir_path} 目录下没有找到.ipa或.xcarchive。"
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

	echo "\n>>>>>>>>开始解压ipa..."

	local ipa_path=$1

	# unzip .ipa to destination folder
	unzip -d $app_contents_root_path $ipa_path

	echo "🔹 解压ipa完成!"
}

# Step 2 - xcarchive : 从 .xcarchive 中提取 app 及 SwiftSupport, 用于接下来的重签名
function prepareAppContentsFromXCArchive() {
	
	echo "\n>>>>>>>> 正在从xcarchive包中提取app内容..."

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

	echo "🔹 从xcarchive包中提取出app内容成功啦!"
}

# Step 3: 删除所有的 _CodeSignature 签名文件夹
function removeAllOldCodeSignature() {

	echo ">>>>>>>> 移除所有旧的签名..."

	oldSignatures=`find $app_contents_root_path -name "_CodeSignature"`

	for signature in $oldSignatures; do
		rm -rf $signature 
		echo "已移除 ${signature}"
	done

	echo "🔹 移除所有旧的签名成功啦!"
}

# Step 4: 获取 entitlements.plsit
function getEntitlementsFromProfile() {

	echo "从${new_profile_path}生成entitlements.plist"

	# 从 Provisioning Profile 中提取出来的 entitlements 信息存储路径
	entitlements_plist_path="${root_working_dir_path}/entitlements.plist"

	removeFileIfExists $entitlements_plist_path

	# 将 *.mobileprovision 文件中的信息输出到一个临时plist
	security cms -D -i $new_profile_path > tempProfile.plist

	# 从临时plist中提取出 entitlements 信息并写入 entitlements.plist
	/usr/libexec/PlistBuddy -x -c 'Print :Entitlements' tempProfile.plist > $entitlements_plist_path

	rm -rf tempProfile.plist

	echo "🔹 生成entitlements.plist成功: ${entitlements_plist_path}"
}

# Step 5: 替换新的签名 profile, 即 .mobileprovision 文件
function replaceWithNewProfile() {

	cp $new_profile_path $app_profile_path

	echo "🔹 替换mobileprovision文件成功!"
}

# Step 6: 更改 bundle id
function changeBundleID() {

	# E6ABDGA.com.company.appresignature.test
	local app_identifier=`/usr/libexec/PlistBuddy -c "Print :application-identifier" $entitlements_plist_path`

	# https://stackoverflow.com/questions/10586153/split-string-into-an-array-in-bash
	IFS='.' read -r -a components <<< "${app_identifier}"
	
	# Remove `E6ABDGA`: https://askubuntu.com/questions/435996/how-can-i-remove-an-entry-from-a-list-in-a-shells-script
	unset components[0]
	
	new_bundle_id=`joinStringComponents "." "${components[@]}"`

	if [[ $new_bundle_id ]]; then
		plutil -replace CFBundleIdentifier -string $new_bundle_id $app_infoplist_path
		echo "🔹 修改app bundle id成功!"
	else
		echo "🔹 不修改app bundle id."
	fi
}

# Step 7: 对 *.app/Frameworks 下的每个库进行签名
function resignFrameworksInAppBundle() {

	echo ">>>>>>>> 开始重签名embedded frameworks, dynamic libraries..."

	local frameworks=`find $app_frameworks_path -name "*.framework" -o -name "*.dylib"`

	for framework in $frameworks; do
		codesign -f -s "${sign_identity}" $framework
	done

	echo "🔹 重签名embedded frameworks, dynamic libraries 成功!"
}

# Step 8: 对 Payload 目录下的所有文件资源进行签名，但不包括对 frameworks 中的文件资源进行签名
function resignAppBundle() {

	echo ">>>>>>>> 开始重签名app bundle..."

	codesign -f -s "${sign_identity}" --entitlements "${entitlements_plist_path}" $app_bundle_path
	
	echo "🔹 重签名app bundle成功!"
}

# Step 9: 验证签名
function verifyAppAfterResigned() {
	# https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html#//apple_ref/doc/uid/TP40005929-CH4-SW9
	codesign --verify --deep --strict --verbose=2 $app_bundle_path
}

# Step 10: 重新制作 ipa 包
function remakeIPA() {

	echo "正在制作新的ipa ..."

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
	
	echo "🔹 制作新的ipa成功: ${ipa_output_directory}/${new_ipa_name}"
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
		echo "iTnues Connect正在验证ipa...\n"

		xcrun altool --validate-app -f $reigned_ipa_path -t iOS -u $apple_id -p $apple_id_password

		echo "🔹 iTnues Connect验证ipa成功!"

	fi
}

function uploadIpaToiTunesConnect() {

	if [[ $apple_id && $apple_id_password ]]; then

		echo "正在上传ipa至iTunes Connect..."

		xcrun altool --upload-app -f $reigned_ipa_path -t iOS -u $apple_id -p $apple_id_password

		echo "🔹 上传ipa至iTunes Connect成功!"

	fi
}

startWorkingFlow
uploadIpaToiTunesConnect




