#! /usr/bin/env python
import sys
import os
import glob
from datetime import datetime, timedelta

from lib import dglib
from lib import timelib

dir = sys.argv[1]

xml_list = glob.glob(os.path.join(dir, '*r100.xml'))
#Should really compute center time for each image, restricted to stereo intersection area
#Need to convert lat/lon to line using rpcs
id1 = dglib.get_id(os.path.split(xml_list[0])[-1])[0]
id2 = dglib.get_id(os.path.split(xml_list[1])[-1])[0]
t1 = dglib.xml_cdt(xml_list[0])
t2 = dglib.xml_cdt(xml_list[1])
cdt = timelib.center_date(t1, t2)
dt = abs(t1 - t2)
print id1, t1
print id2, t2
print "Center date: %s" % cdt
print "Time interval: %s" % dt
