#!/bin/sh

cd ~
USER_HOME_DIR="$PWD"
PROFILE_PATH="$USER_HOME_DIR/.profile"

MY_EMAIL="xxx.xxx@xxx.com"
USER_NAME="xxxx"

function updateGemSystem() {
	sudo gem update —system
}

function installHomebrew() {
	echo "\n####################"
	echo "Install homebrew ......"
	/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	brew install ruby
	echo "Install homebrew done."
}

function installCocoapods() {
	echo "\n####################"
	echo "Install cocoapods ......"

	sudo gem update --system
	sudo gem install -n /usr/local/bin  cocoapods
	pod setup

	echo "Install cocoapods done."
}

function setupSSHKey() {

	echo "\n####################"
	echo "Generate ssh key ......"

	SSH_DIR="$USER_HOME_DIR/.ssh"
	SSH_CONFIG_PATH="$SSH_DIR/config"

	if [ -f "$SSH_DIR/id_rsa" ]; then
		echo "$SSH_DIR/id_rsa already exists, so skips generating ssh key"
		return
	fi

	# Generate ssh key, and add it to ssh agent
	ssh-keygen -t rsa -C "$MY_EMAIL"
	ssh-add ~/.ssh/id_rsa

	# Let ssh key loaded automatically: add identity file to ~/.ssh/config
	if [ ! -f "$SSH_CONFIG_PATH" ]; then
		touch "$SSH_CONFIG_PATH"
  	echo "Host *\nAddKeysToAgent yes\nUseKeychain yes" > $SSH_CONFIG_PATH
	fi

    # Append text to the end of file.
	echo "IdentityFile ~/.ssh/id_rsa" >> $SSH_CONFIG_PATH

	echo "SSH key done."
}

function setupGit() {

	echo "Configurate git ....."

	git config --global user.name "$USER_NAME"
	git config --global user.email "$MY_EMAIL"
	git config --global color.ui true

	# Git command completion
	
	curl -o git-completion.bash https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash
	cp git-completion.bash ~/.git-completion.bash
	rm git-completion.bash

	if [ ! -f "$PROFILE_PATH" ]; then
		touch "$PROFILE_PATH"
	fi

	echo "source ~/.git-completion.bash" > $PROFILE_PATH
	echo "Git config done.\n"
}

function startAutoSetup() {
	echo "Automatical setup starts, it will cost you some time, just leave it doing tasks. Maybe some operations need you enter user account password."
	
	updateGemSystem
	installHomebrew
	installCocoapods
	setupSSHKey
	setupGit

	echo "All setups done."
}

startAutoSetup