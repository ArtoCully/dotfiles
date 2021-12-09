#!/bin/bash

## Install system dependencies
brew install vim
brew install tmux
brew install reattach-to-user-namespace
brew tap caskroom/cask
brew install --cask iterm2

## Add nvm node version manager
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

## Use oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

## Use theme powerlevel10k
git clone https://github.com/ArtoCully/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

## Use zsh
## chsh -s $(which zsh)

## Create .tmux-plugins directory
mkdir -p ~/.tmux-plugins

## Use powerline for tmux-power
git clone https://github.com/ArtoCully/tmux-power.git ~/.tmux-plugins/tmux-power

## Remove files if they alraedy exist
rm -rf ~/.vimrc ~/.zshrc ~/.tmux ~/.tmux.conf> /dev/null

## Symlink files
ln -s ~/dotfiles/zshrc ~/.zshrc
ln -s ~/dotfiles/tmux.conf ~/.tmux.conf
ln -s ~/dotfiles/vimrc ~/.vimrc

