#! /usr/bin/env python

#David Shean
#dshean@gmail.com
#3/30/15

#Utility to compare stereopair acquisition geometry, triangulation error
#First section gathers relevant information from different sources and writes to json
#Second section generates plots

import sys
import os
import glob
import json

import numpy as np
import matplotlib.pyplot as plt

from dgtools.lib import dglib
from pygeotools.lib import iolib
from pygeotools.lib import malib
import error_analysis

dirlist = sys.argv[1:]

trierror_fn = []

pairlist = []

for dir in dirlist:
    print dir
    pair = dglib.dir_pair_dict(dir)

    dem_fn = glob.glob(pair['pairname']+'/dem*/*DEM_tr4x.tif')
    if len(dem_fn) > 0:
        print "Parsing pc_align log"
        dem_fn = dem_fn[0]
        #Temp hack
        #dem_fn = os.path.split(dem_fn)[-1]
        error_dict = error_analysis.parse_pc_align_log(dem_fn)
        error_dict['Date'] = str(error_dict['Date'])
        pair['error_dict'] = error_dict 

    #trierror_fn = glob.glob(pair['pairname']+'/dem*/*Err.tif')
    if len(trierror_fn) > 0:
        print "Computing stats for Tri Error grid"
        trierror = iolib.fn_getma(trierror_fn[0])
        trierror_stats = [float(i) for i in malib.print_stats(trierror)]
        trierror_med = trierror_stats[5]
        pair['trierror_stats'] = trierror_stats

    pairlist.append(pair)

#json.dumps(pairlist)
with open('pairinfo_json.txt', 'w') as outfile:
    json.dump(pairlist, outfile)
