# !/bin/bash

# install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# install via brew
brew bundle --file=./Brewfile

sudo xattr -dr com.apple.quarantine /Applications/Chrome.app
sudo xattr -dr com.apple.quarantine /Applications/Notion.app
sudo xattr -dr com.apple.quarantine /Applications/Alfred\ 5.app
sudo xattr -dr com.apple.quarantine /Applications/Adguard.app
sudo xattr -dr com.apple.quarantine /Applications/iTerm.app
sudo xattr -dr com.apple.quarantine /Applications/Karabiner-Elements.app
sudo xattr -dr com.apple.quarantine /Applications/Sourcetree.app
sudo xattr -dr com.apple.quarantine /Applications/Postman.app
sudo xattr -dr com.apple.quarantine /Applications/Altair\ GraphQL\ Client.app
sudo xattr -dr com.apple.quarantine /Applications/Visual\ Studio\ Code.app
sudo xattr -dr com.apple.quarantine /Applications/WebStorm.app
sudo xattr -dr com.apple.quarantine /Applications/DataGrip.app

sudo xattr -dr com.apple.quarantine /Applications/Slack.app
sudo xattr -dr com.apple.quarantine /Applications/Magnet.app
sudo xattr -dr com.apple.quarantine /Applications/AladinEbook.app
sudo xattr -dr com.apple.quarantine /Applications/KakaoTalk.app
sudo xattr -dr com.apple.quarantine /Applications/Numbers.app

# Node
chmod 755 ./node/install.sh
./node/install.sh

# Change Git Default branch name
git config --global init.defaultBranch main
git config core.ignorecase false

# zsh
chmod 755 ./zsh/install.sh
./zsh/install.sh

# claude
chmod 755 ./claude/install.sh
./claude/install.sh
