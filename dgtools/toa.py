#! /usr/bin/env python

import sys
import os

from lib import dglib

xml_fn = sys.argv[1]
band = sys.argv[2]
print dglib.toa_refl(xml_fn, band)[0]

sys.exit()

img_fn = sys.argv[1]
dir = os.path.split(img_fn)[0]
id = get_id(img_fn)
xml_list = dglib.get_xmllist(dir, id)
xml_list.extentd(dglib.get_xmllist(os.path.join(dir,'M1BS'), id))

if re.match('_b[0-9]_', img_fn):
    band = img_fn.split('_b')[1].split('_')[0]

for xml in xml_list:
    t = None
    t = dglib.getTag(xml_fn, 'ABSCALFACTOR')


