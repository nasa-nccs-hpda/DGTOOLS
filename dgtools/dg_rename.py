#! /usr/bin/env python

import sys
import os
import shutil

from datetime import datetime

def getxml(fn):
    xml_fn = os.path.splitext(fn)[0]+'.xml'
    if not os.path.exists(xml_fn):
        xml_fn = os.path.splitext(fn)[0]+'.XML'
    if not os.path.exists(xml_fn):
        xml_fn = None 
    return xml_fn

def getET(xml_fn):
    import xml.etree.ElementTree as ET 
    tree = ET.parse(xml_fn)
    return tree

def getTag(tree, tag):
    #Want to check to make sure tree contains tag
    elem = tree.find('.//%s' % tag)
    if elem is not None:
        return elem.text

#Chop off time listed in filename (for r1c1 tiled inputs, this time is constant, don't use individual xml time)
def fn_t(fn):
    import re
    r = re.split('\W+', fn)
    t_str = r[0][-6:]
    return t_str

def xml_dt(tree):
    t = getTag(tree, 'FIRSTLINETIME')
    dt = datetime.strptime(t,"%Y-%m-%dT%H:%M:%S.%fZ")
    return dt

in_fn = sys.argv[1]
if not os.path.exists(in_fn):
    sys.exit("Unable to find: %s" % in_fn)
xml_fn = getxml(in_fn) 
if xml_fn is None:
    sys.exit("Unable to find xml file for: %s" % in_fn)
#Convert to uppercase
xml_fn_upper = os.path.splitext(os.path.split(xml_fn)[1])[0].upper()
tree = getET(xml_fn)
#<SATID>WV03</SATID>
sensor = getTag(tree, 'SATID')
#<FIRSTLINETIME>2015-04-23T15:27:00.890375Z</FIRSTLINETIME>
dt = xml_dt(tree)
#dt_str = dt.strftime('%Y%m%d%H%M%S')
dt_str = dt.strftime('%Y%m%d')
t_str = fn_t(xml_fn)
dt_str += t_str
#<CATID>104001000A70F500</CATID>
cat_id = getTag(tree, 'CATID')
#WV03_20150423152700_104001000A70F500_15APR23152700-P1BS-500358054200_01_P001.ntf
out_fn = '%s_%s_%s_%s%s' % (sensor, dt_str, cat_id, xml_fn_upper, os.path.splitext(in_fn)[-1].lower())
print in_fn
print out_fn
if not os.path.exists(out_fn):
    shutil.copyfile(in_fn, out_fn)
    #shutil.move(in_fn, out_fn)
    re_fn = os.path.splitext(out_fn)[0]+'.rename'
    f = open(re_fn, 'w')
    f.write("%s,%s" % (os.path.abspath(in_fn), out_fn))

#Stereo pairs
#WV03_20150423_104001000A587C00_104001000A70F500
#<FIRSTID>15JUL18204948-P1BS_R4C1-500392578010_01_P001.NTF</FIRSTID>
#<SECONDID>15JUL18205028-P1BS_R4C1-500392578010_01_P001.NTF</SECONDID>
