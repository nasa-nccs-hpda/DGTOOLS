#! /usr/bin/env python

"""
David Shean
dshean@gmail.com
8/11/12

This script will download and georeference browse images from the DG catalog, given an input shapefile

#For Catalog.html with stereo:
#grep 'ids\[' Catalog_20140212.html | awk -F"['|_]" '{print $2}' > id1_list.txt
#Then search imagefinder for idlist

To do:
Remove excessive I/O - most of the processing can be done in memory
NOTE: stereo search and mono search have different category ids
Remove png
Create output shapefile/kml from input geom
Add option to process only records marked as selected
Multiple processes
Want isolate the process for a single catalog ID
Do search and save results webpage
https://browse.digitalglobe.com/imagefinder/catalogEntryShow.do
"""

import os, sys, subprocess, shutil
from osgeo import gdal, ogr
from PIL import Image
from bs4 import BeautifulSoup
from datetime import datetime

import numpy
from lib import iolib
from lib import malib
from lib import geolib
from lib import warplib

#Depreciated method to trim margins to valid data using PIL
def trim(im):
    from PIL import ImageChops
    bg = Image.new(im.mode, im.size, im.getpixel((0,0)))
    diff = ImageChops.difference(im, bg) 
    #This handles compression artifacts
    #diff = ImageChops.add(diff, diff, 2.0, -100)
    bbox = diff.getbbox()
    if bbox:
        return im.crop(bbox)

overwrite = False 
list_fn = sys.argv[1]
#proj = sys.argv[2]
proj = None

#This was a first hack, before including BeautifulSoup
#f = open(list_fn, 'r')
#cat_dict = {}
#for line in f:
#    if "<tr catalogidentifier=" in line:
#        line = line.splitlines()[0].lstrip('</tr><tr ').rstrip('>')
#        entry_dict = dict(item.split('="') for item in line.split('" ')) 
#        cat_dict[entry_dict['catalogidentifier']] = entry_dict   

#Also possible to get image metadata
#Includes target azimuth
#https://browse.digitalglobe.com/imagefinder/showBrowseMetadata?buffer=1.0&catalogId=103001000C23DA00&imageHeight=natres&imageWidth=natres

#Parse html file using BeautifulSoup
soup = BeautifulSoup(open(list_fn), "html.parser")
#table = soup.find('table', id="mytable")
table = soup.find('table')
#Extract header row
hdr = [x.text.strip() for x in table.find_all('th')]  
#Extract all rows with image metadata
rows = soup.find_all('tr', catalogidentifier=True)

print hdr

cat_list = []
for r in rows:
    #Slick way to populate dictionary from attributes in row not visible in table
    entry_dict = r.attrs
    #Extract additional information visible in table
    list = [x['copydata'] for x in r.find_all('td', copydata=True)]
    row_dict = dict(zip(hdr[2:], list))
    entry_dict.update(row_dict)
    #Now extract metadata from individual product page
    #url = 'https://browse.digitalglobe.com/imagefinder/showBrowseMetadata?catalogId=%s' % r.attrs['Catalog id']
    #page = urllib2.urlopen(url)
    #soup = BeautifulSoup(page.read())
    cat_list.append(entry_dict)

print len(cat_list), "input catalog IDs"

vrtdriver = gdal.GetDriverByName('VRT')

