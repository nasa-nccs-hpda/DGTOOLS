#! /bin/bash 

#David Shean
#dshean@gmail.com
#5/26/13

#Wrapper for Ames Stereo Pipeline DigitalGlobe processing

#Replace eval cmd $opt (options should be created as arrays)
#Fix the hack-y resolution and filename handling - just maintin variables for L, R, Lxml, Rxml to pass into stereo
#Need more log output

#Extract specified tag from xml file
function gettag() {
    xml=$1
    tag=$2
    echo $(grep "$tag" $xml | awk -F'[<>]' '{print $3}')
}

if [[ "$#" -lt 1 ]] ; then
    echo
    echo "Usage is: $(basename $0) pairdir [rpcdem]"
    echo "Where pairdir contains ntf or mosaiced tif files"
    echo
    exit 1
fi

#Input directory
dir=$1

#Used for kernel test
#spm=$2
#corrkernel=$3
#rfnekernel=$4
#erode_px=$5

if [[ "$#" -eq 2 ]] ; then
    #Input rpc dem
    #Used for site reprocessing
    rpcdem=$2
    rpcdem=$(realpath $rpcdem)

    if [ ! -e $rpcdem ] ; then
        echo "Unable to find input RPC DEM: $rpcdem"
        exit 1
    fi
fi

os=$(uname)

#This provides total number of cores, but includes hyperthreading
#ncpu=$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | tail -1)
#This provides number of physical cores
ncpu=$(cat /proc/cpuinfo | egrep "core id|physical id" | tr -d "\n" | sed s/physical/\\nphysical/g | grep -v ^$ | sort | uniq | wc -l)

#export NCPUS=16
#PBS sets NCPUS based on number of cores available per node
if [ -z "$NCPUS" ] ; then 
    #If running on bridge or pfe nodes, don't hog all cores
    #if (( $ncpu > 20 )) ; then
    #    ncpu=16
    #fi
    export NCPUS=$ncpu
fi
export NCPUS=$ncpu

#******************************************************************

#Stereo Setup

#GDAL options
#gdaldem has issues with BIGTIFF=IF_SAFER for large inputs
gdal_opt="-co TILED=YES -co COMPRESS=LZW -co BIGTIFF=YES" 
gdal_opt+=" -co BLOCKXSIZE=256 -co BLOCKYSIZE=256"

#If input RPC DEM is specified, extract extent
#Should intersect with image extents, common projection, find intersection
if [ -n "$rpcdem" ] ; then
    crop_extent=$(get_extent.py $rpcdem)
fi

#Can hardcode crop extent here
#Rainier, UTM10N
#crop_extent='583980.563675 5180108.83473 604964.563675 5201532.83473'

if [ -n "$crop_extent" ] ; then
    echo "User-defined crop extent: $crop_extent"
    echo "If this is a fresh run, inputs will be mapped to this limited extent"
    echo "If this is a rerun, processing (e.g. refinement onward) will be limited to this extent"
fi

#Running on Pleiades?
pleiades=true

#Map images?
map=true

#Bundle Adjustment for input images?
bundle=false

#Desired image GSD in meters
#Should set res=0.0 for native fullres
res="nat"
#Alternative approach to specify reduce_percent
#scale=50
#Nodata values to use for image and DEM
ndv=0
dem_ndv=-9999

#Output DRG?
drg=false

#Output error map?
error=false

#Remove intermediate files, (PC, F)?
rmfiles=false

#Compress output gtiff?
compress=false

#Set up stereo command line options (no .stereo.default needed)
stereo_opt=""
map_opt=""
sparse_disp_opt=""

#Use DG session
stereo_opt+=" -t dg"
#stereo_opt+=" -t rpc"

#Print commands as they are run and wall times
stereo_opt+=" --verbose"

#Generate output DEMs with different res in parallel
#Note: memory issues for westmere nodes, safe for ivy
parallel_point2dem=false
if [ "$NCPUS" -gt "12" ] ; then
    parallel_point2dem=true
fi

echo "Setting --threads to $NCPUS"
stereo_opt+=" --threads $NCPUS"
#sparse_disp_opt+=" --processes $NCPUS"
sparse_disp_opt+=" --processes $((NCPUS - 1))"
map_opt+=" --threads $NCPUS"

