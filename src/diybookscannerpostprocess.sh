#!/bin/bash

# diybookscannerpostprocess.sh -- 
#
# Copyright (C) 2014 Gerard Choinka
# All rights reserved.
#
# This software may be modified and distributed under the terms
# of the BSD license.  See the LICENSE file for details.

echo $0" [path] <skipuser|skipprocess>"

[ -d "$1" ] || echo "argument 1 has to be a directory"
[ -d "$1" ] || exit 1

export workDir="$1"

imagej_opt="--no-splash"

test -d "$workDir/info/" ||  mkdir "$workDir/info/"
test -d "$workDir/info/logs" ||  mkdir "$workDir/info/logs"


THIS_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
IJ=~/opt/Fiji.app/ImageJ.sh


if [[ "$2" != "skipuser" ]]; 
then 
    python "$THIS_DIR/bsw_run.py" "$workDir"
fi

if [[ "$2" != "skipprocess" ]];
then 

    for f in lef rig a4h
    do 
      $IJ $imagej_opt -- -batch "$THIS_DIR/bsw_rotate-fixplattern.ijm" "$workDir/links/$f/book.bsw" 
    done


    $IJ $imagej_opt -- -batch "$THIS_DIR/norm_light.ijm" "$workDir"

    $IJ $imagej_opt -- -batch "$THIS_DIR/whiteup.ijm" "$workDir"


    export thisDir=$PWD
    cd "$workDir/result"
    export thisName=$(basename "$workDir") 
    for f in sw170 sw300 gr170 gr300
    do 
      cd $f 
      mkdir tmp 
      for k in image*; 
      do 
	sam2p -j:quiet "$k" "tmp/$k.pdf"; 
	echo $k; 
      done ;
      pdftk ./tmp/*.pdf cat output "../../$thisName-$f.pdf" 
      cd ..  
    done
    cd "$thisDir"



    rm "$workDir/tmp" "$workDir/result/norm" "$workDir/result/gr300" "$workDir/result/sw300" "$workDir/result/gr170" "$workDir/result/sw170" "$workDir/result/white" -rf

    mv "$workDir/result" "$workDir/raw_croped"

    cd "$workDir/raw_croped"
    find . -maxdepth 1 -iname "image*.tif"  -exec sam2p -j:quiet "{}" "{}.jpg" \; -exec rm "{}" \;
    find . -maxdepth 1 -iname "image*.tiff" -exec sam2p -j:quiet "{}" "{}.jpg" \; -exec rm "{}" \;
    cd "$thisDir"

    mv "$workDir/links" "$workDir/info/"
fi
