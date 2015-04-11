cat << EOF | docker run -i -v ${PWD}/recipe:/recipe_root -v ${PWD}/build_artefacts:/conda_build_dir \
                        -a stdin -a stdout -a stderr pelson/conda64_obvious_ci bash
cat << CONDARC > ~/.condarc
channels:
 - pelson
 - file:///conda_build_dir
 - defaults # As we need conda-build

conda-build:
 root-dir: /conda_build_dir

show_channel_urls: True

CONDARC

export BINSTAR_TOKEN=${BINSTAR_TOKEN}

#set -x

conda info
conda clean --lock
export CONDA_NPY=18
#linux32 yum install -y expat-devel
#linux32 yum install -y gcc-c++ automake libtool expat-devel texinfo
export PYTHONUNBUFFERED=1


conda build --no-test /recipe_root || exit 1
#obvci_conda_build_dir.py /recipe_root pelson || exit 1

EOF


# In a separate docker, run the test...