#Should use this for validpairs formed from mono images with different illumination
stereo_opt+=" --individually-normalize"

#Sub-pixel refinement
#1=parabola
#2=bayesEM
#3=affine
spm=1
stereo_opt+=" --subpixel-mode $spm"

#Set correlation kernel sizes
#This worked well for PNW forests
corrkernel=31
#rfnekernel=31
#A good compromise between resolution and continuity
#corrkernel=21
rfnekernel=11

stereo_opt+=" --corr-kernel $corrkernel $corrkernel"
stereo_opt+=" --subpixel-kernel $rfnekernel $rfnekernel"

#Create symlinks to mapped L/R images instead of normalizing
#NOTE: BayesEM refinement requires normalization up front
#if $map && [ "$spm" == "1" ] ; then
#    stereo_opt+=" --skip-image-normalization"
#fi

#Seed mode
#1 stereo_corr from L_sub and R_sub
#2 RPC_DEM
#stereo_opt+=" --disparity-estimation-dem $rpcdem"
#3 sparse_disp
sm=1
stereo_opt+=" --corr-seed-mode $sm"

if [ "$sm" == "3" ] ; then
    #Default ASP tile size is 1024x1024, should be OK with fine skip of 256
    sparse_disp_opt+=" --coarse 512 --fine 256 --output_dec_scale=8 --Debug"
    #Turn off epipolar filter - doesn't work well for dg_mosaic output and inaccurate rpcdem
    sparse_disp_opt+=" --no_epipolar_fltr"
    #Use local epipolar filter
    #sparse_disp_opt+=" --local_epipolar"
    #sparse_disp_opt+=" --Exhaustive"
    #Remove leading whitespace (not essential)
    sparse_disp_opt=$(echo $sparse_disp_opt | sed 's/^[ \t]*//')
    stereo_opt+=" --sparse-disp-options '$sparse_disp_opt'"
fi

#Max corr levels
#Output size for sparse_disp is 1/8 input size, should only need level 3
#For Antarctica
#max_lv=2
max_lv=5
stereo_opt+=" --corr-max-levels $max_lv"

#Timeout for tile in seconds
timeout=480
stereo_opt+=" --corr-timeout $timeout"

#Filtering mode
stereo_opt+=" --filter-mode 1"

#Erosion in stereo_fltr
#This is best setting to use for Antarctica
erode_px=1024
stereo_opt+=" --erode-max-size $erode_px"

#stereo tri pc error filter
#NOTE: can now apply this in point2dem
#stereo_opt+=" --max-valid-triangulation-error 8" 

#Compute triangulation error vector
#PC is a 6-band tif instead of 4-band
#stereo_opt+=" --compute-error-vector" 

if [ -z "$rpcdem" ] ; then
    #For now, hardcode the rpcdem
    #rpcdem=/nobackup/deshean/rpcdem/ned1/ned1_tiles_glac24k_115kmbuff.vrt
    #rpcdem=/nobackup/deshean/rpcdem/ned13/ned13_tiles_glac24k_115kmbuff.vrt
    #rpcdem=/nobackup/deshean/rpcdem/ned1_2003/ned1_2003_adj.vrt
    rpcdem=/nobackup/deshean/rpcdem/hma/srtm1/hma_srtm_gl1.vrt
fi

#******************************************************************

t_start=$(date +%s)
echo
uname -a
date

if [ ${PBS_JOBID:+x} ] ; then 
    echo
    echo PBS_JOBID $PBS_JOBID
    echo PBS_JOBNAME $PBS_JOBNAME
fi

echo
echo $ncpu physical CPU cores available
echo
cat /proc/cpuinfo | head -24
echo

echo
env | grep PATH

echo
which stereo
echo
stereo --version
echo

#This should force exit upon error
#Note: must come after stereo --version, which throws an error
set -e
#set -x verbose

#export PATH=${PATH}:~/src/demtools

echo "Current directory: " `pwd`
echo

cd $dir
#Set up striping for outdir that will contain large files
if $pleiades ; then
    lfs setstripe -c $ncpu .
fi

echo "Current directory: " `pwd`
echo

