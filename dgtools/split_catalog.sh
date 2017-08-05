#! /bin/bash

#David Shean
#dshean@gmail.com

#Utility to split DG catalog shp into useful divisions spatially and temporally

set -x

#Cloud cover percentage filter
cloud=25

inshp=$1
#lyr=${inshp%.*}
#Note: if input is ESRI GDB, need to specify layer
#lyr=dg_imagery_index_stereo_antarctica
#US gdb
#lyr=dg_archive_index_2016jul07_US_stereo
#lyr=dg_archive_index_2016jul07_US_all
#Global gdb
#lyr=dg_imagery_index_stereo
#lyr=dg_imagery_index_all
#lyr=dg_imagery_index_stereo_cc20
lyr=dg_imagery_index_all_cc20


#ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'CLOUDCOVER' < $cloud" ${inshp%.*}_${lyr}_CC${cloud}.shp $inshp
#shp=${inshp%.*}_${lyr}_CC${cloud}.shp
#lyr=${shp%.*}

#HMA
proj='EPSG:4326'
#proj='+proj=longlat +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +no_defs '
wkt='POLYGON ((66 47, 106 47, 106 25, 66 25, 66 47))'

shp=$inshp
ogr2ogr -progress -overwrite -clipsrc "$wkt" ${shp%.*}_HMA.shp $shp

exit

#Nov 1
#Late sept to Late dec

shp=${shp%.*}_HMA.shp
lyr=${shp%.*}
#UTM Zone 44N
#proj='EPSG:32644'
#ogr2ogr -t_srs $proj -progress -overwrite ${shp%.*}_32644.shp $shp
#shp=${shp%.*}_32644.shp 

#Split into geocells and smaller targets
#This should include WV3 images, 110x13km
area_cutoff=1300
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'sqkm' >= '$area_cutoff'" ${shp%.*}_geocell.shp $shp
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'sqkm' < '$area_cutoff'" ${shp%.*}_smallarea.shp $shp

exit

#EPSG:3031
proj='+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs '

ogr2ogr -t_srs "$proj" -overwrite -sql "SELECT * from $lyr WHERE 'y1' < 0" ${inshp%.*}_S.shp $inshp

shp=${inshp%.*}_S.shp
lyr=${shp%.*}

#Add WA/OR polygons

wkt='POLYGON ((-2666256.99705614708364 2010022.519967337138951,-2323610.209778512828052 1790211.37341187428683,-2142589.265556366182864 1466959.687300898134708,-1709432.006167659070343 1195428.270967679098248,-1327995.0165567076765 1027337.394189971499145,-1030603.465334610082209 1156638.068634361494333,-972418.161834634374827 1273008.675634312443435,-888372.723445781040937 1686770.833856361918151,-571586.071057024877518 2255693.801411679014564,-99638.609335000161082 2436714.745633824728429,495144.4931091950275 2352669.307244971394539,1258018.472331097815186 2158718.295578385703266,2085542.788775194901973 1867791.778078507632017,2331214.070219536777586 1596260.361745288595557,2783766.430774902459234 451949.39291243487969,2964787.374997049104422 -356179.822365004569292,2538095.149330560583621 -1345329.981864589964971,2053217.620164097752422 -2101738.927364272996783,1367924.045608828309923 -2366805.309975272975862,663235.369886902160943 -2276294.837864199653268,217148.043053755536675 -2108203.961086492519826,171892.80699821934104 -1888392.814531028969213,61987.233720487449318 -1571606.162142272805795,-190149.081446073483676 -1487560.723753419239074,-494005.666390390601009 -1474630.656308980192989,-862512.588556902948767 -1468165.622586760669947,-1580131.331723268842325 -1254819.509753516875207,-2090868.995778610231355 -614781.171253785025328,-2194309.535334122367203 -310924.586309467907995,-2045613.759723073802888 -7068.001365150790662,-2181379.467889683321118 367903.954523581080139,-2336540.277222951874137 710550.741801215335727,-2743837.401722781360149 1201893.30468989815563,-2789092.637778317555785 1647980.631523044779897,-2666256.99705614708364 2010022.519967337138951))'

ogr2ogr -progress -overwrite -clipsrc "$wkt" ${lyr}_Ant.shp $shp

#Split south into years

shp=${lyr%.*}_Ant.shp
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

#Split north into years
lyr=${inshp%.*}

proj='+proj=stere +lat_0=90 +lat_ts=70 +lon_0=-45 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs '
ogr2ogr -t_srs "$proj" -overwrite -sql "SELECT * from $lyr WHERE 'y1' > 0" ${inshp%.*}_N.shp $inshp

#Want to clip to Greenland
shp=${inshp%.*}_N.shp
lyr=${shp%.*}

#clipshp='Gr_clipping_mask_3413.shp'
#ogr2ogr -progress -overwrite -clipsrc $clipshp ${lyr}_Gr.shp $shp

