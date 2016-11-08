#! /usr/bin/env python

import sys

from lib import dglib

dir = sys.argv[1]

ids = dglib.dir_ids(dir)

for id in ids:
    print id
