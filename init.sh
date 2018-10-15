#!/bin/bash

## Install system dependencies
brew install zsh tmux neovim python3 ag reattach-to-usernamspace
brew tap caskroom/cask
brew cask install iterm2

## Update neovim and plugins
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
pip3 install neovim

## Use zsh
chsh -s $(which zsh)

## Remove files if they alraedy exist
rm -rf ~/.vim ~/.vimrc ~/.zshrc ~/.tmux ~/.tmux.conf ~/.config/nvim 2> /dev/null

## Neovim folder dependencies
mkdir -p ~/.config ~/.config/nvim

## Symlink files
ln -s ~/.dotfiles/zshrc ~/.zshrc
ln -s ~/.dotfiles/tmux.conf ~/.tmux.conf
ln -s ~/.dotfiles/vimrc ~/.config/nvim/init.vim
