#! /usr/bin/env python
"""
Convert input extent in projected coordinates to ASP window
input: xmin ymin xmax ymax
output: xoff yoff xsize ysize
"""

import sys
import math

from osgeo import gdal
from pygeotools.lib import geolib

#Assumes coordinate system is same as input image
#Should check to make sure order is correct
fn = sys.argv[1]
extent = [float(x) for x in sys.argv[2:]]

ds = gdal.Open(fn)
gt = ds.GetGeoTransform()

x, y = geolib.mapToPixel([extent[0], extent[2]], [extent[1], extent[3]], gt)
#want upper left and then width, height
x = [math.floor(x[0]), math.ceil(x[1])]
y = [math.floor(y[0]), math.ceil(y[1])]
w = abs(x[1] - x[0])
h = abs(y[1] - y[0])

#out = [int(x[0]), int(y[1]), int(w), int(h)]
out = [x[0], y[1], w, h]
print ' '.join([str(int(i)) for i in out])
