#!/bin/bash
# Copyright 2020. Uecker Lab, University Medical Center Goettingen.
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# 
# Authors:
# 2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
# 
# This script is used to prepare data based on the raw k-space data
# for image reconstructions. It does:
#  1) transpose
#  2) coil compression
#  3) spokes to echos dimensions
#  4) fft along slice dimension
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
-e number of echoes
-h help
EOF
)

NCOI=10
NECO=1

usage="Usage: $0 [-h] [-c NCOI] [-e NECO] <input kdat0> <output kdat1>"

while getopts "hc:e:" opt; do
	case $opt in
	h) 
		echo "$usage"
		echo "$helpstr"
		exit 0 
		;;
	c)
		NCOI=${OPTARG}
		;;
	e)
		NECO=${OPTARG}
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

# --- transpose ---
bart transpose 2 13 $KDAT0 temp_kdat1
bart transpose 1  2 temp_kdat1 temp_kdat2
bart transpose 0  1 temp_kdat2 $KDAT1

# --- dimensions ---
NSMP=$(bart show -d  1 $KDAT1)
NMEA=$(bart show -d 10 $KDAT1)
NSLI=$(bart show -d 13 $KDAT1)

TOT_NSPK=$(bart show -d  2 $KDAT1)

# --- coil compression ---
if [ $NCOI -eq 0 ]; then
	bart scale 1 $KDAT1 temp_kdat1
else
	bart cc -A -p $NCOI $KDAT1 temp_kdat1
fi

# --- from spoke dim to eco dim ---
NSPK=$(( TOT_NSPK / NECO ))

bart reshape $(bart bitmask 2 5) $NECO $NSPK temp_kdat1 temp_kdat2
bart transpose 2 5 temp_kdat2 temp_kdat3

# --- disentangle slices when they are aligned ---
bart fft $(bart bitmask 13) temp_kdat3 $KDAT1

rm temp_*.{cfl,hdr}
