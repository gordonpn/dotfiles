#!/bin/bash

if [[ "$MACHINE" != "Mac" ]]; then
	echo "$MACHINE is not supported"
	exit 1
fi

echo "$MACHINE is supported"
echo "Installing Homebrew..."
read -n 1 -s -r -p "Press any key to continue"
echo
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
open -a "App Store"
echo "Please make sure you are logged into the App Store then continue"
read -n 1 -s -r -p "Press any key to continue"
echo
brew bundle install --file="$(pwd)"/lists/Brewfile

mkdir -p "$HOME/workspace"

sudo true

if [[ $EUID -gt 0 ]]; then
	echo "Please run with sudo"
	exit
fi

chsh -s /usr/local/bin/zsh

bash .macos

download_chrome_extensions() {
	git clone https://github.com/Sainan/Universal-Bypass.git "$HOME/chrome-extensions/Universal-Bypass"
	git clone https://github.com/iamadamdev/bypass-paywalls-chrome.git "$HOME/chrome-extensions/bypass-paywalls-chrome"
	git clone https://github.com/Ibit-to/google-unlocked.git "$HOME/chrome-extensions/google-unlocked"
}

download_completions() {
	git clone https://github.com/sawadashota/go-task-completions.git "$HOME/completions/go-task-completions"
	git clone https://github.com/Berger91/taskfile-zsh-autocompletion.git "$HOME/completions/taskfile-zsh-autocompletion"
}

create_symlinks() {
	DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
	for file in "$DIR"/dotfiles/.*; do
		if [ -d "$file" ]; then
			continue
		fi
		file_name="${file##*/}"
		ln -sfn "$file" "$HOME/$file_name"
	done
}

symlink_iterm_settings() {
	DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
	for file in "$DIR"/iterm2/*; do
		if [ -d "$file" ]; then
			continue
		fi
		file_name="${file##*/}"
		ln -sfn "$file" "$HOME/Library/Preferences/$file_name"
	done
}

symlink_ghostty_settings() {
	DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
	mkdir -p "$HOME/.config/ghostty"
	for file in "$DIR"/ghostty/*; do
		if [ -d "$file" ]; then
			continue
		fi
		file_name="${file##*/}"
		ln -sfn "$file" "$HOME/.config/ghostty/$file_name"
	done
}

download_chrome_extensions
download_completions
create_symlinks
symlink_iterm_settings
symlink_ghostty_settings

# sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
