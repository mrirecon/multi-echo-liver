#!/bin/bash

FILES="simulation_ROIs"

FILES+=" liver_2D_s1_scan1 liver_2D_s1_scan2 liver_2D_s2_scan1 liver_2D_s2_scan2 liver_2D_s3_scan1 liver_2D_s3_scan2"
FILES+=" liver_3D_BH_scan1 liver_3D_BH_scan2 liver_3D_FB_scan1 liver_3D_FB_scan2 liver_ROIs liver_TE"

FILES+=" phantom_NIST_Cartesian phantom_NIST_Cartesian phantom_NIST_Radial phantom_NIST_Radial phantom_NIST_ROIs"
FILES+=" phantom_WaterFat_Cartesian phantom_WaterFat_Cartesian_Fat phantom_WaterFat_Cartesian_FF phantom_WaterFat_Cartesian_TE phantom_WaterFat_Cartesian_Water"
FILES+=" phantom_WaterFat_Radial phantom_WaterFat_Radial_TE phantom_WaterFat_ROIs"


for name in $FILES ; do

	./load.sh 4359744 $name ./data
done

