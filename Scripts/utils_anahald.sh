# utils_anahald.sh

# The functions here may depend on environment variables:
# ########## Linux-ASUS ##############
# IMC="convert"                                         # for Linux-ASUS
# IMI="identify"                                        # for Linux-ASUS
# SBSROOT=~/ANY/GitWork/AnaHald/INP/Anaglyph_RR_1080    # for Linux-ASUS
# cd ~/ANY/GitWork/AnaHald/                             # for Linux-ASUS
# ########## Windows-DT2022 ##########
# IMC="/c/Program Files/Imagemagick_711_3/magick.exe"   # for Windows-DT2022
# IMI="/c/Program Files/Imagemagick_711_3/identify.exe" # for Windows-DT2022
# SBSROOT=/D/Photo/Anaglyph_RR/ORIG                     # for Windows-DT2022
# ## !!! DO use clean SBSROOT  ^^^^ !!!
# cd /d/Work/RMA_WA                                     # for Windows-DT2022
# ####################################

##ANA_EXTENSION="PNG"
##OUT_PROP=""
ANA_EXTENSION="JPG"
OUT_PROP="-quality 90"

# HALDDIR="INP/HALD"

# CHOICEDIR=OUT/Anaglyph_RR/DEMO/CHOICE

# OUTDIR="TMP"
#################################################################################



#################################################################################
# Provides gamma value by printing it on the screen.
#### <<<<<<<<<<<   IF NEEDED, REDEFINE ChooseGammaForHald FUNCTION >>>>>>>>>>>>>>
#### Example (!!!  PLACE AFTER 'source $SCRIPT_DIR/utils_anahald.sh'  !!!):
#### ChooseGammaForHald ()  {
####     if [[ "$1" =~ ahg_oleg_ec ]]; then
####         echo 0.94
####     else
####         ChooseGammaForAnahaldSampleHald $1
####     fi
#### }
#################################################################################
# Call syntax:  gammaVal=$(ChooseGammaForAnahaldSampleHald HALDNAME_OR_EMPTY)
#################################################################################
ChooseGammaForHald ()  {
    local _haldFileNameOrEmpty=$(basename -- $1 "__16.TIF")
    
    ChooseGammaForAnahaldSampleHald $1
}
#################################################################################


#################################################################################
# Call syntax:  gammaVal=$(ChooseGammaForAnahaldSampleHald HALDNAME_OR_EMPTY)
ChooseGammaForAnahaldSampleHald ()  {
    local _haldFileNameOrEmpty=$(basename -- $1 "__16.TIF")
    local _haldPrefixOrEmpty=`echo "$_haldFileNameOrEmpty" |sed "s/__[0-9]*\././"`

    ##if [[ $_haldFileNameOrEmpty == "" ]];  then
    if [[ $1 == "" ]];  then
        echo "1.0"
        return
    fi
    
    declare -A haldPrefixToGamma
    
    #haldPrefixToGamma[""]=1.0
    haldPrefixToGamma["hald__ahg_oleg_cp"]=1.0
    haldPrefixToGamma["hald__ahg_oleg_mc"]=1.0
    haldPrefixToGamma["hald__ahg_oleg_gp"]=1.0
    haldPrefixToGamma["hald__ahg_oleg_ec"]=0.9
    haldPrefixToGamma["hald__ahg_oleg_xc"]=0.88
    haldPrefixToGamma["hald__ahg_oleg_sf"]=0.88
    
    echo ${haldPrefixToGamma[$_haldPrefixOrEmpty]}
    #echo $_haldPrefixOrEmpty
}


#################################################################################
## Converts SBS to color-processed anaglyph
#### Supports automatic choice of gamma per hald
## Call syntax:  Run_SBS_to_ANA <sbsPath> <outPath> <haldPathOrEmpty> <gamma>
## ===  "$IMC"  $sbsPath  -gamma 1.0  $HALD -hald-clut  -crop 50%x100% -swap 0,1 -   define compose:args=20 -compose stereo -composite  -depth 8 -quality 90  $imgAdd
## Example:  Run_SBS_to_ANA  INP/Lenna_3D__imgonline-com.png  TMP/TMP_OUT.jpg  INP/HALD/hald__ahg_oleg_cp__16.TIF  "AUTO"
Run_SBS_to_ANA() {
  local _sbsName=$(basename -- $1 "")
  local _anaName=$(basename -- $2 "")
  local _haldNameOrEmpty=""
  local _haldParam=""
  local _gm=$4
  echo "-I- Entered: \nRun_SBS_to_ANA  '$1'  '$2'  '$3'  '$4'"
  if [[ $3 != "" ]]; then _haldParam="$3 -hald-clut";  fi
  if [[ $3 != "" ]]; then _haldNameOrEmpty=$(basename -- $3 "");  fi
  if [[ "$(echo "$_gm" | tr '[:lower:]' '[:upper:]')" == "AUTO" ]]; then
      _gm=$(ChooseGammaForHald $_haldNameOrEmpty)
      echo "-I- Auto-picked GAMMA value of $_gm for HALD '$_haldNameOrEmpty'"
  fi
  ##local _comment="sbsName: '$_sbsName'  anaName: '$_anaName'  haldFile: '$_haldNameOrEmpty'  gamma: '$_gm'"
  local _comment="Red-cyan anaglyph '$_anaName' (source: '$_sbsName') optimized using CLUT from Anaglyph HALD Generator;  haldFile: '$_haldNameOrEmpty'  gamma: $_gm"
  ##echo ">>> Comment is  '$_comment'"
  "$IMC"  "$1"  -gamma $_gm  $_haldParam  -crop 50%x100% -swap 0,1 -define compose:args=20 -compose stereo -composite  -set comment "$_comment"  -depth 8 $OUT_PROP  "$2"
  #### !!! No more code - PRESERVE EXIT STATUS OF THE COMMAND ITSELF !!!
}


