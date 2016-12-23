#! /usr/bin/env python

#David Shean
#dshean@gmail.com

#This is a hack to precompute the stereo intersection geometry
#from two input xml files
#The output can then be fed to mapproject
#This is more efficient than mapping first, then clipping

import os
import sys
from osgeo import osr

from dgtools.lib import dglib

xml1 = sys.argv[1]
xml2 = sys.argv[2]

#This should be optional
proj = sys.argv[3]

#Can extract appropriate proj from xml, don't need to export to Proj4
#from lib import geolib 
#proj = geolib.get_proj(dglib.xml2geom(xml1)).ExportToProj4()

igeom = dglib.stereo_intersection_xml_fn(xml1, xml2)
#isect_te = (isect[0], isect[2], isect[1], isect[3])

igeom_srs = igeom.GetSpatialReference()

t_srs = osr.SpatialReference()
t_srs.ImportFromProj4(proj)

if t_srs is not None and not igeom_srs.IsSame(t_srs):
    ct = osr.CoordinateTransformation(igeom_srs, t_srs)
    igeom.Transform(ct)

#Write out for later use
wkt_fn = '%s_%s_int.wkt' % (xml1.split(os.extsep, 1)[0], os.path.split(xml2)[1].split(os.extsep, 1)[0])
#Could include srs in wkt
#out_wkt = t_srs.ExportToWkt() + ', ' + igeom.ExportToWkt()
out_wkt = igeom.ExportToWkt()
f = open(wkt_fn, 'w')
f.write(out_wkt + '\n')
f.write(t_srs.ExportToProj4())
f.close()

#from lib import geolib
#shp_fn = os.path.splitext(wkt_fn)[0]+'.shp'
#geolib.geom2shp(igeom, shp_fn)

#This can be used to determine intersecting subscenes
#print igeom.GetArea()

igeom_env = igeom.GetEnvelope()

print igeom_env[0], igeom_env[2], igeom_env[1], igeom_env[3] 
