#!/bin/bash
# apply_hald.sh
## Usage:  apply_hald.sh  SBSPATH  HALDROOTDIR  HALDGLOB  OUTDIR

#### --------- Examples assume $IMC is set according to the computer -------
#### Example 1:  export IMAGEMAGICK_CONVERT_OR_MAGICK=$IMC;    Scripts/apply_hald.sh  INP/Lenna_3D__imgonline-com.png INP/HALD  "*_ahg_*.TIF"  TMP/APPLY_OUT
#### Example 2:  export IMAGEMAGICK_CONVERT_OR_MAGICK=$IMC;  HALDROOTDIR="INP/HALD";  HALDGLOB="hald__ahg_*_16.TIF";  OUTDIR=TMP/CMP6;   Scripts/apply_hald.sh    $HALDROOTDIR  $HALDGLOB  $OUTDIR


if [ "$#" == 0 ]; then
    echo "Usage:  export IMAGEMAGICK_CONVERT_OR_MAGICK=<Path-Of-ImageMagick-magick-Or-convert-Utility>;    apply_hald.sh  <Path-Of-Input-Side=By-Side-Stereopair>  <Path-Of-Root-Directory-With-Hald-LUTs>  <Glob-Pattern-For-Hald-File-Names>  <Path-Of-Output-Directory>  <Output-SBS-or-ANAglyph>"
    echo "---------------------------------"
    echo "Example - convert with all Anahald sample LUTs:  IMAGEMAGICK_CONVERT_OR_MAGICK=/c/Program\ Files/Imagemagick_711_3/magick.exe;    /c/Oleg/GitWork/AnaHald/Scripts/apply_hald.sh  INP/Lenna_3D__imgonline-com.png INP/HALD  \"*_ahg_*.TIF\"  TMP/APPLY_OUT  ANA"
    echo "---------------------------------"
    echo " >> Optionally consider overriding ChooseGammaForHald() function !"
    echo " >> Search for 'ChooseGammaForHald' to find example in its right place"
    echo "---------------------------------"
    exit 255
fi

if [ "$#" -ne 5 ]; then
    echo "---------------------------------"
    echo "-E- Illegal number of parameters."
    echo "-E- Run without parameters to obtain help"
    echo "---------------------------------"
    exit 255
fi

# request environment variable for ImageMagick convert/magick utility
if [[ -z "${IMAGEMAGICK_CONVERT_OR_MAGICK}" ]]; then
    IMC=magick  # IMAGEMAGICK_CONVERT_OR_MAGICK undefined; use the new default"
    echo "-W- Path of ImageMagick convert/magick utility isn't given as IMAGEMAGICK_CONVERT_OR_MAGICK; using default of '$IMC'"
else
    IMC=${IMAGEMAGICK_CONVERT_OR_MAGICK}
    echo "-I- Path of ImageMagick convert/magick utility is given explicitly as IMAGEMAGICK_CONVERT_OR_MAGICK: '$IMC'"
fi

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source $SCRIPT_DIR/utils_anahald.sh
#### <<<<<<<<<<<< IF NEEDED, REDEFINE ChooseGammaForHald FUNCTION >>>>>>>>>>>>>>
#### <<<<<<<<<<<< PLACE HERE - AFTER 'source $SCRIPT_DIR/utils_anahald.sh'>>>>>>
#### __________________________________________
#### Example:
#### ChooseGammaForHald ()  {
####     if [[ "$1" =~ ahg_oleg_ec ]]; then
####         echo 0.94
####     else
####         ChooseGammaForAnahaldSampleHald $1
####     fi
#### }
#################################################################################


SBSPATH=$1;  HALDROOTDIR=$2;  HALDGLOB=$3;  OUTDIR=$4;  OUTSBSORANA=$5

_DESCR="Anahald $OUTSBSORANA conversions of SBS image '$SBSPATH' with all HALD-LUTs matching '$HALDGLOB' located under '$HALDROOTDIR'; output directory '$OUTDIR'"

echo "-I- ==== Begin  $_DESCR ===="
if   [[ $(echo "$OUTSBSORANA" | tr '[:lower:]' '[:upper:]') == "SBS" ]]; then
    echo "-I- Will convert SBS to color-processed SBS"
    Apply_All_Anahald_LUTs   $SBSPATH  $HALDROOTDIR  $HALDGLOB  $OUTDIR
elif [[ $(echo "$OUTSBSORANA" | tr '[:lower:]' '[:upper:]') == "ANA" ]]; then
    echo "-I- Will convert SBS to color-processed anaglyph"
    Make_All_Anaglyph_Types  $SBSPATH  $HALDROOTDIR  $HALDGLOB  $OUTDIR
else
    echo "-E- ==== Unknown output type '$OUTSBSORANA'; should be SBS or ANA ===="
    exit 255
fi
if [ $? -ne 0 ];  then 
    echo "-E- ==== Failed $_DESCR ===="
    exit 255
fi
echo "-I- ==== Done   $_DESCR ===="
exit 0
