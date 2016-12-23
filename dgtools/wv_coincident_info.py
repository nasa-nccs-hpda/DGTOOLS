#! /usr/bin/env python

import sys
import os
import glob
from datetime import datetime, timedelta

import numpy as np
import dateutil.parser

from dgtools.lib import dglib

indir = sys.argv[1]

print
print indir

ntf_list = glob.glob(os.path.join(indir,'*.ntf'))
xml_list = [dglib.getxml(ntf) for ntf in ntf_list]
#Note: sometimes the filename ID is wrong
id_list = [dglib.getTag(xml_fn, 'CATID') for xml_fn in xml_list]
uniq_id = list(set(id_list))

if len(uniq_id) != 2:
    print "Incorrect number of unique IDs"
    print uniq_id
    sys.exit()

t_list = [dateutil.parser.parse(dglib.getTag(xml_fn, 'FIRSTLINETIME')) for xml_fn in xml_list]

min_t_list = []
for id in uniq_id:
    #Might want to take mean here
    min_t = min(np.array(t_list)[(np.array(id_list) == id)])
    min_t_list.append(min_t)

dt = abs(min_t_list[1] - min_t_list[0])
dt_s = dt.total_seconds()

min_t_list.sort()
ctime = min_t_list[0] + dt/2

print uniq_id[0], min_t_list[0]
print uniq_id[1], min_t_list[1]
print "dt:", dt 
print "ctime:", ctime
print
