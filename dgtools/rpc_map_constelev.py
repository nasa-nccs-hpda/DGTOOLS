#! /usr/bin/env python

#David Shean
#dshean@gmail.com
#5/3/13

#This utility will take in two L1B DigitalGlobe images and create products similar to L2 Ortho Ready products
#A median elevation value is computed from an input low-resolution DEM
#A 1-pixel DEM with the image extent union is created with constant elevation
#This can then be fed to rpc_mapproject and stereo_tri

#To do:
#Create funciton to process each image, do the interseciton code in main
#Make rpcdem input optional, otherwise use DG height offset
#Update xml files so they are consistent with DG Ortho Ready products 

import os
import sys
import subprocess

import numpy as np
from osgeo import gdal

from dgtools.lib import dglib
from pygeotools.lib import geolib
from pygeotools.lib import warplib
from pygeotools.lib import iolib
from pygeotools.lib import malib

#Input images
img1 = sys.argv[1]
img2 = sys.argv[2]
#Get xml
xml1 = dglib.getxml(img1)
xml2 = dglib.getxml(img2)
#Input rpcdem
rpcdem_fn = sys.argv[3]
rpcdem_ds = gdal.Open(rpcdem_fn)
rpcdem_b = rpcdem_ds.GetRasterBand(1)
rpcdem_srs = geolib.get_ds_srs(rpcdem_ds)
#Extract geom
geom1 = dglib.xml2geom(xml1)
geom2 = dglib.xml2geom(xml2)
#Compute intersect geom in rpcdem srs coord
igeom = geom1.Intersection(geom2)
igeom.TransformTo(rpcdem_srs)
igeom_env = igeom.GetEnvelope()
#xmin, ymin, xmax, ymax
igeom_extent = [igeom_env[0], igeom_env[2], igeom_env[1], igeom_env[3]]
#Compute union geom
ugeom = geom1.Union(geom2)
ugeom.TransformTo(rpcdem_srs)
ugeom_env = igeom.GetEnvelope()
ugeom_extent = [ugeom_env[0], ugeom_env[2], ugeom_env[1], ugeom_env[3]]
#Since this is just one big pixel, it doesn't cost us anything to wildly increase dimensions
ugeom_extent = geolib.pad_extent(ugeom_extent, 0.5, uniform=True)
#Clip rcpdem to intersection
rpcdem_clip = warplib.memwarp(rpcdem_ds, extent=igeom_extent)
rpcdem_clip_ma = iolib.ds_getma(rpcdem_clip)
#Compute stats for intersection
stats = malib.print_stats(rpcdem_clip_ma)
#Use median elevation
dst_z = stats[5]
#Could also set this from xml file
#dst_z = dglib.getTag(xml1, 'HEIGHTOFFSET')

#Create new 1-pixel tif w/ correct value for union extent
#memdrv = gdal.GetDriverByName('MEM')
#dst_ds = memdrv.Create('', 1, 1, 1, rpcdem_b.DataType) 

#This provides a small grid of constant elevation values for a specified resolution
#May need this for cubic interpolation in rpc_mapproject
if False:
    #This is dx, dy
    gt_res = [500.0, 500.0]
    #This is ydim, xdim
    shape = (int(np.ceil((ugeom_extent[3]-ugeom_extent[1])/gt_res[1])), int(np.ceil((ugeom_extent[2]-ugeom_extent[0])/gt_res[0]))) 
#This creates a single large pixel
else:
    shape = (1,1)
    gt_res = [(ugeom_extent[2]-ugeom_extent[0])/shape[0], (ugeom_extent[3]-ugeom_extent[1])/shape[1]]

#Create the output grid and populate with constant values
dst_npa = np.zeros(shape)
dst_npa[:] = dst_z

#Write out
gtifdrv = gdal.GetDriverByName('GTiff')
dst_fn = os.path.splitext(rpcdem_fn)[0]+'_med%0.0fm.tif' % dst_z 
#This is xdim, ydim
dst_ds = gtifdrv.Create(dst_fn, shape[1], shape[0], 1, rpcdem_b.DataType) 
dst_gt = [ugeom_extent[0], gt_res[0], 0, ugeom_extent[3], 0, -gt_res[1]]
dst_ds.SetGeoTransform(dst_gt)
dst_ds.SetProjection(rpcdem_srs.ExportToWkt())
dst_ds.GetRasterBand(1).WriteArray(dst_npa)
dst_ds = None

#Now run rpc_mapproject with new constant-elevation DEM
out_res = None
#REMOVE THIS
out_res = 1.0
out_ndv = 0
out_srs = rpcdem_srs
#out_srs = geolib.get_proj(igeom)
out_extent = igeom_extent 
for img, xml in zip([img1, img2], [xml1, xml2]):
    if out_res is None:
        out_res = float(dglib.getTag(xml, 'MEANPRODUCTGSD'))
    out_fn = os.path.splitext(img)[0]+'_med%0.0fm.tif' % dst_z
    #rpc_opt = "--nodata-value %s --t_srs '%s' --tr %s --t_projwin %s" % (out_ndv, out_srs.ExportToProj4(), out_res, ' '.join(map(str, out_extent)))
    rpc_opt = "--nodata-value %s --t_srs '%s' --tr %s" % (out_ndv, out_srs.ExportToProj4(), out_res)
    #Uses the original rpcdem for testing/comparison
    #cmd = 'rpc_mapproject %s %s %s %s %s' % (rpc_opt, rpcdem_fn, img, xml, out_fn) 
    #Use the new constant value DEM
    cmd = 'rpc_mapproject %s %s %s %s %s' % (rpc_opt, dst_fn, img, xml, out_fn) 
    print cmd
    print
    subprocess.call(cmd, shell=True)
    print
