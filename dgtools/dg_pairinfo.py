#! /usr/bin/env python

#David Shean
#dshean@gmail.com

#Add heading for each image in projected CS (useful for jitter correction)
#Print TDI and scan direction info
#Print Convergence angle
#Move to dglib

import os
import sys

import numpy as np
import osr

from lib import dglib
from lib import geolib

wgs_srs = geolib.wgs_srs
write_shp = False

#Predict runtime in hours based on intersection area in pixels
#Numbers for 12 threads on westemere node
def pred_runtime(igeom_px):
    m = 6E-9
    b = 2
    t = m*igeom_px + b
    return int(np.ceil(t))

def geom_ct(geom):
    geom_srs = geom.GetSpatialReference()
    t_srs = osr.SpatialReference()
    t_srs = geolib.get_proj(geom)
    #proj = geolib.get_proj(geom)
    #t_srs.ImportFromProj4(proj)
    if t_srs is not None and not geom_srs.IsSame(t_srs):
        ct = osr.CoordinateTransformation(geom_srs, t_srs)
        geom.Transform(ct)
    return geom 

dir = sys.argv[1]
if write_shp:
    shpdir = os.path.join(dir, 'shp')
    if not os.path.exists(shpdir):
        os.makedirs(shpdir)

ids = dglib.dir_ids(dir)
#ids = dglib.pairname_ids(dir)
id_geom_list = []
id_gsd_list = []
for id in ids:
    #ntf_list = dglib.get_ntflist(dir, id)
    xml_list = dglib.get_xmllist(dir, id)
    geom_list = []
    gsd_list = []
    #for ntf in ntf_list:
    for f in xml_list:
        gsd = None
        #xml_fn = dglib.getxml(f)
        xml_fn = f 
        geom = dglib.xml2geom(xml_fn)
        geom.AssignSpatialReference(wgs_srs)
        geom_list.append(geom)
        #Need to check if this is empty before converting to float
        #Early deliveries are missing
        gsd = dglib.getTag(xml_fn, 'MEANPRODUCTGSD')
        if gsd is None:
            gsd = dglib.getTag(xml_fn, 'MEANCOLLECTEDGSD')
        gsd_list.append(float(gsd))
    if len(geom_list) > 1:
        id_geom = geolib.geom_union(geom_list)
    elif len(geom_list) == 1:
        id_geom = geom
    else:
        sys.exit("Unable to extract geometry")
    id_geom = geom_ct(id_geom)
    id_geom_list.append(id_geom)
    if write_shp:
        shp_fn = os.path.join(shpdir, id+'.shp')
        geolib.geom2shp(id_geom, shp_fn)
    id_gsd = np.mean(gsd_list) 
    id_gsd_list.append(id_gsd)
    #print id, id_gsd, id_geom.GetArea()

igeom_gsd = np.min(id_gsd_list)
igeom = id_geom_list[0].Intersection(id_geom_list[1])
igeom_area = igeom.GetArea()
igeom_px = igeom_area/igeom_gsd**2
if write_shp:
    shp_fn = os.path.join(shpdir, ids[0]+'_'+ids[1]+'_int.shp')
    geolib.geom2shp(igeom, shp_fn)

#Want to print for wes, san, ivy
igeom_runtime = pred_runtime(igeom_px)
print dir, igeom_gsd, igeom_area/1E6, igeom_px/1E6, igeom_runtime
