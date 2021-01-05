#!/bin/bash
# Copyright 2020. Uecker Lab, University Medical Center Goettingen.
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# 
# Authors:
# 2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
# 
# This script 
# 1. loads the reconstructed liver data
# 2. loads the saved ROIs file
# 3. compute the average (avg) and standard deviation (std) in TABLE 1
# 

set -e

export PATH=$TOOLBOX_PATH:$PATH

if [ ! -e $TOOLBOX_PATH/bart ] ; then
	echo "\$TOOLBOX_PATH is not set correctly!" >&2
	exit 1
fi

which bart

extract_R2S_W_F()
{
	FILE="$1"            # INPUT

	IND_R2S="$2"         # INPUT
	IND_W="$3"           # INPUT
	IND_F="$4"           # INPUT

	IND_TIME="$5"        # INPUT
	IND_SLICE="$6"       # INPUT

	OUTPUT_PREFIX="$7"   # OUTPUT

	bart slice 6 ${IND_R2S} 10 ${IND_TIME} 13 ${IND_SLICE} ${FILE} ${OUTPUT_PREFIX}_R2S

	bart slice 6 ${IND_W} 10 ${IND_TIME} 13 ${IND_SLICE} ${FILE} ${OUTPUT_PREFIX}_W
	bart slice 6 ${IND_F} 10 ${IND_TIME} 13 ${IND_SLICE} ${FILE} ${OUTPUT_PREFIX}_F
}




# --- create destination folder ---
mkdir -p liver_table && cd "$_"



# slice 3; scan 1; WFR2S
FILE=$(readlink -f "../liver_2D_s3_scan1/R_WFR2S_RT")
PREFIX="2D_scan1_WFR2S"

extract_R2S_W_F $FILE 2 0 1 8 0 $PREFIX

../utils/fatfrac.sh ${PREFIX}_W ${PREFIX}_F ${PREFIX}_FF


# slice 3; scan 1; WF2R2S
FILE=$(readlink -f "../liver_2D_s3_scan1/R_WF2R2S_RT")
PREFIX="2D_scan1_WF2R2S"

extract_R2S_W_F $FILE 1 0 2 8 0 $PREFIX

../utils/fatfrac.sh ${PREFIX}_W ${PREFIX}_F ${PREFIX}_FF


# slice 1; scan 2; WFR2S
FILE=$(readlink -f "../liver_2D_s1_scan2/R_WFR2S_RT")
PREFIX="2D_scan2_WFR2S"

extract_R2S_W_F $FILE 2 0 1 6 0 $PREFIX

../utils/fatfrac.sh ${PREFIX}_W ${PREFIX}_F ${PREFIX}_FF


# slice 1; scan 2; WFR2S JST
FILE=$(readlink -f "../liver_2D_s1_scan2/R_WFR2S_RT_JST")
PREFIX="2D_scan2_WFR2S_JST"

extract_R2S_W_F $FILE 2 0 1 6 0 $PREFIX

../utils/fatfrac.sh ${PREFIX}_W ${PREFIX}_F ${PREFIX}_FF


# slice 1; scan 2; WF2R2S
FILE=$(readlink -f "../liver_2D_s1_scan2/R_WF2R2S_RT")
PREFIX="2D_scan2_WF2R2S"

extract_R2S_W_F $FILE 1 0 2 6 0 $PREFIX

../utils/fatfrac.sh ${PREFIX}_W ${PREFIX}_F ${PREFIX}_FF


# 3D BH; scan1
FILE=$(readlink -f "../liver_3D_BH_scan1/R_WFR2S_3D_BH")
PREFIX="3D_BH_scan1_WFR2S"

extract_R2S_W_F $FILE 2 0 1 0 22 ${PREFIX}

../utils/fatfrac.sh ${PREFIX}_W ${PREFIX}_F ${PREFIX}_FF


# 3D BH; scan2
FILE=$(readlink -f "../liver_3D_BH_scan2/R_WFR2S_3D_BH")
PREFIX="3D_BH_scan2_WFR2S"

extract_R2S_W_F $FILE 2 0 1 0 16 $PREFIX

../utils/fatfrac.sh ${PREFIX}_W ${PREFIX}_F ${PREFIX}_FF


# 3D FB; scan1
FILE=$(readlink -f "../liver_3D_FB_scan1/R_WFR2S_3D_FB")
PREFIX="3D_FB_scan1_WFR2S"

extract_R2S_W_F $FILE 2 0 1 0 22 $PREFIX

../utils/fatfrac.sh ${PREFIX}_W ${PREFIX}_F ${PREFIX}_FF

# 3D FB; scan2
FILE=$(readlink -f "../liver_3D_FB_scan2/R_WFR2S_3D_FB")
PREFIX="3D_FB_scan2_WFR2S"

extract_R2S_W_F $FILE 2 0 1 4 16 $PREFIX

../utils/fatfrac.sh ${PREFIX}_W ${PREFIX}_F ${PREFIX}_FF



# --- group all files into array ---
declare -a FILE_ARR=(
	2D_scan1_WFR2S
	2D_scan1_WF2R2S
	2D_scan2_WFR2S
	2D_scan2_WFR2S_JST
	2D_scan2_WF2R2S
	3D_BH_scan1_WFR2S
	3D_BH_scan2_WFR2S
	3D_FB_scan1_WFR2S
	3D_FB_scan2_WFR2S
)

# get length of an array
LEN=${#FILE_ARR[@]}



# --- use for loop to read all R2S & FF files ---
for (( IND=0; IND<${LEN}; IND++ )); do

	echo ">>> R2S "

	bart roistat -M ../liver_ROIs ${FILE_ARR[$IND]}_R2S ${FILE_ARR[$IND]}_R2S_avg

	bart roistat -b -D ../liver_ROIs ${FILE_ARR[$IND]}_R2S ${FILE_ARR[$IND]}_R2S_std

	echo "> ${FILE_ARR[$IND]} avg: "
	bart show ${FILE_ARR[$IND]}_R2S_avg

	echo "> ${FILE_ARR[$IND]} std: "
	bart show ${FILE_ARR[$IND]}_R2S_std

	echo "   "

	echo ">>> FF "

	bart roistat -M ../liver_ROIs ${FILE_ARR[$IND]}_FF ${FILE_ARR[$IND]}_FF_avg

	bart roistat -b -D ../liver_ROIs ${FILE_ARR[$IND]}_FF ${FILE_ARR[$IND]}_FF_std

	echo "> ${FILE_ARR[$IND]} avg: "
	bart show ${FILE_ARR[$IND]}_FF_avg

	echo "> ${FILE_ARR[$IND]} std: "
	bart show ${FILE_ARR[$IND]}_FF_std

	echo "   "


done
