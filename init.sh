#!/bin/bash

## Install system dependencies
brew install tmux
brew install reattach-to-user-namespace
brew tap caskroom/cask
brew install --cask iterm2

## Use oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

## Use theme powerlevel10k
git clone https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

## Use zsh
## chsh -s $(which zsh)

## Use powerline for tmux
git clone git@github.com:powerline/powerline.git

## Remove files if they alraedy exist
rm -rf ~/.vim ~/.vimrc ~/.zshrc ~/.tmux ~/.tmux.conf> /dev/null

## Symlink files
ln -s ~/dotfiles/zshrc ~/.zshrc
ln -s ~/dotfiles/tmux.conf ~/.tmux.conf
ln -s ~/dotfiles/vimrc ~/.vimrc

