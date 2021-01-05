#!/bin/bash
# Copyright 2020. Uecker Lab, University Medical Center Goettingen.
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# 
# Authors:
# 2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
# 
# This script is used to create results 
# for Figure stack-of-stars multi-echo liver acquisition
# 

set -e

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


# # --- prepare raw k-space data ---

../utils/meco_prep.sh -c 10 -e $NECO $RAW kdat_prep


# --- compute trajectory ---

NSMP=$(bart show -d  1 kdat_prep)
FSMP=$((NSMP))
NSPK=$(bart show -d  2 kdat_prep)
NMEA=$(bart show -d 10 kdat_prep)

BASERES=$(( FSMP / 2 ))
OVERGRID=1.5

../utils/meco_traj.sh -F $FSMP -s 2 kdat_prep traj_prep GDC


# # --- SSA-FARY ---

../utils/meco_ssafary.sh -F $FSMP -w 9 traj_prep kdat_prep traj_ssa kdat_ssa EOF SV





# --- moba reconstuction ---

MODEL_IND=1
MODEL="WFR2S"

R_FILE="R_WFR2S_3D_FB"

NBIN=$(bart show -d 10 kdat_ssa)
NPAR=$(bart show -d 13 kdat_ssa)

# --- compute init ---
# --- apply temporal regularization along partitions ---
for (( B=0; B<${NBIN}; B++ )); do

	bart slice 10 $B traj_ssa temp_traj_b
	bart slice 10 $B kdat_ssa temp_kdat_b

	bart extract 5 0 3 $TE temp_TE_e
	bart extract 5 0 3 temp_traj_b temp_traj_be
	bart extract 5 0 3 temp_kdat_b temp_kdat_be

	bart transpose 10 13 temp_traj_be temp_traj_bet
	bart transpose 10 13 temp_kdat_be temp_kdat_bet

	../utils/meco_init.sh -m ${MODEL_IND} -o ${OVERGRID} -T temp_traj_bet temp_kdat_bet temp_TE_e temp_init

	bart transpose 10 13 temp_init temp_init_B${B}

done

bart join 10 `seq -s" " -f "temp_init_B%g" 0 $((NBIN-1))` R_INIT_M${MODEL_IND}

rm temp_*.{cfl,hdr}


# --- joint reconstruction ---
for (( P=0; P<${NPAR}; P++ )); do

	bart slice 13 $P traj_ssa temp_traj_p
	bart slice 13 $P kdat_ssa temp_kdat_p

	bart slice 13 $P R_INIT_M${MODEL_IND} temp_init_p

	bart moba -G -m${MODEL_IND} -J -rQ:1 -rS:0 -rW:3:$(bart bitmask 6):1 -rT:$(bart bitmask 10):0:1 -u0.01 -i10 -C100 -R3 -d4 -g -k --kfilter-2 -o$OVERGRID -I temp_init_p -t temp_traj_p temp_kdat_p ${TE} R_M${MODEL_IND}_P${P}
done

bart join 13 `seq -s" " -f "R_M${MODEL_IND}_P%g" 0 $((NPAR-1))` R_M${MODEL_IND}
bart resize -c 0 $BASERES 1 $BASERES R_M${MODEL_IND} ${R_FILE}

rm R_M*.{cfl,hdr} temp_*.{cfl,hdr}

cd ..
