#!/bin/bash
# copyright Yang Lab 2023
#
# This is a bash script that downloads Yang Lab DANDI
# db into subfolder in working directory.
# Works in Linux 6.4.3+, WSL 1.2.5+, and MacOS 10.17+

# PLACE IDENTIFIER LOCATION HERE; eg 000004/0.220126.1852
ID="000615/draft"


OPENID="dandi download DANDI:$ID"

printf 'creating python virtual environment at .venv...'
python3 -m venv .venv
source .venv/bin/activate
printf ' done!\ninstalling DANDI dependencies: %s...\n' "$ID"
pip install "dandi>=0.13.0"
pip install "neo"

printf ' done!\nfetching: %s...\n' "$ID"

eval "$OPENID"

printf ' done!\nExtracting nwb files...\n'

for d in */* ; do
    PYID="python3 -c 'import ephysCONV; ephysCONV.nwb2txt(\"$d\")'"
    eval "$PYID"
done

printf 'done!\n'

