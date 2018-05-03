#!/usr/bin/env bash
# Zsh
sudo apt install zsh curl
chsh -s $(which zsh)
echo $SHELL
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
# Clone dots files
git clone --bare https://github.com/Emiller88/dotfiles.git $HOME/.cfg
# Emacs
git clone https://github.com/hlissner/doom-emacs ~/.emacs.d
bash emacs27.sh
git submodule update --init
cd ~/.emacs.d/
make install compile all
# Set up link to keep home dir clean
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

# Install Vim plug
# https://github.com/junegunn/vim-plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

