#!/bin/bash

cd ..

# excute the clean script
find -maxdepth 10 -type f -executable -name 'clean' -execdir {} \;

mkdir _bak

str_date=$(date +%Y%m%d_%H%M)

prj_path=$(cd `dirname $0`; pwd)
str_prj="${prj_path##*/}"

str_pack="_bak/${str_prj}_${str_date}.tar.gz"

tar -czvf ${str_pack} --exclude=_bak --exclude=*.gz --exclude=*.fsdb *
# tar -czvf ${str_pack} --exclude=_bak --exclude=*.gz --exclude=*.fsdb --exclude=test_vector*/* *

# zip -r -x=*.fsdb -x=*.zip ${str_pack} *