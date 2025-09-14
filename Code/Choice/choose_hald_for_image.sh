#!/bin/bash
# choose_hald_for_image.sh

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [ -f "$SCRIPT_DIR/python.sh" ]; then
   PYTHON_EXE="$SCRIPT_DIR/python.sh"
else
   echo "-W- Missing '$SCRIPT_DIR/python.sh' with path of Python interpreter; assuming default path for python provided by system path"
   PYTHON_EXE="python"
fi


PYTHON_CODE_DIR="$SCRIPT_DIR"
PYSCRIPT="$PYTHON_CODE_DIR/choose_hald_for_image.py"

# Pass all arguments to choose_hald_for_image.py
"$PYTHON_EXE"  "$PYSCRIPT"  "$@"


