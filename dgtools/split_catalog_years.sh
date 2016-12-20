#! /bin/bash

shp=$1
lyr=${shp%.*}

t1='2001-06-01'
t2='2008-05-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2008-06-01'
t2='2009-05-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2009-06-01'
t2='2010-05-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2010-06-01'
t2='2011-05-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2011-06-01'
t2='2012-05-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2012-06-01'
t2='2013-05-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2013-06-01'
t2='2014-05-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2014-06-01'
t2='2015-05-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2015-06-01'
t2='2016-05-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2016-06-01'
t2='2017-05-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 
