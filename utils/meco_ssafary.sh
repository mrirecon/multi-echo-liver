#!/bin/bash
# Copyright 2020. Uecker Lab, University Medical Center Goettingen.
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# 
# Authors:
# 2019-2020 Sebastian Rosenzweig <sebastian.rosenzweig@med.uni-goettingen.de>
# 2019-2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
# 
# This script is used to perform SSA-FARY on multi-echo data
# 

set -e

export PATH=$TOOLBOX_PATH:$PATH

if [ ! -e $TOOLBOX_PATH/bart ] ; then
	echo "\$TOOLBOX_PATH is not set correctly!" >&2
	exit 1
fi

helpstr=$(cat <<- EOF
prepare raw k-space data
-F full sample (for partial Fourier sampling)
-w window size
-h help
EOF
)

usage="Usage: $0 [-h] [-F FSMP] [-w WINSIZE] <input traj> <input kdat> <output traj> <output kdat> <output EOF> <output SV>"

FSMP=1
WINSIZE=200

while getopts "hF:w:" opt; do
	case $opt in
	h)
		echo "$usage"
		echo "$helpstr"
		exit 0 
		;;
	F)
		FSMP=${OPTARG}
		;;
	w)
		WINSIZE=${OPTARG}
		;;
	\?)
		echo "$usage" >&2
		exit 1
		;;
	esac
done

shift $(($OPTIND -1 ))

TRAJ_I=$(readlink -f "$1")  # INPUT trajectory
KDAT_I=$(readlink -f "$2")  # INPUT k-space data

TRAJ_O=$(readlink -f "$3")  # OUTPUT binned trajectory
KDAT_O=$(readlink -f "$4")  # OUTPUT binned k-space data

EOF=$(readlink -f "$5") # OUTPUT EOF
SV=$(readlink -f "$6")  # OUTPUT SV

# --- dimensions ---

NSMP=$(bart show -d  1 $KDAT_I)
NSPK=$(bart show -d  2 $KDAT_I)
NCOI=$(bart show -d  3 $KDAT_I)
NECO=$(bart show -d  5 $KDAT_I)
NMEA=$(bart show -d 10 $KDAT_I)
NSLI=$(bart show -d 13 $KDAT_I)


# --- group all spokes to time dim ---
bart reshape $(bart bitmask 2 10) 1 $(( NSPK * NMEA )) $TRAJ_I temp_tt
bart reshape $(bart bitmask 2 10) 1 $(( NSPK * NMEA )) $KDAT_I temp_kk

# --- use only the first echo ---
bart slice 5 0 temp_tt temp_tt_e
bart slice 5 0 temp_kk temp_kk_e

# --- extract DC component ---
CTR=$(( $FSMP/2 - ($FSMP - $NSMP) ))
bart extract 1 $CTR $(( $CTR + 1 )) temp_kk_e temp_kk_ec
bart rmfreq temp_tt_e temp_kk_ec temp_kk_ec_rmfreq

bart transpose 2 10 temp_kk_ec_rmfreq temp_kc_smp
bart reshape $(bart bitmask 3 13) $(( NCOI*NSLI )) 1 temp_kc_smp temp_kc

bart squeeze temp_kc temp_ac1
bart scale -- -1i temp_ac1 temp_ac2

bart creal temp_ac1 temp_ac_real
bart creal temp_ac2 temp_ac_imag

bart join 1 temp_ac_real temp_ac_imag temp_ac


# --- SSA-FARY ---
bart ssa -w ${WINSIZE} temp_ac ${EOF} ${SV}


RESPI0=0
RESPI1=1

CARDI0=2
CARDI1=3

bart slice 1 $RESPI0 $EOF temp_EOF_r0
bart slice 1 $RESPI1 $EOF temp_EOF_r1

bart slice 1 $CARDI0 $EOF temp_EOF_c0
bart slice 1 $CARDI1 $EOF temp_EOF_c1

bart join 1 temp_EOF_r{0,1} temp_EOF_c{0,1} temp_tmp0
bart transpose 1 11 temp_tmp0 temp_tmp1
bart transpose 0 10 temp_tmp1 temp_eof

RESPI=7
CARDI=1 # 20

# --- bin ---

MOVAVG=$(( WINSIZE * 3 ))

bart bin -r0:1 -R$RESPI -c2:3 -C$CARDI -a${MOVAVG} temp_eof temp_tt temp_tsg
bart bin -r0:1 -R$RESPI -c2:3 -C$CARDI -a${MOVAVG} temp_eof temp_kk temp_ksg

bart transpose 11 10 temp_tsg $TRAJ_O
bart transpose 11 10 temp_ksg $KDAT_O

rm temp_*.{cfl,hdr}
