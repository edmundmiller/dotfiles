with import <nixpkgs> {};

python37.withPackages (ps: with ps; [
  jupyterlab_server
  jupyter_core
  jupyter
  ipython
  ipykernel
  notebook
  matplotlib
  numpy
  toolz
  pandas
])