#This will pull out unique catalog IDs from all filenames in a dir
ids=($(dg_get_ids.py .))

if [ ${#ids[@]} -ne 2 ] ; then
    #echo "Unable to find ntf files or existing mosaics in $dir"
    echo "Incorrect number of unique ids in $dir:"
    echo ${ids[@]}
    exit 1
fi

#Want to check to make sure both ids are valid

#Mosaic and wv_correct the two ids 
#Note: this script now contains mosaicing code that used to exist here 
#Note: output ndv for mosaics is hardcoded to 0
echo ntfmos.sh 
time ntfmos.sh 

#If ntfmos was successful for both, remove corr
nr100=$(ls *r100.tif | wc -l)
if (( "$nr100" == "2" )) ; then
    if $rmfiles ; then
        if ls *corr.tif 1> /dev/null 2>&1; then
            echo "Removing corr files"
            rm -v *corr.{tif,xml}
        fi
    fi
else
    echo "Unable to find two input dg_mosaic images"
    exit
fi

#This extracts mean GSD for the mosaiced products
#Note: some older deliveries are missing MEANPRODUCT tags
if grep -q MEANPRODUCTGSD ${ids[0]}.r100.xml ; then
    res1=$(printf '%.2f' $(gettag ${ids[0]}.r100.xml 'MEANPRODUCTGSD'))
else
    res1=$(printf '%.2f' $(gettag ${ids[0]}.r100.xml 'MEANCOLLECTEDGSD'))
fi
if grep -q MEANPRODUCTGSD ${ids[1]}.r100.xml ; then
    res2=$(printf '%.2f' $(gettag ${ids[1]}.r100.xml 'MEANPRODUCTGSD'))
else
    res2=$(printf '%.2f' $(gettag ${ids[1]}.r100.xml 'MEANCOLLECTEDGSD'))
fi

echo "Input MEANPRODUCTGSD res"
echo "${ids[0]}: $res1 GSD"
echo "${ids[1]}: $res2 GSD"

#Set L to the image with higher res
#Note: bc true=1, false=0; bash true=0, false=1
#if [ $(echo "a=($res1 < $res2); a" | bc -l) ]; then
if [ $(echo "a=($res1 < $res2); a" | bc -l) -eq 1 ]; then
    imgL=${ids[0]}
    imgR=${ids[1]}
    if [ "$res" == "nat" ] ; then
        res=$res1
    fi
else
    imgL=${ids[1]}
    imgR=${ids[0]}
    if [ "$res" == "nat" ] ; then
        res=$res2
    fi
fi

#Determine proj using proj_select utility and xml
xmlL1=${imgL}.r100.xml
proj="$(proj_select.py $xmlL1)"

#Determine rpcdem
#rpcdem="$(dem_select.py $xmlL1)"

echo
mono_cdate.py .
echo

#This was the old way of assigning timestamps - works fine for along-track pairs with dt < 60-90 sec
#Extract image acquisition datetime
t=$(gettag $xmlL1 'FIRSTLINETIME')

#This is a better estimate for center time of pair uses r100 firstline, numrows and linerate
#Important for coincident stereo with time separation of hours or days
ct=$(mono_cdate.py . | grep 'Center date:' | awk -F'date: ' '{print $NF}' | sed 's/ /T/')

#SUSE date util is GNU, OS X is BSD
#http://www.gnu.org/software/coreutils/manual/html_node/Combined-date-and-time-of-day-items.html
if [ "$os" == "Linux" ] ; then
    #Note, the following assumes the input is in local time zone, regardles of Z
    #ts=$(date -d ${t%.*} '+%Y%m%d_%H%M')
    #This works correctly, with both input and output recognized as UTC
    ts=$(date -u -d "$(echo $t | sed -e 's/T/ /')" '+%Y%m%d_%H%M')
    cts=$(date -u -d "$(echo $ct | sed -e 's/T/ /')" '+%Y%m%d_%H%M')
elif [ "$os" == "Darwin" ] ; then
    #This works on OS X
    ts=$(date -j -f '%Y-%m-%dT%T' ${t%.*} '+%Y%m%d_%H%M')
    cts=$(date -j -f '%Y-%m-%dT%T' ${ct%.*} '+%Y%m%d_%H%M')
fi

stereo_arg=""

#Bundle Adjustment
if $bundle ; then
    echo
    ba_prefix="${imgL}_${imgR}_ba"
    nadjust=$(ls ${ba_prefix}*adjust | wc -l)
    if (( $nadjust >= 2 )) ; then
        echo "Found existing BA files"
    else
        echo "Performing Bundle Adjustment"
        echo
        ba_opt="-o $ba_prefix -r 100 --threads $NCPUS"
        ba_arg="${imgL}.r100.tif ${imgR}.r100.tif ${imgL}.r100.xml ${imgR}.r100.xml"
        echo bundle_adjust $ba_opt $ba_arg
        eval time bundle_adjust $ba_opt $ba_arg
    fi
    echo
    stereo_opt+=" --bundle-adjust-prefix $ba_prefix"
fi

#Map mosaiced input images using ASP mapproject
if $map ; then
    outext="_ortho"
    map_opt+=" -t rpc --nodata-value $ndv --t_srs \"$proj\""
    if $bundle ; then 
        map_opt+=" --bundle-adjust-prefix $ba_prefix"
    fi
    if [[ -n $res ]]; then
        map_opt+=" --tr $res"
        #Note: res format is %0.3f
        outext="${outext}_${res}m"
    fi
    for id in $imgL $imgR; do
        echo
        if [ ! -e ${id}${outext}.xml ] ; then
            ln -sv ${id}.r100.xml ${id}${outext}.xml
        fi
        echo
    done
    echo
    #Determine stereo intersection bbox up front from xml files
    if [ -z "$crop_extent" ] ; then
        echo "Computing intersection extent:"
        #Want to compute intersection with rpcdem as well
        map_extent=$(dg_stereo_int.py ${imgL}.r100.xml ${imgR}.r100.xml "$proj")
    else
        echo "Using user-specified crop extent:"
        map_extent=$crop_extent
        unset crop_extent
    fi
    echo $map_extent
    echo
    for id in $imgL $imgR; do
        map_arg="--t_projwin $map_extent $rpcdem ${id}.r100.tif ${id}${outext}.xml ${id}${outext}.tif"
        if [ ! -e ${id}${outext}.tif ]; then
            echo; date; echo;
            echo mapproject $map_opt $map_arg
            eval time mapproject $map_opt $map_arg
        fi
    done
    stereo_arg+=" $rpcdem"
    stereo_opt+=" --alignment-method None"

    if $bundle ; then
        echo
        echo "Updating BA files"
        ln -svf ${ba_prefix}-${imgL}.r100.adjust ${ba_prefix}-${imgL}${outext}.adjust
        ln -svf ${ba_prefix}-${imgR}.r100.adjust ${ba_prefix}-${imgR}${outext}.adjust
        echo
    fi

else
    echo; date; echo;
    outext="_nomap"
    for id in $imgL $imgR; do
        ln -svf ${id}.r100.tif ${id}${outext}.tif
        ln -svf ${id}.r100.xml ${id}${outext}.xml
    done
    stereo_opt+=" --alignment-method AffineEpipolar"
fi

#Directory for output products
outdir=dem${outext}
#outdir=dem${outext}_${spm}_${corrkernel}_${rfnekernel}_${erode_px}

if [ ! -d $outdir ]; then
    mkdir -pv $outdir
fi

#Set up striping for outdir that will contain large files
if $pleiades ; then
    lfs setstripe -c $ncpu $outdir
fi

#Hack to replace existing timestamp
out=$outdir/${ts}_${imgL}_${imgR}
if [ "$ts" != "$cts" ] ; then
    if [[ -n $(find . -name ${ts}_${imgL}_${imgR}*) ]] ; then
        echo "Found existing products with old timestamp format"
        echo "Updating timestamp from $ts to $cts"
        filelist=$(find . -name ${ts}_${imgL}_${imgR}*)
        for f in $filelist
        do
            mv -v $f $(echo $f | sed "s/${ts}/${cts}/")
        done
    fi
    out=$outdir/${cts}_${imgL}_${imgR}
fi

#Want to prepend new args, so rpcdem is last
stereo_arg="${imgL}${outext}.tif ${imgR}${outext}.tif ${imgL}${outext}.xml ${imgR}${outext}.xml $out $stereo_arg"

if [ -e ${out}-DRG.tif ]; then
    echo "Existing DEM/DRG found"
    exit 0
fi

#This is used to rerun refinement on subwindow without starting from scratch
if [ -n "$crop_extent" ] ; then
    window=$(extent_proj2px.py ${imgL}${outext}.tif $crop_extent)
    echo
    echo "Using user-specified crop extent: $crop_extent"
    echo "Corresponding L window: $window"
    echo
    stereo_opt+=" --left-image-crop-win $window"
    #Note: this won't work, as the --left-image-crop-win preserves original dimensions
    #just writes nodata to area outside specified window
    if [ -e ${out}-RD.tif ] ; then
        rd_dim=$(gdalinfo ${out}-RD.tif | grep 'Size is' | sed 's/,//')
        w_dim=$(echo $window | awk '{print $3 " " $4}')
        if [ "$rd_dim" != "$w_dim" ] ; then
            #NOTE: only run if existing RD is different size than specified window
            echo
            echo bayes_prep
            #bayes_prep.sh .
            echo
        fi
    fi
fi

#Set entry point appropriately based on contents of outdir
if [ -e ${out}-PC.tif ]; then
    e=5
elif [ -e ${out}-F.tif ]; then
    e=4
elif [ -e ${out}-RD.tif ]; then
    e=3
elif [ -e ${out}-D.tif ]; then
    e=2
elif [ -e ${out}-R_sub.tif ]; then
    e=1
else
    e=0
fi

#pstereo_opt=""
##pstereo_opt+=" --nodes-list $PBS_NODEFILE"
#pstereo_opt+=" --processes $NCPUS" 
##pstereo_opt+=" --threads-multiprocess $NCPUS"
#pstereo_opt+=" --threads-multiprocess 1"
#pstereo_opt+=" --threads-singleprocess $NCPUS"

#Run stereo with entry point
if [ "$e" -lt "5" ]; then
    echo; date; echo;
    echo stereo -e $e $stereo_opt $stereo_arg; echo
    eval time stereo -e $e $stereo_opt $stereo_arg 
    #echo parallel_stereo -e $e $pstereo_opt $stereo_opt $stereo_arg; echo
    #eval time parallel_stereo -e $e $pstereo_opt $stereo_opt $stereo_arg 
fi

base_dem_opt+="--nodata-value $dem_ndv"
base_dem_opt+=" --remove-outliers --remove-outliers-params 75.0 3.0"

#Median filter, window size and dz threshold
#base_dem_opt+=" --median-filter-params 11 40"
#base_dem_opt+=" --search-radius-factor 1"

#Rounding error precision - default is 1/1024, or ~1 mm
#1/256
#base_dem_opt+=" --rounding-error 0.00390625"
#1/128
#base_dem_opt+=" --rounding-error 0.0078125"
#1/64
#base_dem_opt+=" --rounding-error 0.015625"

#Note: point2dem doesn't seem to use more than ~400% CPU
if $parallel_point2dem ; then
    base_dem_opt+=" --threads 4"
    cmd_list=''
else
    base_dem_opt+=" --threads $NCPUS"
fi

base_dem_opt+=" --t_srs \"$proj\""

#Output multiple DEM resolutions
for dem_res in 2 8 32
do
    if [ ! -e ${out}-DEM_${dem_res}m.tif ]; then
        dem_opt="$base_dem_opt"
        dem_opt+=" --tr $dem_res"
        dem_opt+=" -o ${out}_${dem_res}m"
        #Generate low-res Intersection Error
        if $error ; then
            if [ ! -e ${out}_${dem_res}m-IntersectionErr.tif ]; then
                dem_opt+=" --errorimage"
            fi
        fi
        echo; date; echo;
        echo point2dem $dem_opt ${out}-PC.tif
        echo
        if $parallel_point2dem ; then
            cmd=''
            cmd+="time point2dem $dem_opt ${out}-PC.tif; "
            cmd+="mv ${out}_${dem_res}m-DEM.tif ${out}-DEM_${dem_res}m.tif; "
            #Absolute difference filter to remove outliers relative to rpcdem
            if [ -n "$rpcdem" ] ; then
                cmd+="filter.py ${out}-DEM_${dem_res}m.tif -filt dz -param $rpcdem -200 200; "
            fi
            #Shaded relief map
            #cmd+="gdaldem hillshade ${out}-DEM_${dem_res}m.tif ${out}-DEM_${dem_res}m_hs.tif"
            cmd_list+=\ \'$cmd\'
        else
            eval time point2dem $dem_opt ${out}-PC.tif
            mv ${out}_${dem_res}m-DEM.tif ${out}-DEM_${dem_res}m.tif
        fi
    fi
done

if $parallel_point2dem ; then
    #For wes nodes, limit to 2 jobs to avoid memory issues
    if (( $NCPUS > 15 )) ; then
        njobs=3
    else
        njobs=2
    fi
    eval parallel -verbose -j $njobs ::: $cmd_list
fi

#Full-res orthoimage output options
dem_opt="$base_dem_opt"
#We dont ever actually use the full-res DEM
dem_opt+=" --no-dem"
#Note: the computed point2dem resolution is sometimes much higher than this input res
dem_opt+=" --tr $res"
#Write out DRG
if $drg ; then
    #Hole filling slows things down considerably
    dem_opt+=" --orthoimage-hole-fill-len 256"
    #dem_opt+=" --orthoimage-hole-fill-len 1024"
    #Note: now need to specify PC.tif before L.tif
    dem_opt+=" ${out}-PC.tif"
    #Note: texture dimensions must match PC dimensions, use -L.tif (ok if mapped)
    if $map ; then
        #This is float32, but has original values, not normalized
        dem_opt+=" --orthoimage ${imgL}${outext}.tif"
        prefix=${out}_${imgL}${outext}
    else
        #This is float32, normalized, more work to return to original values
        dem_opt+=" --orthoimage ${out}-L.tif"
        prefix=${out}_L
    fi
    dem_opt+=" -o $prefix"
    #Create full-res DRG from PC
    if [ ! -e ${prefix}-DRG.tif ]; then
        echo; date; echo;
        echo point2dem $dem_opt 
        echo
        eval time point2dem $dem_opt 
        if [ ! -e ${prefix}-DRG_11b.tif ] ; then
            if $map ; then
                gdal_translate $gdal_opt -ot UInt16 -a_nodata $ndv ${prefix}-DRG.tif ${prefix}-DRG_11b.tif
            else
                #Default is 2.0 and 98.0%
                #Get original stats
                #perc=($(getperc.py ${prefix}-DRG.tif))
                orig_mm=($(gdal_stats.sh ${imgL}${outext}.tif))
                L_mm=($(gdal_stats.sh ${prefix}-DRG.tif))
                gdal_translate $gdal_opt -ot UInt16 -scale ${L_mm[0]} ${L_mm[1]} ${orig_mm[0]} ${orig_mm[1]} \
                -a_nodata $ndv ${prefix}-DRG.tif ${prefix}-DRG_11b.tif 
            fi
            #gdaladdo_ro.sh ${prefix}-DRG_11b.tif
        fi
    fi
    #Now downsample and reduce to 8-bit
fi

#mdenoise, or other DEM filtering

echo "Generating 16-bit orthoimage from nadir ID"
ortho_proc.sh .
#rm ${imgL}${outext}.tif ${imgR}${outext}.tif ${imgL}${outext}.xml ${imgR}${outext}.xml 

#Clean up unnecessary files
if $rmfiles ; then
    echo; echo "Removing intermediate files"
    #for i in PC F L R RD D; do
    for i in PC F RD; do
        if [ -e ${out}-${i}.tif ]; then
            rm -v ${out}-${i}.tif
        fi
    done
fi

if $compress ; then
    echo; date; echo;
    echo "Compressing all .tif files"
    time parallel gdal_compress.sh ::: $(find . -name '*.tif')
    echo
fi

t_end=$(date +%s)
t_diff=$(expr $t_end - $t_start)
t_diff_hr=$(printf '%0.4f' $(echo "$t_diff/3600" | bc -l))

echo
date
echo; echo "Total wall time (hr): $t_diff_hr"
echo
