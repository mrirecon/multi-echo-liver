#!/bin/bash
# Copyright 2020. Uecker Lab, University Medical Center Goettingen.
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# 
# Authors:
# 2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
# 
# This scripts runs all liver data
# 

set -e

export PATH=$TOOLBOX_PATH:$PATH

if [ ! -e $TOOLBOX_PATH/bart ] ; then
	echo "\$TOOLBOX_PATH is not set correctly!" >&2
	exit 1
fi

which bart

./run_liver_2D_FB.sh liver_2D_s3_scan1

./run_liver_2D_FB.sh liver_2D_s1_scan2
./run_liver_2D_FB.sh liver_2D_s2_scan2
./run_liver_2D_FB.sh liver_2D_s3_scan2

./run_liver_3D_BH.sh liver_3D_BH_scan1
./run_liver_3D_BH.sh liver_3D_BH_scan2

./run_liver_3D_FB.sh liver_3D_FB_scan1
./run_liver_3D_FB.sh liver_3D_FB_scan2
