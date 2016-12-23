#! /usr/bin/env python

import os
import sys

import matplotlib.colors
import numpy as np

from pygeotools.lib import iolib

#Sample data in /scr/pansharpen_test

def brovey(r,g,b,p):
    ro = (r/(r + g + b)) * p
    go = (g/(r + g + b)) * p
    bo = (b/(r + g + b)) * p
    return ro, go, bo

def hsi(r,g,b,p):
    h,s,i = rgb2hsv(r,g,b)
    ro,go,bo = hsv2rgb(h, s, p)
    return ro, go, bo

def overlay(r,g,b,p):
    #From here
    #mf2 id ${ctxpicno:r}_8b sd $img od ${img:r}_overlay ex '(a < 127) ? (a * b) / 127 : 255 - (((255 - a) * (255 - b)) / 127)'
    prange = p.max() - p.min()
    pmid = p.min+(prange/2.)
    ro[p < pmid] = (p * r)/prange
    ro[p >= pmid] = prange - ((prange - p) * (prange - r))/pmid
    go[p < pmid] = (p * g)/prange
    go[p >= pmid] = prange - ((prange - p) * (prange - g))/pmid
    bo[p < pmid] = (p * b)/prange
    bo[p >= pmid] = prange - ((prange - p) * (prange - b))/pmid
    return ro, go, bo

#Inputs must be scaled from 0-1
#Results of toa reflectance calculation should work
def rgb2hsv_mpl(r, g, b):
    rgb = np.ma.array([r,g,b])
    hsv = matplotlib.colors.rgb_to_hsv(rgb)
    return hsv[0], hsv[1], hsv[2]

def hsv2rgb_mpl(h, s, v):
    hsv = np.ma.array([h,s,v])
    rgb = matplotlib.colors.hsv_to_rgb(hsv)
    return rgb[0], rgb[1], rgb[2]

def rgb2hsv(r, g, b):
    m = np.ma.min([r, g, b], axis=0)
    #Value (HSV)
    M = np.ma.max([r, g, b], axis=0)
    v = M
    #Intensity (HSI)
    #I = np.ma.mean([r, g, b], axis=0)
    #Lightness (HSL)
    #L = np.ma.mean([M, m], axis=0)
    #Luma
    #Y = 0.3*r + 0.59*g + 0.11*b
    c = M - m
    h = np.select([c==0, r==M, g==M, b==M], [0, ((g-b)/c) % 6, (2 + ((b-r)/c)), (4 + ((r-g)/c))], default=0) * 60
    h = np.ma.array(h, mask=np.ma.getmaskarray(v))
    #This is S for HSV
    s = np.select([c==0, c!=0], [0, c/v])
    s = np.ma.array(s, mask=np.ma.getmaskarray(v))
    #HSL
    #Note, should be OK with cascading conditions here
    #s = np.select([c==0, c==1, c!=0], [0, 0, c/(1-np.ma.abs(2*L - 1))])
    #This is S for HSI
    #s = np.select([I==0, I!=0], [0, 1-m/I])
    return h, s, v

def hsv2rgb(h, s, v):
    #HSV
    c = v * s
    m = v - c
    #HSL
    #l = v
    #c = (1 - np.abs(2*l - 1)) * s
    #m = l - c/2.
    #HSI
    #Need to work this out
    #c = v * (s - 1)
    h = h/60
    x = c*(1-np.ma.abs(h%2 - 1))
    #Converting to int here rounds down, makes select statement simple
    h = h.astype(int)
    r = np.select([h==0,h==1,h==2,h==3,h==4,h==5], [c, x, 0, 0, x, c], default=0)
    g = np.select([h==0,h==1,h==2,h==3,h==4,h==5], [x, c, c, x, 0, 0], default=0)
    b = np.select([h==0,h==1,h==2,h==3,h==4,h==5], [0, 0, x, c, c, x], default=0)
    r += m
    g += m
    b += m
    return r, g, b

r_fn, g_fn, b_fn, p_fn = sys.argv[1:5]
r = iolib.fn_getma(r_fn).filled()
g = iolib.fn_getma(g_fn).filled()
b = iolib.fn_getma(b_fn).filled()
p = iolib.fn_getma(p_fn).filled()

min_val = 1
max_val = 2048
range = max_val - min_val
if True:
    r = r.astype('Float32')/range
    g = g.astype('Float32')/range
    b = b.astype('Float32')/range
    p = p.astype('Float32')/range

#Common mask
#h, s, v = rgb2hsv(r, g, b)
#r1, g1, b1 = hsv2rgb(h, s, p)
#Apply common mask

