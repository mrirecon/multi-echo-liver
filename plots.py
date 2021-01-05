#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
# Authors: 
# 2019-2020 Zhengguo Tan <zhengguo.tan@med.uni-goettingen.de>
"""

import matplotlib.cm as cm
import matplotlib.pyplot as plt
import matplotlib as mpl
mpl.rcParams['savefig.pad_inches'] = 0

import numpy as np
import cfl
import os

# https://github.com/jdoepfert/roipoly.py
from roipoly import RoiPoly

# %% calculate fat fraction from water and fat maps
def wf2frac(W, F, thres):
    
    NX,NY = W.shape
    
    frac = np.zeros(shape=(NX,NY), dtype="float")
    
    Deno = W + F
    
    mask = (Deno > np.amax(Deno) * thres).astype(np.float)
    
    for x in range(0,NX):
        for y in range(0,NY):

            if W[x,y] <= F[x,y]:
                frac[x,y] = np.absolute( float(F[x,y]) ) / np.absolute( float(Deno[x,y]) )
            else:
                frac[x,y] = 1. - np.absolute( float(W[x,y]) ) / np.absolute( float(Deno[x,y]) )
    
    return mask, frac

# %%

def full_frame(width=None, height=None):

    figsize = None if width is None else (width, height)
    fig = plt.figure(figsize=figsize)
    ax = plt.axes([0,0,1,1], frameon=False)
    ax.get_xaxis().set_visible(False)
    ax.get_yaxis().set_visible(False)
    plt.autoscale(tight=True)

# %%
def imshow_img(R, cmap_str, vmin, vmax, roi=None, width=None, height=None):

    full_frame(width,height)

    plt.imshow(R, interpolation='none', cmap=cmap_str, vmin=vmin,vmax=vmax, aspect='auto')
    plt.show()
    
    if roi is not None:
        for n in range(0, len(roi)):
            roi[n].display_roi()

# %%
def save_img(R, cmap_str, vmin, vmax, png_file, width=None, height=None):

    width  = 4 if width is None else width
    height = 4 if height is None else height
    
    full_frame(width,height)

    plt.imshow(R, interpolation='none', cmap=cmap_str, vmin=vmin,vmax=vmax, aspect='auto')

    plt.savefig(png_file, bbox_inches='tight', dpi=100, pad_inches=0)
    plt.close()

# %%
def roi_selection(R2S, roi_color, img_cmap, vmin, vmax):

    # show the R2s of water
    fig = plt.figure(figsize=(16,16))
    plt.imshow(R2S.real, interpolation='nearest', cmap=img_cmap, vmin=vmin,vmax=vmax)
    plt.show(block=False)
    
    # let user draw ROI (right click or double click: close region)
    roi = RoiPoly(color=roi_color, fig=fig)
    
    return roi

# %% 
def save_5D_images(file_name, model):

    R = np.flipud(cfl.readcfl(file_name))
    
    if R.ndim == 14: # 3D acquisition

        if R.shape[10] == 1:
            R = np.squeeze(R)
            NX,NY,NM,NP = R.shape
            R = np.reshape(R,[NX,NY,NM,1,NP])
        else:
            R = np.squeeze(R)

    # 2D
    elif R.ndim == 11:
        R = np.expand_dims(np.squeeze(R), 4)

    elif R.ndim ==  7:
        R = np.expand_dims(np.squeeze(R), axis=(3,4))

    NX,NY,NM,NF,NP = R.shape

    frac = np.zeros(shape=(NX,NY,1,NF,NP), dtype="float")


    for partition in range(0, NP):

        for frame in range(0, NF):

            if 1 == model:
                W = np.absolute(np.squeeze(R[:,:,0,frame,partition]))
                F = np.absolute(np.squeeze(R[:,:,1,frame,partition]))
                R2S = np.real(np.squeeze(R[:,:,2,frame,partition]))
                fB0 = np.real(np.squeeze(R[:,:,3,frame,partition]))
            
            elif 2 == model:
                W = np.absolute(np.squeeze(R[:,:,0,frame,partition]))
                R2S_W = np.real(np.squeeze(R[:,:,1,frame,partition]))
                F = np.absolute(np.squeeze(R[:,:,2,frame,partition]))
                R2S_F = np.real(np.squeeze(R[:,:,3,frame,partition]))
                fB0 = np.real(np.squeeze(R[:,:,4,frame,partition]))

            postfix_str = '_frm' + str(frame) + '_par' + str(partition)

            mask, FF = wf2frac(W, F, 0.08)
            
            frac[:,:,0,frame,partition] = np.multiply(FF, mask)

            if 1 == model:
                save_img(np.multiply(W, mask), 'gray', 0, 1000, file_name + '_W' + postfix_str)
                save_img(np.multiply(F, mask), 'gray', 0, 1000, file_name + '_F' + postfix_str)
                save_img(np.multiply(R2S, mask), 'hot', 0, 300, file_name + '_R2S' + postfix_str)
                save_img(np.multiply(fB0, mask), 'RdBu_r', -200, 200, file_name + '_fB0' + postfix_str)

            elif 2 == model:
                save_img(np.multiply(W, mask), 'gray', 0, 1000, file_name + '_W' + postfix_str)
                save_img(np.multiply(R2S_W, mask), 'hot', 0, 300, file_name + '_R2S_W' + postfix_str)
                save_img(np.multiply(F, mask), 'gray', 0, 1000, file_name + '_F' + postfix_str)
                save_img(np.multiply(R2S_F, mask), 'hot', 0, 300, file_name + '_R2S_F' + postfix_str)
                save_img(np.multiply(fB0, mask), 'RdBu_r', -200, 200, file_name + '_fB0' + postfix_str)

            save_img(np.multiply(FF, mask), 'gray', 0, 1, file_name + '_FF' + postfix_str)

    return R, frac

# %%
def roi_analysis_nist(R1, R2, roi, cmap):

    assert len(roi) == len(cmap)
    
    NX,NY = R1.shape
    
    arr_stp = len(roi)

    val_avg = np.zeros((arr_stp,2))
    val_std = np.zeros((arr_stp,2))

    fig, ax = plt.subplots(figsize=(9,9))
    
    plt.plot([0, 200], [0, 200], color='k',linestyle='-')

    for r in range(0, len(roi)):
        val_avg[r,0], val_std[r,0] = roi[r].get_mean_and_std(R1.real)
        val_avg[r,1], val_std[r,1] = roi[r].get_mean_and_std(R2.real)

        plt.errorbar(val_avg[r,0], val_avg[r,1], 
                     xerr=val_std[r,0], yerr=val_std[r,1], 
                     fmt='o', markersize=6, color=cmap[r], capsize=8, 
                     linestyle='')

    plt.grid(color='lightgrey', linestyle='--', linewidth=4)
    plt.xlabel('Reference $R_2^*$ (1/s)', fontsize=16)
    plt.ylabel('MERLOT $R_2^*$ (1/s)', fontsize=16)

    plt.xticks(val_avg[:,0], rotation=60)
    plt.xlim((0,200))

    plt.yticks(val_avg[:,1])
    plt.ylim((0,200))
        
    ax.tick_params(axis='x', labelsize=12)
    ax.tick_params(axis='y', labelsize=12)
        
    plt.show()

# %%
def roi_analysis_wfphan(R1, R2, roi, cmap):

    assert len(roi) == len(cmap)
    
    NX,NY = R1.shape
    
    arr_stp = len(roi)

    val_avg = np.zeros((arr_stp,2))
    val_std = np.zeros((arr_stp,2))

    fig, ax = plt.subplots(figsize=(9,9))
    
    plt.plot([0, 100], [0, 100], color='k',linestyle='-')

    for r in range(0, len(roi)):
        val_avg[r,0], val_std[r,0] = roi[r].get_mean_and_std(R1.real)
        val_avg[r,1], val_std[r,1] = roi[r].get_mean_and_std(R2.real)

        plt.errorbar(val_avg[r,0], val_avg[r,1], 
                     xerr=val_std[r,0], yerr=val_std[r,1], 
                     fmt='o', markersize=6, color=cmap[r], capsize=8, 
                     linestyle='')

    plt.grid(color='lightgrey', linestyle='--', linewidth=4)
    plt.xlabel('Reference fat fraction (%)', fontsize=16)
    plt.ylabel('MERLOT fat fraction (%)', fontsize=16)

    plt.xticks(val_avg[:,0], rotation=60)
    plt.xlim((0,100))

    plt.yticks(val_avg[:,1])
    plt.ylim((0,100))
        
    ax.tick_params(axis='x', labelsize=12)
    ax.tick_params(axis='y', labelsize=12)
        
    plt.show()

# %%
def roi_analysis_liver(R, roi, cmap):
    
    assert len(roi) == len(cmap)
    
    NX,NY,NITER = R.shape
    
    arr_stp = np.arange(NITER) + 1

    val_avg = np.zeros((NITER,2))
    val_std = np.zeros((NITER,2))

    fig, ax = plt.subplots(figsize=(15,7))

    for r in range(0, len(roi)):
        
        for n in range(0, NITER):
            
            R_curr = R[:,:,n]
            
            val_avg[n,0], val_std[n,0] = roi[r].get_mean_and_std(R_curr.real)
        
        plt.errorbar(arr_stp, val_avg[:,0], val_std[:,0], 
                     marker='o', markersize=12, color=cmap[r], 
                     linestyle='dotted', label='ROI'+str(r+1))
    
        plt.grid(color='lightgrey', linestyle='--', linewidth=4)
        plt.xlabel('Iteration', fontsize=24)
        # plt.ylabel('$R_2^*$ (1/s)', fontsize=24)
        plt.ylabel('Fat Fraction (%)', fontsize=24)
    
        plt.xticks(np.arange(1, NITER+1, step=2))
        plt.xlim((0,NITER+1))

        plt.ylim((0,100))
        
        ax.legend(fontsize=24)
        
        ax.tick_params(axis='x', labelsize=24)
        ax.tick_params(axis='y', labelsize=24)
        
        plt.show()


# %% --- 1 ---
orig_dir = os.getcwd()

# %% --- 2.0 --- Water/Fat Phantom

os.chdir(orig_dir)
os.chdir('scripts/')

R_WaterFat_Radial = np.squeeze(cfl.readcfl('phantom_WaterFat_Radial/moba_R'))

W = np.absolute(np.squeeze(R_WaterFat_Radial[:,:,0]))
F = np.absolute(np.squeeze(R_WaterFat_Radial[:,:,2]))

FF_WaterFat_Radial = np.squeeze(cfl.readcfl('phantom_WaterFat_Radial/FF'))

os.chdir('../reprod/phantom_WaterFat_Radial/')

save_img(W, 'gray', 0, 300, 'Water_Radial')
save_img(F, 'gray', 0, 300, 'Fat_Radial')
save_img(np.absolute(FF_WaterFat_Radial), 'gray', 0, 100, 'FF_Radial')



os.chdir(orig_dir)
os.chdir('scripts/')

W_WaterFat_Cartesian = np.squeeze(cfl.readcfl('phantom_WaterFat_Cartesian_Water'))
F_WaterFat_Cartesian = np.squeeze(cfl.readcfl('phantom_WaterFat_Cartesian_Fat'))

FF_WaterFat_Cartesian = np.squeeze(cfl.readcfl('phantom_WaterFat_Cartesian_FF'))

os.chdir('../reprod/phantom_WaterFat_Radial/')

save_img(np.absolute(W_WaterFat_Cartesian), 'gray', 0, 0.0008, 'Water_Cartesian')
save_img(np.absolute(F_WaterFat_Cartesian), 'gray', 0, 0.0008, 'Fat_Cartesian')
save_img(np.absolute(FF_WaterFat_Cartesian), 'gray', 0, 100, 'FF_Cartesian')



# roi_analysis_wfphan(FF_WaterFat_Cartesian, FF_WaterFat_Radial, roi_WaterFat, cmap)


os.chdir(orig_dir)





# %% --- 2.1 --- 2D FB VOL2 SLI1

os.chdir(orig_dir)
os.chdir('scripts/liver_2D_s3_scan1/')

R_WFR2S_RT_SLI3_SCAN1, FF_SLI3_SCAN1 = save_5D_images('R_WFR2S_RT', 1)

R_WF2R2S_RT_SLI3_SCAN1, FF2_SLI3_SCAN1 = save_5D_images('R_WF2R2S_RT', 2)

os.chdir(orig_dir)



os.chdir('scripts/liver_2D_s1_scan2/')

R_WFR2S_RT_SLI1_SCAN2, FF_SLI1_SCAN2 = save_5D_images('R_WFR2S_RT', 1)

R_WF2R2S_RT_SLI1_SCAN2, FF2_SLI1_SCAN2 = save_5D_images('R_WF2R2S_RT', 2)

R_WFR2S_JST_SLI1_SCAN2, FF_JST_SLI1_SCAN2 = save_5D_images('R_WFR2S_RT_JST', 1)

os.chdir(orig_dir)



os.chdir('scripts/liver_2D_s2_scan2/')

R_WFR2S_RT_SLI2_SCAN2, FF_SLI2_SCAN2 = save_5D_images('R_WFR2S_RT', 1)

os.chdir(orig_dir)

os.chdir('scripts/liver_2D_s3_scan2/')

R_WFR2S_RT_SLI3_SCAN2, FF_SLI3_SCAN2 = save_5D_images('R_WFR2S_RT', 1)

os.chdir(orig_dir)

# %% --- 2.2 --- 2D FB VOL2 SLI1 compare filters

os.chdir(orig_dir)
os.chdir('scripts/liver_2D_s1_scan2_filter_off/')

R_WFR2S_RT_SLI1_SCAN2_off, FF_SLI1_SCAN2_off = save_5D_images('R_WFR2S_RT', 1)

os.chdir(orig_dir)

os.chdir('scripts/liver_2D_s1_scan2_filter_ori/')

R_WFR2S_RT_SLI1_SCAN2_ori, FF_SLI1_SCAN2_ori = save_5D_images('R_WFR2S_RT', 1)

os.chdir(orig_dir)

os.chdir('scripts/liver_2D_s1_scan2_filter_new/')

R_WFR2S_RT_SLI1_SCAN2_new, FF_SLI1_SCAN2_new = save_5D_images('R_WFR2S_RT', 1)

os.chdir(orig_dir)



# %% --- 3 --- 3D BH (Stack-of-Stars Breath Holding)

os.chdir(orig_dir)
os.chdir('scripts/liver_3D_BH_scan2/')

R_WFR2S_3D_BH_SCAN2, FF_3D_BH_SCAN2 = save_5D_images('R_WFR2S_3D_BH', 1)

os.chdir(orig_dir)

os.chdir('scripts/liver_3D_BH_scan1/')

R_WFR2S_3D_BH_SCAN1, FF_3D_BH_SCAN1 = save_5D_images('R_WFR2S_3D_BH', 1)

os.chdir(orig_dir)

# %% --- 4 --- 3D FB 

os.chdir(orig_dir)
os.chdir('scripts/liver_3D_FB_scan2/')

R_WFR2S_3D_FB_SCAN2, FF_3D_FB_SCAN2 = save_5D_images('R_WFR2S_3D_FB', 1)

os.chdir(orig_dir)


os.chdir('scripts/liver_3D_FB_scan1/')

R_WFR2S_3D_FB_SCAN1, FF_3D_FB_SCAN1 = save_5D_images('R_WFR2S_3D_FB', 1)

os.chdir(orig_dir)

# %%

os.chdir(orig_dir)
os.chdir('scripts/liver_3D_FB_scan2/')

ind = 114

R_3DFB_ref = np.squeeze(R_WFR2S_3D_FB_SCAN2[ind, :, :, :, :])
R_3DFB_ref = np.transpose(R_3DFB_ref, (3, 0, 1, 2))

NX,NY,NM,NF = R_3DFB_ref.shape

R_3DFB_ref = R_3DFB_ref.reshape(NX,NY,1,1,1,1,NM,1,1,1,NF)

cfl.writecfl('R_WFR2S_3D_FB_reformat_114', R_3DFB_ref)

save_5D_images('R_WFR2S_3D_FB_reformat_114', 1)

