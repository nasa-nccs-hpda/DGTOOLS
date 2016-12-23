#! /usr/bin/env python

import sys
import os
import glob

import numpy as np
from osgeo import gdal

from pygeotools.lib import geolib

#This takes output browse images from dg_catalog_htmllist.py
#and creates subdir with ln to candidate stereo

fn_list = np.array(glob.glob('*00_100m.tif'))
fn_list.sort()

dt_list = np.array([i[0:13] for i in fn_list])

min_area = 150
min_width = 11

outdir = 'stereo'
if not os.path.exists(outdir):
    os.makedirs(outdir)

for n,fn in enumerate(fn_list):
    dt = fn[0:13]
    dt_idx = np.array((dt_list[n+1:] == dt)).nonzero()[0]
    if dt_idx.size:
        ds1 = gdal.Open(fn)
        geom1 = geolib.get_outline(ds1)
        for fn2 in fn_list[n+1+dt_idx]:
            ds2 = gdal.Open(fn2)
            geom2 = geolib.get_outline(ds2)
            if geom1.Intersects(geom2):
                intsect = geom1.Intersection(geom2)
                area = intsect.GetArea()/1E6
                extent = intsect.GetEnvelope()
                width = (extent[1] - extent[0])/1E3
                if area > min_area and width > min_width:
                    print fn, fn2, area
                    #Write out shp
                    #geolib.geom2shp
                    for i in fn, fn2:
                        outln = os.path.join(outdir,i)
                        if os.path.exists(outln):
                            os.remove(outln)
                        os.symlink(os.path.join('..',i), outln) 
