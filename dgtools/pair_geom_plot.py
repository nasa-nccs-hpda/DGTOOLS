#! /usr/bin/env python

#David Shean
#dshean@gmail.com
#5/14/15

#Utility to create polar "skyplot" showing stereo baselines 
#Use pair_geom_anlysis.py to generate json from input directories

import os
import sys
import json

import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
import numpy as np

fn = sys.argv[1]

with open(fn, 'r') as f:
    pairlist = json.load(f)

a_list = []
for p in pairlist:
    a = []
    a.extend([p['id1_dict']['az'], p['id1_dict']['el'], p['id1_dict']['offnadir']])
    a.extend([p['id2_dict']['az'], p['id2_dict']['el'], p['id2_dict']['offnadir']])
    a.append(p['conv_ang'])
    a.append(p['id1_dict']['offnadir']+p['id2_dict']['offnadir'])
    a.append(p['error_dict']['Output Sampled Median Error'])
    a.append(p['error_dict']['Output Sampled 16th Percentile Error'])
    a.append(p['error_dict']['Output Sampled 84th Percentile Error'])
    a.extend(p['error_dict']['Translation vector (Proj meters)'])
    a.append(p['error_dict']['Translation vector magnitude (meters)'])
    #a.append(p['trierror_stats'][5])
    #if p['id1_dict']['id'].startswith('103'):
    a_list.append(tuple(a))

#names = ['az1', 'el1', 'offnadir1', 'az2', 'el2', 'offnadir2', 'conv_ang', 'offnadir_sum', 'err_med', 'err_p16', 'err_p84', 'xoff', 'yoff', 'zoff', 'trans_mag', 'trierr_med']
names = ['az1', 'el1', 'offnadir1', 'az2', 'el2', 'offnadir2', 'conv_ang', 'offnadir_sum', 'err_med', 'err_p16', 'err_p84', 'xoff', 'yoff', 'zoff', 'trans_mag']
formats = ['float'] * len(names)
dtype_dict = dict(names=names, formats=formats) 
#a = np.array(a_list).astype('f4')
a = np.array(a_list, dtype=dtype_dict)
#a.dtype.names = names

fig1 = plt.figure()
ax = plt.subplot(111, polar=True)
ax.set_theta_direction(-1)
ax.set_theta_zero_location('N')
ax.grid(True)

#var = a['zoff']
var = a['trans_mag']
label = 'Translation Vector Magnitude (m)'
az = (a['az1'], a['az2'])
az = np.deg2rad(az)
el = 90 - np.array((a['el1'], a['el2']))
#This creates np arrays for each segment (two points, 4 coords)
segments = np.array([az, el]).T
#norm = plt.Normalize(var.min(), var.max())
norm = plt.Normalize(0, 10)
lc = LineCollection(segments, cmap=plt.get_cmap('YlOrRd'), norm=norm)
lc.set_array(var)
lc.set_linewidth(2)
ax.add_collection(lc)
#This sets elevation range
ax.set_rmin(0)
ax.set_rmax(50)
plt.colorbar(lc, orientation='vertical', shrink=0.7, pad=0.07, label=label)
ax.patch.set_facecolor('gray')
out_fn = os.path.splitext(fn)[0]+'polar.pdf'
#plt.savefig(out_fn)
plt.show()

sys.exit()

fig1 = plt.figure(1)
plt.plot(pair['conv_ang'], med, 'o')
plt.figure(1)
plt.xlabel('Convergence Angle (deg)')
plt.ylabel('Triangulation Error (m)')
plt.savefig('test.pdf')
