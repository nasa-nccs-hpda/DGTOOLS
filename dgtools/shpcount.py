#! /usr/bin/env python

#David Shean
#5/4/16
#dshean@gmail.com

#Utility to generate raster heatmap from DG footprint shapefile

import sys
import os

from osgeo import gdal, ogr, osr

from pygeotools.lib import geolib
from pygeotools.lib import timelib

if len(sys.argv) != 2:
    sys.exit('Usage is shpcount.py in.shp')

shp_fn = sys.argv[1]

if not os.path.exists(shp_fn):
    sys.exit('Unable to find input shp')

outdir = os.path.splitext(shp_fn)[0]+'_count'
if not os.path.exists(outdir):
    os.makedirs(outdir)

shp_ds = ogr.Open(shp_fn)
shp_lyr = shp_ds.GetLayer()
shp_srs = shp_lyr.GetSpatialRef()

#Filter cloudcover
#Filter IKONOS/QB2?

res = 1024.
dst_dt = gdal.GDT_Byte
#dst_srs = geolib.wgs_srs
#This is HMA UTM
dst_srs = osr.SpatialReference()
dst_srs.ImportFromEPSG(32644)
#This is UTM 11N
#dst_srs.ImportFromEPSG(32611)
#dst_srs = geolib.sps_srs

dst_dtype=gdal.GDT_Byte
dst_ndv = 0
gtiff_drv = gdal.GetDriverByName('GTiff')

#m_ds = mem_ds(res, extent, srs=dst_srs, dtype=gdal.GDT_Byte)
#For stereo, use this
#name_field = 'pair_name'
#WV01_20140214_102001002C122A00_102001002D5E9300
#acqdate
#2014-02-14

#This creates dummy ogr dateset, will add new layer with single feature
drv = ogr.GetDriverByName('Memory')  
temp_ds = drv.CreateDataSource('out') 

#This is for dg_imagery_index_stereo shp
#date_field = 2 
#name_field = 15

#This is for validpairs
#date_field = 2
#name_field = 0

#This is for Antarctica gdb stereo
date_field = 1
name_field = 14

out_fn = os.path.join(outdir, os.path.split(outdir)[-1]+'_count_fn_list.txt')
f = open(out_fn, 'w')

for n,feat in enumerate(shp_lyr):
    geom = feat.GetGeometryRef()
    geom.AssignSpatialReference(shp_srs)
    geolib.geom_transform(geom, dst_srs)
    #This is xmin, xmax, ymin, ymax
    extent = geom.GetEnvelope()

    #Get output filename from feature, make sure datestr is included
    pairname = feat.GetFieldAsString(name_field) 
    pairdt = feat.GetFieldAsString(date_field)
    pairdt = pairdt.replace('-','')[0:8]
    dst_fn = '%s_%s_%im.tif' % (pairdt, pairname, res)
    dst_fn = os.path.join(outdir, dst_fn)
    print>>f, os.path.split(dst_fn)[-1]

    temp_lyr = temp_ds.CreateLayer('out', None, ogr.wkbPolygon)
    temp_lyr.CreateFeature(feat)

    dst_ns = int((extent[1] - extent[0])/res + 0.9999)
    dst_nl = int((extent[3] - extent[2])/res + 0.9999)
    dst_gt = [extent[0], res, 0, extent[3], 0, -res]

    dst_ds = gtiff_drv.Create(dst_fn, dst_ns, dst_nl, 1, dst_dtype)
    dst_ds.SetGeoTransform(dst_gt)
    dst_ds.SetProjection(dst_srs.ExportToWkt())

    gdal.RasterizeLayer(dst_ds, [1], temp_lyr, burn_values=[1])
    b = dst_ds.GetRasterBand(1)
    b.SetNoDataValue(0)
    dst_ds = None
    feat.Destroy()

f = None

#Split into years
#Antarctica
#timelib.get_dt_bounds_fn(out_fn, min_rel_dt=(5,31), max_rel_dt=(6,1))
#PNW
timelib.get_dt_bounds_fn(out_fn, min_rel_dt=(8,1), max_rel_dt=(10,31))
timelib.get_dt_bounds_fn(out_fn, min_rel_dt=(4,1), max_rel_dt=(6,30))

sys.exit()

#Make sure file limit is set
#OS x requires the following for ulimit beyond 9999
#sudo sysctl -w kern.maxfiles=1000000
#sudo sysctl -w kern.maxfilesperp=1000000
#ulimit -S -n 1000000

#Generate annual mosaics
#This can require a ton of memory
#Should split up into chunks of ~1000 inputs or so
#parallel 'dem_mosaic --threads 2 -l {} --count -o {.}' ::: 2*fn_list.txt
#mkdir mos_year
#mv 2*fn_list* mos_year
#cd mos_year
#Now create cumulative mosaic
#dem_mosaic --count -o annual 2*count.tif

#for i in 20140101_20130531-20140601_fn_list.txt 20150101_20140531-20150601_fn_list.txt 20160101_20150531-20160601_fn_list.txt; do dem_mosaic -l $i --count -o ${i%.*}; done

#Hack to split lists - should do this up front in timelib
#list_fn=20160101_20150531-20160601_fn_list.txt
#for i in 201506 201507 201508 201509 201510 201511 201512 201601 201602 201603 201604
#do
#grep ^$i $list_fn > ${list_fn%.*}_$i.txt
#dem_mosaic -l ${list_fn%.*}_$i.txt --count -o ${i}_monthly
#done
#dem_mosaic --count -o 20160101_20150531-20160601_fn_list 20*monthly*count.tif
#Make stack then sum
