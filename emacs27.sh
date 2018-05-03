mdkir ~/Git/
mkdir ~/Git/emacs
cd ~/Git/
git clone emiller88@git.sv.gnu.org:/srv/git/emacs.git
sudo apt-get install build-essential automake texinfo libjpeg-dev libncurses5-dev
sudo apt-get install libtiff5-dev libgif-dev libpng-dev libxpm-dev libgtk-3-dev libgnutls28-dev 
cd emacs/
./autogen.sh
./configure --with-mailutils --with-xwidgets
make
src/emacs --version
sudo make install
