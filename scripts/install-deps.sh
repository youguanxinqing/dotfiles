echo "install fnm"
curl -fsSL https://fnm.vercel.app/install | bash

echo "install rust"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

echo "install goup"
curl -sSf https://raw.githubusercontent.com/owenthereal/goup/master/install.sh | sh

echo "install fzf"
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

