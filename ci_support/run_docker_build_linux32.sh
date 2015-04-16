#!/usr/bin/env bash

UPLOAD_OWNER=""
UPLOAD_CHANNELS=main


while getopts :u:c: OPT; do
    case "$OPT" in
      u)
        UPLOAD_OWNER="$OPTARG" ;;
      c)
        UPLOAD_CHANNELS="$OPTARG" ;;
      [?])
        # got invalid option
        echo "Usage: $0 [-u upload-owner] [-c upload-channels]" >&2
        exit 1 ;;
    esac
done

if [ ! -z "$UPLOAD_OWNER" ]; then
  echo "Upload will take place to $UPLOAD_OWNER's $UPLOAD_CHANNELS channel(s) for merged recipes.";
fi


cat << EOF | docker run -i -v ${PWD}/recipe:/recipe_root -v ${PWD}/build_artefacts:/conda_build_dir \
                        -a stdin -a stdout -a stderr pelson/conda32_obvious_ci linux32
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
yum install -y expat-devel
export PYTHONUNBUFFERED=1

conda build --no-test /recipe_root || exit 1

EOF


# In a separate docker, run the test...
cat << EOF | docker run -i -v ${PWD}/recipe:/recipe_root -v ${PWD}/build_artefacts:/conda_build_dir \
                        -a stdin -a stdout -a stderr pelson/conda32_obvious_ci linux32

cat << CONDARC > ~/.condarc
channels:
 - pelson
 - file:///conda_build_dir
 - defaults # As we need conda-build

conda-build:
 root-dir: /conda_build_dir

show_channel_urls: True

CONDARC


conda info
export CONDA_NPY=18
conda build --test /recipe_root || exit 1

# TODO: if not uploading, check that the distribution doesn't already exist. This will mean that PRs will
# fail if they fail to update the build number etc.
if [ ! -z "$UPLOAD_OWNER" ] && [ ! -z "$BINSTAR_TOKEN" ]
then
    # It would be good if the command were: add_to_channels which uploaded only if necsessary.
    binstar --token=${BINSTAR_TOKEN} upload /conda_build_dir/*/*.tar.bz2 --user=$UPLOAD_OWNER --channel=$UPLOAD_CHANNELS
else
    python -c "from obvci.conda_tools.build_directory import distribution_exists; \
           from binstar_client.utils import get_binstar; \
           from argparse import Namespace; \
           from conda_build.metadata import MetaData; \
           import sys; \
           \
           cli = get_binstar(Namespace(token=\"${BINSTAR_TOKEN}\", site=None)); \
           meta = MetaData(\"/recipe_root\"); \
           exists = distribution_exists(cli, \"${UPLOAD_OWNER}\", meta); \
           sys.exit(10 if not exists else 0); \
           " || exit_num=$? && \
                echo "Distribution already exists. Does the version or build number need increasing?" && \
                exit ${exit_num}


fi


EOF



