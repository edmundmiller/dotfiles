#!/usr/bin/env bash

git clone https://github.com/hlissner/doom-emacs ~/.emacs.d
bash emacs26.sh
git clone --bare https://github.com/Emiller88/dotfiles.git $HOME/.cfg
git submodule update --init
function config { /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $@ }
mkdir -p .config-backup
config checkout
if [ $? = 0 ]; then
  echo "Checked out config.";
  else
    echo "Backing up pre-existing dot files.";
    config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config-backup/{}
fi;
config checkout
config config status.showUntrackedFiles no
# Go to my doom branch till I commit to it
config checkout doom
cd .emacs.d/
make install

# Install Vim plug
# https://github.com/junegunn/vim-plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
