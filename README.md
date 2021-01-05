# Summary

These scripts reproduce the experiments described in the article:

**Free-Breathing Water, Fat, $R_2^*$ and $B_0$ Field Mapping of the Liver Using Multi-Echo Radial FLASH and Regularized Model-based Reconstruction (MERLOT)**

The algorithms have been integrated into the Berkeley Advanced Reconstruction Toolbox (BART) [1]
(commit a28c18a)


# The raw files are hosted on ZENODO
## How to download

- Download manually: https://zenodo.org/record/4359744

- Download via bash script: 

	- All files: `bash load-all.sh`
	- Individual file: `bash load.sh 4359744 <FILENAME> <dstdir>` (please refer to md5sum.txt for FILENAME)

## Explanation of directory and raw files

	.
	├── ### Figure 2 ###
	├── simulation_ROIs.[hdr,cfl]                  # 10 regions of interst
	├── ### Figure 3 ###
	├── phantom_NIST_Cartesian.[hdr,cfl]           # k-space data
	├── phantom_NIST_Cartesian_TE.[hdr,cfl]        # TE array
	├── phantom_NIST_Radial.[hdr,cfl]              # k-space data
	├── phantom_NIST_Radial_TE.[hdr,cfl]           # TE_array
	├── phantom_NIST_ROIs.[hdr,cfl]                # 7 ROIs
	├── ### Figure 4 ###
	├── phantom_WaterFat_Cartesian.[hdr,cfl]       # k-space data
	├── phantom_WaterFat_Cartesian_TE.[hdr,cfl]    # TE array
	├── phantom_WaterFat_Cartesian_Water.[hdr,cfl] # Water
	├── phantom_WaterFat_Cartesian_Fat.[hdr,cfl]   # Fat
	├── phantom_WaterFat_Cartesian_FF.[hdr,cfl]    # Fat fraction
	├── phantom_WaterFat_Radial.[hdr,cfl]          # k-space data
	├── phantom_WaterFat_Radial_TE.[hdr,cfl]       # TE array
	├── phantom_WaterFat_ROIs.[hdr,cfl]            # 4 ROIs
	├── ### Figures 5, 6 ###
	├── liver_2D_s3_scan2.[hdr,cfl]                # k-space data
	├── liver_2D_s1_scan1.[hdr,cfl]
	├── liver_2D_s2_scan1.[hdr,cfl]
	├── liver_2D_s3_scan1.[hdr,cfl]
	├── ### Figures 7 ###
	├── liver_3D_BH_scan1.[hdr,cfl]
	├── liver_3D_BH_scan2.[hdr,cfl]
	├── ### Figures 8 ###
	├── liver_3D_FB_scan1.[hdr,cfl]
	├── liver_3D_FB_scan2.[hdr,cfl]
	├── liver_TE.[hdr,cfl]                         # TE array
	└── liver_ROIs.[hdr,cfl]                       # 3 ROIs
# The bash scritps used for reconstructions and quantitative analysis

After downloading the raw data, you can run the following bash scripts.

### Simulation:

`bash run_simulation.sh` performs:
1. numerical simulation;
2. model-based reconstruction for $R_2^\star$ mapping;
3. comparison of the reconstructed $R_2^\star$ values with the reference values based on the ROI files stored in `simulation/simulation_ROIs.[cfl,hdr]`.

### Phantom NIST:

`bash run_NIST_Cartesian.sh` performs:

1. polarity correction of MGRE Cartesian k-space data;
2. coil combination via ESPIRiT;
3. pixel-wise mobafit.

`bash run_NIST_Radial.sh` performs:

1. preparation of multi-echo radial FLASH data;
2. calculation of multi-echo radial sampling trajectory;
3. moba reconstruction for quantitative R2* mapping.

### Phantom WaterFat:
`bash run_WaterFat_Radial.sh` performs:

1. preparation of multi-echo radial FLASH data;
2. calculation of multi-echo radial sampling trajectory;
3. moba reconstruction for water/fat separation and R2* mapping.

### Liver:

`bash run_liver_all.sh` runs all liver data (2D and 3D).

`bash run_liver_table.sh` runs after the reconstruction of all liver data, and computes the mean and standard deviation given the ROIs.

### Note:
For the preparation of figures in the article, `plots.py` is used to export png files from all the above reconstructed files.


If you need further help to run the scripts, we are happy to help you: zhengguo.tan@med.uni-goettingen.de and martin.uecker@med.uni-goettingen.de.


[1]. https://mrirecon.github.io/bart
