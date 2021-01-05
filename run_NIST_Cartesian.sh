#!/bin/bash
# Copyright 2020. Uecker Lab, University Medical Center Goettingen.
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# 
# Authors:
# 2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
# 
# This script is used to create results for Figure NIST PHANTOM
# 

set -e

export PATH=$TOOLBOX_PATH:$PATH

if [ ! -e $TOOLBOX_PATH/bart ] ; then
	echo "\$TOOLBOX_PATH is not set correctly!" >&2
	exit 1
fi

which bart


# --- data source ---

RAW=$(readlink -f ./data/phantom_NIST_Cartesian)
TE=$(readlink -f ./data/phantom_NIST_Cartesian_TE)

NECO=$(bart show -d  5 $TE)

mkdir -p phantom_NIST_Cartesian && cd "$_"


# --- prepare raw k-space data ---

../utils/meco_cart_prep.sh -c 10 -B $RAW kdat_prep

# --- estimate coil-sensitivity maps ---

bart slice 5 0 kdat_prep temp_kdat

bart ecalib -m1 temp_kdat sens_prep

rm temp_kdat*.{cfl,hdr}

# --- compute coil-combined echo images ---

bart fft -u -i 3 kdat_prep tempcart_coilimg

bart fmac -C -s 8 tempcart_coilimg sens_prep tempcart_img

IMX=$(bart show -d 0 tempcart_img)
IMY=$(bart show -d 1 tempcart_img)

# --- use magnitude images ---
bart cabs tempcart_img tempcart_img_abs
bart resize -c 0 $IMY tempcart_img_abs tempcart_yx
bart transpose 0 1 tempcart_yx echo_images

# --- mobafit ---
bart mobafit -G -m3 $TE echo_images mobafit_R

# --- extract maps ---
bart slice 6 0 mobafit_R rho

bart slice 6 1 mobafit_R tempcart_R2S
bart scale 1000 tempcart_R2S R2S # (1/s)

bart slice 6 2 mobafit_R tempcart_fB0
bart scale 1000 tempcart_fB0 fB0 # (Hz)

rm tempcart_*.{cfl,hdr}

cd ..
