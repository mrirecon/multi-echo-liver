#!/bin/bash
# Copyright 2020. Uecker Lab, University Medical Center Goettingen.
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# 
# Authors:
# 2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
# 
# This script is used to create results for 
# single-slice multi-echo free-breathing acquisition using 
# two different models: 
#  1. WFR2S  (single R2S between water and fat); 
#  2. WF2R2S (independent R2S between water and fat).
# 

set -ex

export PATH=$TOOLBOX_PATH:$PATH

if [ ! -e $TOOLBOX_PATH/bart ] ; then
	echo "\$TOOLBOX_PATH is not set correctly!" >&2
	exit 1
fi

which bart

# --- data source ---

DNAME=$1

RAW=$(readlink -f ./data/${DNAME})
TE=$(readlink -f ./data/liver_TE)

NECO=$(bart show -d  5 $TE)

mkdir -p ${DNAME} && cd "$_"

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


# --- SSA-FARY ---
# ./../meco_ssafary.sh -F $FSMP -w 161 traj_prep kdat_prep traj_ssa kdat_ssa EOF SV


# --- use only 10 frames ---

bart extract 10 20 30 kdat_prep kdat_part
bart extract 10 20 30 traj_prep traj_part

TMEA=$(bart show -d 10 kdat_part)

# --- moba reconstruction ---

declare -a MODEL_ARR=(1 2)
declare -a R_FILE_ARR=(R_WFR2S_RT R_WF2R2S_RT)

MODEL_ARRLEN=${#MODEL_ARR[@]}

for (( M_IND=1; M_IND<${MODEL_ARRLEN}+1; M_IND++ )); do

	MODEL_IND=${MODEL_ARR[${M_IND}-1]}
	R_FILE_IND=${R_FILE_ARR[${M_IND}-1]}

	for (( F=0; F<${TMEA}; F++ )); do

		bart slice 10 $F traj_part tempmoba_traj
		bart slice 10 $F kdat_part tempmoba_kdat

		# compute init (3-point water/fat separation)

		../utils/meco_init.sh -m ${MODEL_IND} -o ${OVERGRID} tempmoba_traj tempmoba_kdat $TE tempmoba_R_INIT


		bart moba -G -m${MODEL_IND} -rQ:1 -rS:0 -rW:3:$(bart bitmask 6):1 -u0.01 -i8 -C100 -R3 -d4 -k --kfilter-2 -g -o$OVERGRID -I tempmoba_R_INIT -t tempmoba_traj tempmoba_kdat ${TE} tempmoba_R_F${F}

	done

	bart join 10 `seq -s" " -f "tempmoba_R_F%g" 0 $((TMEA-1))` tempmoba_R_M${MODEL_IND}
	bart resize -c 0 $BASERES 1 $BASERES tempmoba_R_M${MODEL_IND} ${R_FILE_IND}

	rm tempmoba_*.{cfl,hdr}

done

# --- joint reconstruction ---
for (( M_IND=1; M_IND<${MODEL_ARRLEN}+1; M_IND++ )); do

	MODEL_IND=${MODEL_ARR[${M_IND}-1]}
	R_FILE_IND=${R_FILE_ARR[${M_IND}-1]}

	../utils/meco_init.sh -m ${MODEL_IND} -o ${OVERGRID} traj_part kdat_part $TE tempmoba_R_INIT

	bart moba -G -m${MODEL_IND} -J -rQ:1 -rS:0 -rW:3:$(bart bitmask 6):1 -rT:$(bart bitmask 10):0:1 -u0.01 -i10 -C100 -R3 -d4 -k --kfilter-2 -g -o$OVERGRID -I tempmoba_R_INIT -t traj_part kdat_part ${TE} tempmoba_R

	bart resize -c 0 $BASERES 1 $BASERES tempmoba_R ${R_FILE_IND}_JST

done

rm tempmoba_*.{cfl,hdr}

cd ..