## Color-processes SBS stereopair with HALD CLUT.
##   ( This function is a stripped-down version of Run_SBS_to_ANA() )
#### Supports automatic choice of gamma per hald
## Call syntax:  Run_Apply_Hald_to_SBS <sbsPath> <outPath> <haldPathOrEmpty> <gamma>
Run_Apply_Hald_to_SBS() {
  local _sbsName=$(basename -- $1 "")
  local _preName=$(basename -- $2 "")
  local _haldNameOrEmpty=""
  local _haldParam=""
  local _gm=$4
  echo "-I- Entered: \nRun_Apply_Hald_to_SBS  '$1'  '$2'  '$3'  '$4'"
  if [[ $3 != "" ]]; then _haldParam="$3 -hald-clut";  fi
  if [[ $3 != "" ]]; then _haldNameOrEmpty=$(basename -- $3 "");  fi
  if [[ "$(echo "$_gm" | tr '[:lower:]' '[:upper:]')" == "AUTO" ]]; then
      _gm=$(ChooseGammaForHald $_haldNameOrEmpty)
      echo "-I- Auto-picked GAMMA value of $_gm for HALD '$_haldNameOrEmpty'"
  fi
  ##local _comment="sbsName: '$_sbsName'  anaName: '$_preName'  haldFile: '$_haldNameOrEmpty'  gamma: '$_gm'"
  local _comment="SBS stereopair '$_preName' (source: '$_sbsName') optimized using CLUT from Anaglyph HALD Generator;  haldFile: '$_haldNameOrEmpty'  gamma: $_gm"
  ##echo ">>> Comment is  '$_comment'"
  "$IMC"  "$1"  -gamma $_gm  $_haldParam  -set comment "$_comment"  -depth 8 $OUT_PROP  "$2"
  #### !!! No more code - PRESERVE EXIT STATUS OF THE COMMAND ITSELF !!!
}


## Performs CLUT application for all HALD-s under HALD root-dir.
## Call syntax:  Apply_All_Anahald_LUTs <inpSBS> <haldRootDir> <haldPattern> <outDir>
#### Example:  HALDROOTDIR="INP/HALD";  HALD_GLOB="hald__ahg_*_16.TIF";  OUTDIR=TMP/CMP6;    Apply_All_Anahald_LUTs INP/Lenna_3D__imgonline-com.png  $HALDROOTDIR  $HALD_GLOB  $OUTDIR
Apply_All_Anahald_LUTs()  {
    Make_All_Hald_Conversions  0  $@
}


## Makes anaglyphs for all HALD-s under HALD root-dir.
## Call syntax:  Make_All_Anaglyph_Types <inpSBS> <haldRootDir> <haldPattern> <outDir>
#### Example:  HALDROOTDIR="INP/HALD";  HALD_GLOB="hald__ahg_*_16.TIF";  OUTDIR=TMP/CMP6;    Make_All_Anaglyph_Types INP/Lenna_3D__imgonline-com.png  $HALDROOTDIR  $HALD_GLOB  $OUTDIR
Make_All_Anaglyph_Types()  {
    Make_All_Hald_Conversions  1  $@
}


