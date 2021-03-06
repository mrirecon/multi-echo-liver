#!/bin/bash
# Copyright 2020. Uecker Lab, University Medical Center Goettingen.
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# 
# Authors:
# 2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
# 
# This script is used to create results for Figure Water/Fat PHANTOM
# 

set -e

export PATH=$TOOLBOX_PATH:$PATH

if [ ! -e $TOOLBOX_PATH/bart ] ; then
	echo "\$TOOLBOX_PATH is not set correctly!" >&2
	exit 1
fi

which bart


# --- data source ---

RAW=$(readlink -f ./data/phantom_WaterFat_Radial)
TE=$(readlink -f ./data/phantom_WaterFat_Radial_TE)

NECO=$(bart show -d  5 $TE)

mkdir -p phantom_WaterFat_Radial && cd "$_"


# --- prepare raw k-space data ---

../utils/meco_prep.sh -c 10 -e $NECO $RAW kdat_prep

# --- compute trajectory ---

NSMP=$(bart show -d  1 kdat_prep)
FSMP=$((NSMP))
NSPK=$(bart show -d  2 kdat_prep)
NMEA=$(bart show -d 10 kdat_prep)

BASERES=$(( FSMP / 2 ))
OVERGRID=1.5

../utils/meco_traj.sh -F $FSMP -s 2 kdat_prep traj_prep GDC


# --- use all spokes ---

bart extract 10 5 $NMEA kdat_prep kdat_ext
bart extract 10 5 $NMEA traj_prep traj_ext

NMEA_EXT=$(bart show -d 10 kdat_ext)

bart reshape $(bart bitmask 2 10) $((NSPK * NMEA_EXT)) 1 kdat_ext kdat_all
bart reshape $(bart bitmask 2 10) $((NSPK * NMEA_EXT)) 1 traj_ext traj_all

rm -rf kdat_ext.{cfl,hdr} traj_ext.{cfl,hdr}

MODEL_IND=2
R_FILE="moba_R"


# compute init (3-point water/fat separation)

bart extract 5 0 3 $TE tempinit_TE
bart extract 5 0 3 traj_all tempinit_traj
bart extract 5 0 3 kdat_all tempinit_kdat

bart moba -O -G -m0 -i6 -R2 -g -o$OVERGRID -t tempinit_traj tempinit_kdat tempinit_TE tempinit_R

bart extract 6 0 1 tempinit_R tempinit_w
bart extract 6 1 2 tempinit_R tempinit_f
bart extract 6 2 3 tempinit_R tempinit_fB0

IMX=$(bart show -d 0 tempinit_R)
IMY=$(bart show -d 1 tempinit_R)

bart zeros 16 $IMX $IMY 1 1 1 1 1 1 1 1 1 1 1 1 1 1 tempinit_zeros

bart join 6 tempinit_w tempinit_zeros tempinit_f tempinit_zeros tempinit_fB0 R_M${MODEL_IND}_init

rm tempinit_*.{cfl,hdr}

# --- moba reconstruction ---

bart moba -G -m${MODEL_IND} -rQ:1 -rS:0 -rW:3:64:1 -i10 -C100 -R3 -u0.00001 -b11:1 -d4 -g -k --kfilter-2 -o1.5 -I R_M${MODEL_IND}_init -t traj_all kdat_all ${TE} R_M${MODEL_IND}

# --- crop ---
bart resize -c 0 $BASERES 1 $BASERES R_M${MODEL_IND} R_M${MODEL_IND}_crop

bart transpose 0 1 R_M${MODEL_IND}_crop ${R_FILE}

rm R_M*.{cfl,hdr}

bart slice 6 0 ${R_FILE} Water
bart slice 6 1 ${R_FILE} Water_R2S
bart slice 6 2 ${R_FILE} Fat
bart slice 6 3 ${R_FILE} Fat_R2S
bart slice 6 4 ${R_FILE} fB0

# --- fat fraction ---
../utils/fatfrac.sh Water Fat FF

# --- roistat ---
bart roistat -M ../data/phantom_WaterFat_ROIs FF FF_Radial_ROIs_avg
bart roistat -b -D ../data/phantom_WaterFat_ROIs FF FF_Radial_ROIs_std


cd ..
