#!/bin/bash

src_dir=$1

if [ -z "$src_dir" ]; then
	echo "usage: bash compile.sh <dir> [compiler flags]"
	exit 1;
fi

for dir in $(find $src_dir -maxdepth 1 -type d | sort);
do
	cd $dir
	if [[ ! -d "addons/sourcemod/scripting" || -z $(ls -A "addons/sourcemod/scripting") ]]; then
		cd - > /dev/null
		continue
	fi

	mkdir -p "addons/sourcemod/plugins/levels_ranks"
	plugins=$(realpath addons/sourcemod/plugins/levels_ranks)

	for src_file in $(find addons/sourcemod/scripting -maxdepth 1 -type f -name "*.sp")
	do
		noext_file=$(basename "$src_file" .sp)
		echo "==============================================================="
		echo "Source name: $noext_file"
		echo "---------------------------------------------------------------"
		bin_file=$noext_file'.smx'
		spcomp $src_file -o=$plugins/$bin_file ${@:2}
	done
	
	cd - > /dev/null
done