#!/bin/bash 

INSTALL_PATH=$HOME/.scripts

if [ ! -d $INSTALL_PATH ]; then
  echo "creating $INSTALL_PATH"
  mkdir $INSTALL_PATH
fi

cp ./git-pr.sh $INSTALL_PATH/git-pr
chmod +x $INSTALL_PATH/git-pr

if [ -z $(which git-pr) ]; then
  echo "$INSTALL_PATH not found in PATH"
  if [ $(echo $SHELL) == "/bin/bash" ]; then
    echo "export PATH=$PATH:$INSTALL_PATH" >> $HOME/.bashrc
    echo "added $INSTALL_PATH to $HOME/.bashrc"
    source $HOME/.bashrc
  fi
  if [ $(echo $SHELL) == "/bin/zsh" ]; then
    echo "export PATH=$PATH:$INSTALL_PATH" >> $HOME/.zshrc
    echo "added $INSTALL_PATH to $HOME/.zshrc"
    source $HOME/.zshrc
  fi
fi

git-pr
