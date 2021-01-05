#!/bin/bash
# Copyright 2020. Uecker Lab, University Medical Center Goettingen.
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# 
# Authors:
# 2020 Nick Scholand <nick.scholand@med.uni-goettingen.de>
# 2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
# 
# This script is used to create results for 
# the Simulated Phantom in Figure 2
# 

set -e

export PATH=$TOOLBOX_PATH:$PATH

if [ ! -e $TOOLBOX_PATH/bart ] ; then
	echo "\$TOOLBOX_PATH is not set correctly!" >&2
	exit 1
fi

which bart

# --- create destination folder ---
mkdir -p simulation && cd "$_"

# --- TE ---
NECO=7

bart index 5 $((NECO+1)) temp_index
bart scale 1.6 temp_index temp_TEp1
bart extract 5 1 $((NECO+1)) temp_TEp1 TE

rm temp_*.{cfl,hdr}

NSMP=400

# --- simulation ---
simu()
{
	NSPK="$1" # INPUT: number of spokes per echo time
	TRAJ="$2" # OUTPUT: trajectory
	KDAT="$3" # OUTPUT: k-space data
	REF="$4"  # OUTPUT: reference values

	# nummerical phantom consists of 11 tubes
	GEOM_BASIS=11

	#Remove water background of phantom?
	RM_WATER_BKGRD=0

	# Create trajectory
	bart traj -x $NSMP -y $NSPK -c -r -E -e $NECO $TRAJ

	# Create geometry basis functions
	bart phantom -T -k -b -t $TRAJ __basis_geom

	# Remove water background?
	bart extract 6 $RM_WATER_BKGRD $GEOM_BASIS _{_,}basis_geom

	# Create simulation basis functions using signal
	bart signal -G -n$NECO -1 3:3:1 -2 1:1:1 _basis_simu_water
	bart signal -G -n$NECO -1 1.2:1.2:1 -2 0.005:0.2:10 _basis_simu_tubes

	bart index 0 10 temp_index
	bart ones 1 10 temp_ones
	bart scale 0.0195 temp_ones temp_incre # (0.2 - 0.005)/10

	bart scale 0.005 temp_ones temp_t2

	bart fmac -A temp_index temp_incre temp_t2

	bart invert temp_t2 temp_r2
	
	bart transpose 0 2 temp_r2 $REF


	bart reshape $(bart bitmask 6 7) 10 1 _basis_simu_{,sdim_}tubes
	# Simulated phantom consists of 11 basis functions!
	bart join 6 _basis_simu{_water,_sdim_tubes,}

	# Remove water background?
	bart extract 6 $RM_WATER_BKGRD $GEOM_BASIS _basis_simu{,2}

	# create simulated dataset
	bart fmac -s $(bart bitmask 6) _basis_geom _basis_simu2 $KDAT

	rm _*basis*.{cfl,hdr} temp_*.{cfl,hdr}
}

{

# --- reconstruction ---
for NSPK in 101 33 
do

	echo "> simulation: ${NSPK} spokes per echo"

	simu $NSPK traj_s${NSPK} kdat_s${NSPK} REF_spoke${NSPK}

	echo "> add noise"
	bart noise -s 1. -n 0.00000001 kdat_s${NSPK} kdat_s${NSPK}_n

	echo "> model-based R2* mapping"
	bart moba -G -m3 -rQ:1 -rW:3:$(bart bitmask 6):1 -rS:0 -u0.00001 -i15 -C400 -R3 -d4 -g -o1.5 -t traj_s${NSPK} kdat_s${NSPK}_n TE R_M3_s${NSPK}_n

	IMX=$(bart show -d 0 R_M3_s${NSPK}_n)
	IMY=$(bart show -d 1 R_M3_s${NSPK}_n)

	bart resize -c 0 $((IMX/2)) 1 $((IMY/2)) R_M3_s${NSPK}_n R_M3_s${NSPK}_n_crop

	bart slice 6 0 R_M3_s${NSPK}_n_crop rho_spoke${NSPK}
	bart slice 6 1 R_M3_s${NSPK}_n_crop R2S_spoke${NSPK}
	bart slice 6 2 R_M3_s${NSPK}_n_crop fB0_spoke${NSPK}

	rm R_M3_*.{cfl,hdr} kdat_s*.{cfl,hdr} traj_s*.{cfl,hdr}

done

rm TE.{cfl,hdr}

} > simulation_log.txt

# --- roi analysis for reproducible and quantitative test ---

for NSPK in 101 33 
do 

	echo "comparison between reference values and reconstruction with ${NSPK}-spoke simulation: "

	bart roistat -M ../data/simulation_ROIs R2S_spoke${NSPK} R2S_spoke${NSPK}_ROI_avg

	bart roistat -b -D ../data/simulation_ROIs R2S_spoke${NSPK} R2S_spoke${NSPK}_ROI_std

	bart nrmse REF_spoke${NSPK} R2S_spoke${NSPK}_ROI_avg

done

cd ..

