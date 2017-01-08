#! /bin/bash

#Utility to stash existing output files ASP w/ parabolic sub-pixel refinement
#Preparation for re-run with different refinement (e.g., BayesEM)

#Use specified input directory if provided
if [ $# -eq 1 ]; then
    indir=$1
else
    indir=$(pwd)
fi

if [ ! -d $indir ]; then
    echo "Unable to find directory $indir"
    exit 1
fi

#Find the directory containing the goods
if $(ls $indir/*-RD.tif &> /dev/null); then
    dir=$indir
else
    if $(ls -d $indir/dem* &> /dev/null); then
        #Might need to deal with multiple dem directories here
        dir=$(ls -d $indir/dem* | head -1)
    else
        echo "Input directory does not contain -RD.tif or a dem subdirectory"
        #exit 1
    fi
fi

#For a change in refinement method
#Core parabolic products
extlist="-RD.tif -F.tif -GoodPixelMap.tif -PC.tif"
#Pick up after refinemnet, for filtering tests
#extlist="-F.tif -GoodPixelMap.tif -PC.tif"
#dem_post products
extlist="$extlist -DEM*.tif -DRG*.tif -IntersectionErr.tif" 

#For a change in seed mode
#sparse_disp products and integer corr
#extlist="$extlist -D.tif -D_sub.tif -D_sub_spread.tif .csv" 
#extlist="$extlist -L_sub.vwip -L_sub__R_sub.match -R_sub.vwip"

extlist="$extlist .txt .default"

pushd $dir &> /dev/null

outdir=parabolic
#outdir=parabolic_21px_erode32
#outdir=parabolic_full_sm3
#outdir=parabolic_full_sm1
#outdir=write_error

if [ ! -d $outdir ]; then
    mkdir -pv $outdir 
fi

for i in $extlist
do
    #filelist=$(find . -maxdepth 1 -name "*-${i}.tif")
    filelist=$(eval ls *$i 2> /dev/null)
    if [ ${#filelist} -ne 0 ]; then
        mv -vi $filelist $outdir/ 
    fi
done

pushd &> /dev/null

#Rerun with spm 2
#new_dg_stereo.sh $dir