for n, item in enumerate(cat_list):
    print
    #if item['selected']:

    #Import geometry - this should be image footprint
    geom = ogr.CreateGeometryFromWkt(item['wkt']) 
    #Extent is minlon, maxlon, minlat, maxlat
    extent = geom.GetEnvelope()
   
    id = item['Catalog Id']
   
    #This is for Stereo search results
    #acqdate = datetime.strptime(item['Latest Acquisition Date'], '%Y/%m/%d')
    acqdate = datetime.strptime(item['Acquisition Date'], '%Y/%m/%d')

    #outid = acqdate.strftime('%Y%m%d')+'_'+item['Sensor Vehicle']+'_'+id
    outid = acqdate.strftime('%Y%m%d')+'_'+item['Spacecraft']+'_'+id
    #Quick tests for Cascades data suggest ~13-15 m/px native resolution
    out_res = '12'
    sub_res = 100
    out_fn = '%s_%sm.tif' % (outid, out_res)
    sub_fn = '%s_%sm.tif' % (outid, sub_res)

    print n+1, outid, extent

    if os.path.exists(sub_fn):
        print "Found existing file: %s" % out_fn
        if overwrite:
            print "Overwrting existing file"
        else:
            continue

    #https://browse.digitalglobe.com/imagefinder/showBrowseMetadata?catalogId=102001003380C400
    page_url = 'https://browse.digitalglobe.com/imagefinder/showBrowseMetadata?catalogId=%s' % (id)
    page_fn = outid+'.html'
    cmd = 'wget --no-check-certificate -O %s "%s"' % (page_fn, page_url)
    #Check to see if page already exists on filesystem, if not download
    try:
        with open(page_fn) as f: pass
    except IOError as e:
        #import urllib
        #urllib.urlretrieve(url, browseimg_fn_rgb)
        print cmd
        subprocess.call(cmd, shell=True)

    #parse to extract Avg Off Nadir Angle, Avg Target Azimuth
    #These are not in html fields, but are contained as text within a single table row

    """
    try: 
        with open(out_fn) as f: pass
        print "Found existing file: %s" % out_fn
        continue
    except IOError as e:
        print "Processing %s" % outid 
    """

    #Eventually, just keep as srs and do warping in memory
    proj = geolib.get_proj(geom).ExportToProj4()

    if proj is None:
        print 'Unable to determine projected coordinate system'
        print 'Reverting to WGS84'
        proj = geolib.wgs_srs.ExportToProj4()

    print "Selected proj is: ", proj

    #Get image from DG website
    browseimg_fn_rgb = outid+'_rgb.png'
    #Note: can specify any height/width dimensions in the url
    browse_size = 'natres'
    #browse_size = '2048'
    url = 'https://browse.digitalglobe.com/imagefinder/showBrowseImage?catalogId=%s&imageHeight=%s&imageWidth=%s' % (id, browse_size, browse_size)
    print url
    #Note: Important to enclose url in quotes here, otherwise ? and & 
    cmd = 'wget --no-check-certificate -O %s "%s"' % (browseimg_fn_rgb, url)
   
    #Check to see if image already exists on filesystem, if not download
    try:
        with open(browseimg_fn_rgb) as f: pass
    except IOError as e:
        #import urllib
        #urllib.urlretrieve(url, browseimg_fn_rgb)
        print cmd
        subprocess.call(cmd, shell=True)

    #Want to properly mask nodata - deal with fact that 255 is valid - do mask from edges of image
    #This is mostly an issue for grayscale images
    browseimg_ndv = 255
    out_ndv = 0
   
    print "Loading image"
    im = Image.open(browseimg_fn_rgb)

    print "Image dimensions:", im.size

    #DG png are RGB by default, even if there is only one gray band
    #Note: stereo list doesn't contain Imaging Bands
    """
    if item['Imaging Bands'] == 'Pan':
        #Convert png to grayscale
        print "Converting to grayscale"
        im = im.convert('L')
        #os.remove(browseimg_fn_rgb)
    """

    if True: 
        #This attempts to find valid edges and only mask data outside contiguous area
        #Residual offsets between mask and actual valid data...hmmm 
        print "Loading into masked array"
        a = numpy.array(im)
        ma = numpy.ma.masked_equal(a, browseimg_ndv)
        print "Masking margins and trimming to valid data"
        a_trim = malib.apply_edgemask(ma, trim=True).filled(out_ndv)
        im_trim = Image.fromarray(a_trim)
    else:
        #This uses PIL trim approach - saturated areas are set to ndv
        im_trim = trim(im)
    
    browseimg_fn = outid+'_trim.png'
    im_trim.save(browseimg_fn)

    #Now open with gdal and create a vrt with gt, proj, ndv
    browseimg_ds = gdal.Open(browseimg_fn, gdal.GA_ReadOnly)

    #Can just use resolution computed along meridian here
    #x and y res should be identical since input is WGS84 geographic CS
    #Note: Some high-latitude natres images have reduced width, MUST use x_res
    x_res = (extent[1]-extent[0])/browseimg_ds.RasterXSize
    y_res = (extent[3]-extent[2])/browseimg_ds.RasterYSize

    #Create geotransform
    gt = [extent[0], x_res, 0, extent[3], 0, -y_res]

    #Create vrt for png
    vrt_fn = os.path.splitext(browseimg_fn)[0] + '.vrt'
    vrt = vrtdriver.CreateCopy(vrt_fn, browseimg_ds) 
    vrt.SetGeoTransform(gt)
    vrt.SetProjection('EPSG:4326')
    for n in range(vrt.RasterCount):
        b = vrt.GetRasterBand(n+1)    
        b.SetNoDataValue(out_ndv)
    vrt = None
   
    co = ""
    #cmd = 'gdalwarp -overwrite -s_srs EPSG:4326 -t_srs "%s" -tr %s %s -srcnodata %s -dstnodata %s -r cubic %s %s %s' % \
    cmd = 'gdalwarp -co "COMPRESS=LZW" -co "TILED=YES" -overwrite -s_srs EPSG:4326 -t_srs "%s" -tr %s %s -srcnodata %s -dstnodata %s -r cubic %s %s %s' % \
    (proj, out_res, out_res, out_ndv, out_ndv, co, vrt_fn, out_fn)
    print cmd
    subprocess.call(cmd, shell=True)

    cmd = 'gdalwarp -tr %0.2f %0.2f -r cubic -dstnodata %s %s %s' % (sub_res, sub_res, out_ndv, out_fn, sub_fn)
    print cmd
    subprocess.call(cmd, shell=True)

    """
    #Generate overviews
    #Note: No way to specify these options through the Python API
    oo = "-r gauss --config COMPRESS_OVERVIEW JPEG --config JPEG_QUALITY_OVERVIEW 95 --config PHOTOMETRIC_OVERVIEW YCBCR --config INTERLEAVE_OVERVIEW PIXEL"
    cmd = 'gdaladdo %s %s 2 4 8 16' % (oo, out_fn)
    print cmd
    subprocess.call(cmd, shell=True)

    #Extract small preview image
    out_fn_sm = os.path.splitext(out_fn)[0]+'_8x.tif'
    olvl = 100./8
    cmd = 'gdal_translate -outsize %0.3f%% %0.3f%% %s %s' % (olvl, olvl, out_fn, out_fn_sm)
    print cmd
    subprocess.call(cmd, shell=True)

    #Compress final output product
    #Want to preserve overviews here
    co = "-co COPY_SRC_OVERVIEWS=YES -co COMPRESS=LZW -co TILED=YES"
    cmd = 'gdal_translate %s %s %s' % (co, out_fn, 'temp.tif')
    print cmd
    subprocess.call(cmd, shell=True)
    shutil.move('temp.tif', out_fn)
    """

print
