#!/usr/bin/env bash

RECIPE_ROOT=$(cd "$(dirname "$0")/.."; pwd;)
echo $RECIPE_ROOT

UPLOAD_OWNER="conda-forge"
UPLOAD_CHANNEL="main"

while getopts :u:c: OPT; do
    case "$OPT" in
      u)
        UPLOAD_OWNER="$OPTARG" ;;
      c)
        UPLOAD_CHANNEL="$OPTARG" ;;
      [?])
        # got invalid option
        echo "Usage: $0 [-u upload-owner] [-c upload-channel]" >&2
        exit 1 ;;
    esac
done

if [ ! -z "$UPLOAD_OWNER" ]; then
  echo "Upload will take place to $UPLOAD_OWNER's $UPLOAD_CHANNEL channel for merged recipes.";
fi


config=$(cat <<'CONDARC'

channels:
 - pelson
 - file:///conda_build_dir
 - defaults # As we need conda-build

conda-build:
 root-dir: /conda_build_dir

show_channel_urls: True

CONDARC)


cat << EOF | docker run -i \
                        -v ${RECIPE_ROOT}:/recipe_root \
                        -v ${RECIPE_ROOT}/build_artefacts:/conda_build_dir \
                        -a stdin -a stdout -a stderr \
                        pelson/conda64_obvious_ci \
                        bash || exit $?

export PYTHONUNBUFFERED=1
conda info

yum install -y expat-devel

export CONDA_PY=27
export CONDA_NPY=18
conda build --no-test /recipe_root || exit 1

EOF


# In a separate docker, run the test...
cat << EOF | docker run -i \
                        -v ${RECIPE_ROOT}:/recipe_root \
                        -v ${RECIPE_ROOT}/build_artefacts:/conda_build_dir \
                        -a stdin -a stdout -a stderr \
                        pelson/conda64_obvious_ci \
                        bash || exit $?

export BINSTAR_TOKEN=${BINSTAR_TOKEN}
export PYTHONUNBUFFERED=1
echo "$config" > ~/.condarc

conda info

export CONDA_PY=27
export CONDA_NPY=18
conda build --test /recipe_root || exit $?
/recipe_root/ci_support/upload_or_check_non_existence.py /recipe_root $UPLOAD_OWNER --channel=$UPLOAD_CHANNEL || exit $?

EOF
