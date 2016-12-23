#! /usr/bin/env python

#David Shean
#dshean@gmail.com
#11/7/13

#Utility to fill ASP output DEM and regenerate orthoimage

#want to take --threads as argument

import os
import sys
import subprocess
from multiprocessing import cpu_count

from osgeo import gdal

from dgtools.lib import dglib
from pygeotools.lib import geolib

#Input images
img_fn = sys.argv[1]
#Get xml
xml_fn = dglib.getxml(img_fn)
#Extract geom
img_geom = dglib.xml2geom(xml_fn)
img_res = dglib.getTag(xml_fn, 'MEANPRODUCTGSD')
#Some earlier images only have collected
if img_res is None:
    img_res = dglib.getTag(xml_fn, 'MEANCOLLECTEDGSD')
img_res = round(float(img_res), 2)

#Input rpcdem
rpcdem_fn = sys.argv[2]
rpcdem_ds = gdal.Open(rpcdem_fn)
rpcdem_srs = geolib.get_ds_srs(rpcdem_ds)
#Original DEM geom
rpcdem_geom = geolib.ds_geom(rpcdem_ds)

#Might want to clip rpcdem to image extent
fill = True 
inpaint = False
if fill:
    if inpaint:
        import inpaint_dem
        print "Filling input DEM with inpainting method"
        rpcdem_fill_fn = os.path.splitext(rpcdem_fn)[0]+'_inpaint.tif'
        if not os.path.exists(rpcdem_fill_fn):
            inpaint_dem.inpaint_fn(rpcdem_fn)
        rpcdem_fill_ds = gdal.Open(rpcdem_fill_fn) 
    else:
        import dem_downsample_fill
        print "Filling input DEM with gdalfill"
        #Note - need to be more careful about BIG holes here - they won't be filled, but mapproject should handle
        rpcdem_fill_fn = os.path.splitext(rpcdem_fn)[0]+'_fill.tif'
        if not os.path.exists(rpcdem_fill_fn):
            rpcdem_fill_ds = dem_downsample_fill.gdalfill_ds(rpcdem_ds)
            dem_downsample_fill.writeout(rpcdem_fill_fn, rpcdem_fill_ds)
        else:
            rpcdem_fill_ds = gdal.Open(rpcdem_fill_fn)
    rpcdem_fn = rpcdem_fill_fn
    rpcdem_ds = rpcdem_fill_ds

#Smooth DEM?
smooth = False 
if smooth:
    from lib import iolib
from lib import malib
    from lib import filtlib 
    rpcdem_b = iolib.ds_getma(rpcdem_ds)
    rpcdem_b_fltr = filtlib.gauss_fltr_astropy(rpcdem_b)
    rpcdem_fltr_fn = os.path.splitext(rpcdem_fn)[0]+'_smooth.tif'
    iolib.writeGTiff(rpcdem_b_fltr, rpcdem_fltr_fn, rpcdem_fill_ds) 
    rpcdem_fn = rpcdem_fltr_fn

#Do this in inpaint_dem
erode = False 
if erode:
    from lib import iolib
from lib import malib
    in_ma = iolib.ds_getma(rpcdem_ds)
    out_ma = malib.mask_islands(in_ma)
    out_fn = os.path.splitext(rpcdem_fn)[0]+'_erode.tif'
    iolib.writeGTiff(out_ma, out_fn, rpcdem_ds)
    rpcdem_fn = out_fn 

rpcdem_ds = None

#Compute intersection geom for output extent
img_geom.TransformTo(rpcdem_srs)
igeom = rpcdem_geom.Intersection(img_geom)
igeom_env = igeom.GetEnvelope()
#xmin, ymin, xmax, ymax
out_extent = [igeom_env[0], igeom_env[2], igeom_env[1], igeom_env[3]]

"""
print
print img_geom
print rpcdem_geom
print out_extent
print
"""

#Now run mapproject with filled DEM
model = "rpc"
#model = "dg"
out_res = None 
#out_res = 0.5 
#out_res = 1.0
if img_res:
   out_res = img_res 
out_ndv = 0
out_srs = rpcdem_srs

map_opt = []
map_opt += ["--threads", cpu_count()]
map_opt += ["-t", model]
map_opt += ["--nodata-value", out_ndv]
map_opt += ["--t_srs", '%s' % out_srs.ExportToProj4()]
map_opt += ["--t_projwin"] + out_extent

if out_res is not None:
    map_opt += ["--tr", out_res]
    #out_fn = os.path.splitext(img_fn)[0]+'_ortho_%0.1fm_fill.tif' % out_res
    out_fn = img_fn.split(os.extsep)[0]+'_ortho_%0.2fm_fill.tif' % out_res
else:
    out_fn = img_fn.split(os.extsep)[0]+'_ortho_fill.tif'

#Add the mode
out_fn = os.path.splitext(out_fn)[0]+'_%s.tif' % model

map_arg = [rpcdem_fn, img_fn, xml_fn, out_fn]

#Combine options and argument lists to build command
cmd = ["mapproject",] + map_opt + map_arg 

#rpc_opt = "--threads 32 -t %s --nodata-value %s --t_srs '%s' --tr %f --t_projwin %s" % (model, out_ndv, out_srs.ExportToProj4(), out_res, ' '.join(map(str, out_extent)))
#cmd = 'mapproject %s %s %s %s %s' % (rpc_opt, rpcdem_fn, img_fn, xml_fn, out_fn) 
#subprocess.call(cmd, shell=True)

#Convert all arguments to str
cmd = [str(i) for i in cmd]

print
print ' '.join(cmd)
print
subprocess.call(cmd, shell=False)
print

#Now convert to 8 bit and generate overviews
#gdal_opt="-co TILED=YES -co COMPRESS=LZW -co BIGTIFF=YES"
#gdal_opt="$gdal_opt -co BLOCKXSIZE=256 -co BLOCKYSIZE=256"
#gdal_translate $gdal_opt -ot Byte -scale $drg_dnscale 1 255 -a_nodata 0 ${out}-DRG.tif ${out}-DRG_8b.tif
#gdaladdo_lzw.py ${out}-DRG_8b.tif
