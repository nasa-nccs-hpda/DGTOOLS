#! /usr/bin/env python

#Filter mono dg catalog shapefile to generate candidate coincident stereo pairs

import os
import sys
from dgtools.lib import dglib

#On lfe in mono dir
#Generate list of cat id and time from mono delivery
#time_fn = '2015aug28_2015oct23_combined_mono_id_time_list_uniq.txt'
#time_fn = '../2015aug28_mono_id_time_list_uniq.txt'
#time_fn = 'pig_mono_2015oct23_id_time_list_uniq.txt'
#ls */*ntf | awk -F'/' '{print $2}' | awk -F'_' '{print $3, $2}' | sort -u -k1,1 | sort -n -k 2 > $time_fn

#Note: shape should be in projected coordinates for area calculation

#Maximum number of days
max_dt = 7.0
#Maximum cloud cover
max_cc = 25

shp_fn = sys.argv[1] 
d_list = dglib.parse_pgc_catalog_mono(shp_fn)

"""
#This adds time for delivered products
d_list = dglib.parse_pgc_catalog_mono(shp_fn, timelist=time_fn)
t_list = []
for i in d_list:
   if i['date'].hour != 0:
       t_list.append(i)
c = dglib.get_candidates(t_list)
"""
#c = dglib.get_candidates(d_list)
#This is much faster, does initial filtering by dt and intersection
c = dglib.get_candidates_dt(d_list, max_dt=max_dt)
if len(c) > 1:
    g = dglib.get_validpairs(c, min_conv=10, max_conv=70, max_dt_days=max_dt, min_area=40, min_area_perc=0, min_w=6, min_h=6, max_cc=max_cc, include_intrack=False, same_platform=False)
    #out_fn = os.path.splitext(shp_fn)[0]+'_validpairs_time_2day_update'
    if len(g) >= 1:
        out_fn = os.path.splitext(shp_fn)[0]+'_validpairs'
        dglib.valid_txt(g, out_fn+'.csv')
        dglib.valid_pairname_txt(g, out_fn+'_pairname.txt')
        dglib.valid_shp(g, out_fn+'.shp')
        dglib.unique_ids(g, out_fn+'_uniq_ids.txt')

#Now copy files to nobackup and generate dir

#ssh lfe
#id_list=
#If in subid, do this
#for id in $(cat $id_list); do ls *${id}*/*${id}* >> ${id_list%.*}_filelist.txt; done
#shiftc -R $(cat ${id_list%.*}_filelist.txt) $outdir

#Back on nobackup
#Create individual directories
#for i in $(cat ${shp_fn%.*}_pairname.txt); do mkdir $i; pushd $i; ids=$(echo $i | awk -F'_' '{print $3 " " $4}'); for id in $ids ; do list=$(ls ../images/*${id}*/*${id}*); for j in $list ; do ln -s $j . ; done; done; pushd; done
#~/bin/stereo_qsub.sh