#wkt='POLYGON ((-32.694905108744983 84.201167733184022,-20.011322422385074 83.271943323020025,-17.038021468676735 82.458738786108171,-9.715540211338137 82.001028136722709,-11.702650720346494 80.325531495020215,-15.535281637929373 79.471528456774351,-15.638756683872238 77.506285228361733,-16.272020200277364 75.918195374455507,-15.946877696066538 74.684930307823237,-20.232063093134016 72.445828279975871,-20.317933078028354 70.428606968405717,-21.483863944527382 69.349963208850809,-25.195641378554367 68.352426471907222,-31.198029976873755 67.558646004577596,-34.87678958614346 65.47168799013545,-38.753037910818421 64.733581624574143,-41.308006551591042 62.197932690444176,-41.635831181801599 60.739096772891784,-42.41733865129774 59.41107015598481,-44.096895168357733 59.153335981655978,-47.206663788458265 59.901178734453147,-49.088594004514604 60.671442964366896,-50.681347687357608 61.857195723492772,-52.93701977723223 63.828147234641058,-54.212932442683289 65.506815680568678,-54.863935547383036 68.43829316186266,-56.268992872670282 70.05206485269693,-58.016001061095714 73.158342297436448,-59.626906673680942 74.783190681782344,-61.867318695053953 75.607666243613465,-66.829107923673902 75.398125355709965,-70.914822739410567 75.791240814240098,-70.762825834274281 76.133391585652859,-73.519825587812775 76.600464563994038,-73.685620470945992 77.680300038022111,-73.292225519906978 78.348883210132811,-70.227656205636976 79.008215856347618,-67.164973839924585 79.468567560776975,-67.68509994127875 80.205025264578921,-67.006866712457651 80.774193708576092,-63.304545751989544 81.31789231679187,-60.47357867485767 81.956865920100171,-54.241287354904024 82.746099300462021,-43.361276561391549 83.734803037204031,-32.694905108744983 84.201167733184022))'

#Note: clipsrc CRS must be identical to input shape (EPSG:3413 here)
wkt='POLYGON ((133984.063661193213193 -614243.978193692513742,308227.296400783467107 -661336.743798988405615,383575.721369257662445 -722557.33908587647602,501307.635382495820522 -708429.509404289536178,576656.060350986546837 -877963.46558337949682,562528.230669414508156 -995695.379596650484018,666132.315001019858755 -1184066.442017753142864,736771.463408961426467 -1344181.845075754215941,810301.333737556939013 -1458631.25906087923795,802701.335256373859011 -1739761.076160228112713,893686.063136181095615 -1944615.86713799997233,901963.114925615955144 -2072776.596103509189561,803722.589299503248185 -2231892.635139946825802,587189.009367592516355 -2390250.630228076130152,474001.781751109694596 -2654801.223792370874435,302556.282302263600286 -2763975.87579041114077,197676.757974687207025 -3063484.217341335024685,189995.625585118395975 -3232131.097440743818879,152821.169903319008881 -3388007.872345710173249,53926.362132195376034 -3420972.808269428554922,-128395.795261976352776 -3332134.035728873219341,-231401.986147261486622 -3237260.761447335593402,-307774.756245341908652 -3093695.793882640544325,-398164.187678640242666 -2855859.62100575491786,-431129.123602344130632 -2658070.005463495384902,-404729.356689314125106 -2327644.167167083825916,-426419.847041810920928 -2140049.583805234637111,-413764.508718467026483 -1789930.233899801969528,-418624.428051582421176 -1604035.488368177087978,-454675.506404986663256 -1499587.971573226153851,-591244.526660339790396 -1476041.588770578149706,-676011.50474987027701 -1391274.610681048361585,-655973.984192175325006 -1359197.185377059970051,-696102.827327278442681 -1281004.67915430245921,-642973.055562894558534 -1175114.360339610604569,-600198.805920488783158 -1115052.587716646259651,-508999.181533881579526 -1080324.463941388530657,-431577.700166033697315 -1059399.683444211259484,-410175.446083954826463 -981272.674140823772177,-375273.995033053215593 -928515.329650867613964,-295927.379230524878949 -894563.650303149945103,-232822.293302118603606 -841035.917707448243164,-126354.88025190155895 -776592.386361059383489,19427.285108420761389 -679063.890073983813636,133984.063661193213193 -614243.978193692513742))'

ogr2ogr -progress -overwrite -clipsrc "$wkt" ${lyr}_Gr.shp $shp

#Split into geocells and smaller targets
area_cutoff=1000
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'SQKM' >= '$area_cutoff'" ${lyr}_geocell.shp $shp
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'SQKM' < '$area_cutoff'" ${lyr}_smallarea.shp $shp

shp=${lyr}_Gr.shp
lyr=${shp%.*}

t1='2008-01-01'
t2='2008-12-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2009-01-01'
t2='2009-12-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2010-01-01'
t2='2010-12-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2011-01-01'
t2='2011-12-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2012-01-01'
t2='2012-12-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2013-01-01'
t2='2013-12-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2014-01-01'
t2='2014-12-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 

t1='2015-01-01'
t2='2015-12-31'
ogr2ogr -overwrite -sql "SELECT * from $lyr WHERE 'ACQDATE' >= '$t1' AND 'ACQDATE' <= '$t2'" ${lyr}_${t1}_${t2}.shp $shp 
