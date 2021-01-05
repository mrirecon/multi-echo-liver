#!/bin/bash
# Copyright 2020. Uecker Lab, University Medical Center Goettingen.
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# 
# Authors:
# 2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
# 
# This script is used to prepare data based on the raw Cartesian k-space data
# for image reconstructions. It does:
#  1) coil compression
#  2) correct bipolar echoes
# 

set -e

export PATH=$TOOLBOX_PATH:$PATH

if [ ! -e $TOOLBOX_PATH/bart ] ; then
	echo "\$TOOLBOX_PATH is not set correctly!" >&2
	exit 1
fi

helpstr=$(cat <<- EOF
prepare raw k-space data
-c number of compressed coils
-B bipolar echoes
-h help
EOF
)

NCOI=10
BIPOLAR=0

usage="Usage: $0 [-h] [-c NCOI] [-B] <input kdat0> <output kdat1>"

while getopts "hc:B" opt; do
	case $opt in
	h) 
		echo "$usage"
		echo "$helpstr"
		exit 0 
		;;
	c)
		NCOI=${OPTARG}
		;;
	B)
		BIPOLAR=1
		;;
	\?)
		echo "$usage" >&2
		exit 1
		;;
	esac
done

shift $(($OPTIND -1 ))

KDAT0=$(readlink -f "$1") # INPUT k-space data
KDAT1=$(readlink -f "$2") # OUTPUT reformatted k-space data

# --- coil compression ---
if [ $NCOI -eq 0 ]; then
	bart scale 1 $KDAT0 $KDAT1
else
	bart cc -A -p $NCOI $KDAT0 $KDAT1
fi

# --- correct bipolar echoes ---
NECO=$(bart show -d  5 $KDAT1)

if [ $BIPOLAR -eq 1 ]; then

	for (( E=0; E<${NECO}; E++ )); do

		bart slice 5 $E $KDAT1 temp_kdat

		if [ $(($E%2)) -eq 1 ]; then
			bart flip 1 temp_kdat temp_kdat_E${E}
		else
			bart scale 1 temp_kdat temp_kdat_E${E}
		fi

	done

	bart join 5 `seq -s" " -f "temp_kdat_E%g" 0 $(( $NECO - 1 ))` $KDAT1

fi


rm temp_*.{cfl,hdr}
