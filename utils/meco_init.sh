#!/bin/bash
# Copyright 2020. Uecker Lab, University Medical Center Goettingen.
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# 
# Authors:
# 2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
# 
# This script is used to compute initialization 
# for moba mgre reconstructions. 
# 

set -e

export PATH=$TOOLBOX_PATH:$PATH

if [ ! -e $TOOLBOX_PATH/bart ] ; then
	echo "\$TOOLBOX_PATH is not set correctly!" >&2
	exit 1
fi

helpstr=$(cat <<- EOF
initialization for moba reconstruction
-m meco model [enum: WF = 0, WFR2S, WF2R2S, R2S, PHASEDIFF]
-o over-grid factor [default: 1.5]
-T use temporal regularization
-h help
EOF
)

MODEL=1
OVERGRID=$(echo "scale=2; 3/2" | bc)
TEMPREG=0
REGSTR="-i6 -R2"
# REGSTR="-rT:3:64:1 -rQ:1 -u0.01 -i8 -C100 -R2 -b0:1"

usage="Usage: $0 [-h] [-m MODEL] [-o OVERGRID] [-s REGSTR] [-T] <input traj> <input kdat> <input TE> <output init>"

while getopts "hm:o:s:T" opt; do
	case $opt in
	h) 
		echo "$usage"
		echo "$helpstr"
		exit 0 
		;;
	m)
		MODEL=${OPTARG}
		;;
	o)
		OVERGRID=${OPTARG}
		;;
	s)
		REGSTR=${OPTARG}
		;;
	T)
		TEMPREG=1
		;;
	\?)
		echo "$usage" >&2
		exit 1
		;;
	esac
done

shift $(($OPTIND -1 ))

TRAJ=$(readlink -f "$1") # INPUT trajectory
KDAT=$(readlink -f "$2") # INPUT k-space data
TE=$(readlink -f "$3")   # INPUT TE
INIT=$(readlink -f "$4") # OUTPUT init

NMEA=$(bart show -d 10 $KDAT)

bart extract 5 0 3 $TRAJ tempinit_traj_e
bart extract 5 0 3 $KDAT tempinit_kdat_e
bart extract 5 0 3 $TE tempinit_TE_e

# --- regularization option ---
echo " reconstruction option: $REGSTR"

# --- reconstruction ---
if [ $TEMPREG -eq 1 ]; then

	bart moba -O -G -m0 ${REGSTR} -g -o$OVERGRID -t tempinit_traj_e tempinit_kdat_e tempinit_TE_e tempinit_R_m0_e

elif [ $TEMPREG -eq 0 ]; then

	for (( M=0; M<$NMEA; M++ )); do

		bart slice 10 $M tempinit_traj_e tempinit_traj_ef
		bart slice 10 $M tempinit_kdat_e tempinit_kdat_ef

		bart moba -O -G -m0 ${REGSTR} -g -o$OVERGRID -t tempinit_traj_ef tempinit_kdat_ef tempinit_TE_e tempinit_R_m0_e_M${M}
	done

	bart join 10 `seq -s" " -f "tempinit_R_m0_e_M%g" 0 $(( $NMEA - 1 ))` tempinit_R_m0_e

fi

# --- format data as init file ---
bart slice 6 0 tempinit_R_m0_e tempinit_W
bart slice 6 1 tempinit_R_m0_e tempinit_F
bart slice 6 2 tempinit_R_m0_e tempinit_fB0

IMX=$(bart show -d 0 tempinit_R_m0_e)
IMY=$(bart show -d 1 tempinit_R_m0_e)

bart zeros 16 $IMX $IMY 1 1 1 1 1 1 1 1 $NMEA 1 1 1 1 1 tempinit_0

case $MODEL in
0) # WF
	bart join 6 tempinit_W tempinit_F tempinit_fB0 $INIT
	;;
1) # WFR2S
	bart join 6 tempinit_W tempinit_F tempinit_0 tempinit_fB0 $INIT
	;;
2) # WF2R2S
	bart join 6 tempinit_W tempinit_0 tempinit_F tempinit_0 tempinit_fB0 $INIT
	;;
3) # R2S
	bart join 6 tempinit_W tempinit_0 tempinit_fB0 $INIT
	;;
4) # PHASEDIFF
	bart join 6 tempinit_W tempinit_fB0 $INIT
	;;
*)
	echo "unknown model"
	exit 1
	;;
esac

rm tempinit*.{cfl,hdr}
