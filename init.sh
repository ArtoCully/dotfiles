#!/bin/bash

## Install system dependencies
brew install zsh tmux python3 ag reattach-to-usernamspace
brew tap caskroom/cask
brew cask install iterm2

## Use zsh
chsh -s $(which zsh)

## Remove files if they alraedy exist
rm -rf ~/.vim ~/.vimrc ~/.zshrc ~/.tmux ~/.tmux.conf> /dev/null

## Symlink files
ln -s ~/.dotfiles/zshrc ~/.zshrc
ln -s ~/.dotfiles/tmux.conf ~/.tmux.conf
ln -s ~/.dotfiles/vimrc ~/.vimrc