## Makes CLUT-processed SBS-s or anaglyphs for all HALD-s under HALD root-dir
## Call syntax:  Make_All_Anaglyph_Types <doAnaglyph> <inpSBS> <haldRootDir> <haldPattern> <outDir>
#### Example:  HALDROOTDIR="INP/HALD";  HALD_GLOB="hald__ahg_*_16.TIF";  OUTDIR=TMP/CMP6;    Make_All_Anaglyph_Types INP/Lenna_3D__imgonline-com.png  $HALDROOTDIR  $HALD_GLOB  $OUTDIR
Make_All_Hald_Conversions()  {
  local _doAnaglyph=$1
  local _inpSBS=$2
  local _haldRootDir=$3
  local _haldPattern=$4
  local _outDir=$5
  # local _knownHaldOrder="_cp _mc _gp _ec _xc _sf"
  ##echo ">>> _inpSBS='$_inpSBS'  _haldRootDir='$_haldRootDir'  _haldPattern='$_haldPattern'  _outDir='$_outDir'"
  mkdir -p $_outDir

  local _allHALDs=`find $_haldRootDir -name "$_haldPattern"`  # !! undefined order !!
  if [[ $? -ne 0 || -z "$_allHALDs" ]];  then 
      echo "-E- ==== Failed locating HALD-s to apply (root-dir='$_haldRootDir', name-pattern='$_haldPattern' ===="
      exit 255
  fi
  ## if [ -z "${VAR}" ];
  ##echo ">>> HALDs to apply: " $_allHALDs
  for HALD in ${_allHALDs}
  do
      haldName=$(basename -- $HALD "__16.TIF");  haldSuff=`echo $haldName |sed -e 's/^hald__//'`
      anaName=$(basename -- $_inpSBS ".TIF")_${haldSuff}__FCA.$ANA_EXTENSION
      sbsName=$(basename -- $_inpSBS ".TIF")_${haldSuff}__SBS.$ANA_EXTENSION
      if [[ $_doAnaglyph != 0 ]];  then
          outPath=${OUTDIR}/${anaName}
          Run_SBS_to_ANA        $_inpSBS $outPath $HALD "AUTO"
      else
          outPath=${OUTDIR}/${sbsName}
          Run_Apply_Hald_to_SBS $_inpSBS $outPath $HALD "AUTO"
      fi
      if [ $? -ne 0 ];  then 
          echo "-E- ==== Failed applying HALD '$HALD' ===="
          exit 255
      fi
      echo '->' "$haldName" ' -> '  "$outPath"
  done
  ### DO NOT:  exit 0
}
# TODO: debug it !!!
#################################################################################


## Prints important environment variables
Report_Settings_For_Demo()  {
  _PX="-- Environment:"
  echo -e "${_PX} IMC=\"$IMC\"\n${_PX} SBSROOT=\"$SBSROOT\""
  echo -e "${_PX} HALDDIR=\"$HALDDIR\"\n${_PX} CHOICEDIR=\"$CHOICEDIR\""
  echo -e "${_PX} OUTDIR=\"$OUTDIR\""                            #${_PX} =\"$\"
  echo -e "${_PX} _DEBUG_annotateCmd=\"$_DEBUG_annotateCmd\""    #${_PX} =\"$\"
  ####echo -e "${_PX} =\"$\"${_PX} =\"$\""
}


## Reads comment from image 'srcFile'
## Call syntax:  res="$(Read_Image_Comment  <srcFile>)"
Read_Image_Comment()  {
  local _srcFile="$1"
  local _commentPref="comment:"
  local _commentLine=`"$IMI" -verbose $_srcFile |grep "$_commentPref"`
  local _commentStr=$(echo $_commentLine | sed -e "s/^$_commentPref//")
  #echo ">>>> Comment being read is: '""$_commentStr""' <<<<"
  echo "$_commentStr"
}


## Compose demo-combo from ultimate anaglyph and its source SBS (stereopair)
## Call syntax:  Run_ANA_and_SBS_to_Combo  <anaPath>  <sbsRootDirPath>
Run_ANA_and_SBS_to_Combo() {
  local _anaName=$(basename -- $1 "")
  local _sbsRoot="$2"
  
  echo "-I- Entered: \nRun_ANA_and_SBS_to_Combo  '$1'  '$2'"
  anaName=$(basename -- $imgANA ".jpg")
  sbsName=`awk -v bName=$anaName 'BEGIN {res=sub(/_ahg_oleg_(cp|gp|ec|mc|sf|xc)__FCA/, "", bName);  print bName}'`
  imgSBS=`find ${_sbsRoot} -name "$sbsName.*"`
  if [[ $imgSBS == "" ]]; then
     echo -E- ==== Missing SBS for $anaName ====
     return 255
  else
     imgCombo=${OUTDIR}/demo__${anaName}.JPG
     echo -I- ==== $anaName " -> " $sbsName " -> " $imgSBS " => " $imgCombo ====
     commentStr="$(Read_Image_Comment $imgANA)"
     "$IMC"    -size 1920x1080 canvas:black        $stroke_S  -annotate $coordStr_S1 "$str1"  -annotate $coordStr_S2 "$str2"  -annotate $coordStr_S3 "$str3"        \( $imgSBS -resize 800x470 \) -geometry +30+575 -composite  \( $imgANA -resize 900x1020 \) -geometry +990+30 -composite  -set comment "$commentStr"  -quality 90  $imgCombo
  fi
  return 0
}
#################################################################################
