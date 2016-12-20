#!/usr/bin/env python

from distutils.core import setup

#To prepare a new release
#python setup.py sdist upload

setup(name='dgtools',
    version='0.1.0',
    description='Utilities for working with DigitalGlobe data',
    author='David Shean',
    author_email='dshean@gmail.com',
    license='MIT',
    url='https://github.com/dshean/demcoreg',
    packages=['dgtools'],
    long_description=open('README.md').read(),
    install_requires=['numpy','gdal','pygeotools','wget'],
    #Note: this will write to /usr/local/bin
    scripts=['dgtools/validpairs.py',]
)

