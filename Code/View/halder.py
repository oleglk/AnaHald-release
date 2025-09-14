#################################################################################
## Copyright 2025 Oleg Kosyakovsky
##
## Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
##
## 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
##
## 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#################################################################################

# halder.py - "model" class for Anahald viewer


from datetime import datetime
import os
import shutil
import sys
from pathlib import Path
import re
import subprocess
from PIL import Image
from tempfile import TemporaryDirectory



################## HOW TO LOAD THE CODE #########################################
# DT2022:
# import sys;  sys.path.append('C:\\Oleg\\Gitwork\\Anahald\\Code\\View')
# from halder import *
# import os;  os.chdir(r'D:\Work\RMA_WA')

# SZBOX12
# import sys;  sys.path.append('C:\\ANY\\Gitwork\\Anahald\\Code\\View')
# from halder import *
# import os;  os.chdir('C:\\ANY\\Gitwork\\Anahald')


# RELOAD:
# import importlib;  import halder;  importlib.reload(halder);  from halder import *;  import choose_hald_base;  importlib.reload(choose_hald_base);  from choose_hald_base import *;  import AnahaldDataset;  importlib.reload(AnahaldDataset);  from AnahaldDataset import *;  import search_ana;  importlib.reload(search_ana);  from search_ana import *
#################################################################################


SCRIPT_PATH = os.path.realpath(__file__)
VIEWER_DIR  = os.path.dirname(SCRIPT_PATH)
sys.path.append(VIEWER_DIR)
CHOICE_DIR  = os.path.join(VIEWER_DIR, "..", "Choice")
sys.path.append(CHOICE_DIR)
MODEL_DIR  = os.path.join(CHOICE_DIR, "..", "..", "CHOICE_MODELS")
MODEL_FILENAME = "anahald_model_params__96d5__20250814-231159.pth"  # duplicated, but ...
MODEL_PATH = os.path.join(MODEL_DIR, MODEL_FILENAME)


from choose_hald_base import *   # need AnahaldNetBase.apply_hald_make_ana
from choose_hald_resnet import * # need AnahaldResnet.LoadSavedAnahaldResnet
from search_ana import *         # need GenerateTimestampedFilePath
from ah_cfg import *             # configuration settings



#################################################################################
## Example 01:  hr = Halder(r"INP\Mini3D_Samples", [], "TMP")
## Example 02:  hr = Halder(r"INP\Mini3D_Samples", ["INP/HALD","INP/HALD/ADD"], "TMP")
class Halder:
    previewWidth = 1080
    previewHeight = 1080
    
    def __init__(self, sbsImgOrDirPath, haldDirs, outDir):
        for haldDir in haldDirs:
            if ( not os.path.isdir(haldDir) ):
                raise Exception(f"Inexistent HALD directory {haldDir}")
        self.haldDirs = haldDirs

        if ( outDir != "" ):
            self.outDir = outDir
            self.tmpDir = GenerateTimestampedFilePath(outDir, "ANAHALD_TMP",
                                                      ext="", nameSuffOrEmpty="")
        else:
            self.outDir = ""
            self.tmpDir = ""

            
        self.currHaldId  = "ahg_oleg_id"  # for ID of the currently chosen HALD
        self.currGamma   = 1.0            # for the currently chosen gamma value
        self.currAnaPath = ""

        self.sbsDir = ""
        self.currSbsPath = ""
        if ( sbsImgOrDirPath != "" ):
            self.point_at_image_or_dir(sbsImgOrDirPath)
    ####


    def is_ready(self):
        return((self.currSbsPath is not None) and (self.currSbsPath != ""))
    ####


    # Initializes image browsing based on 'sbsImgOrDirPath'
    def point_at_image_or_dir(self, sbsImgOrDirPath):
        if ( not os.path.exists(sbsImgOrDirPath) ):
            raise Exception(f"Inexistent '{sbsImgOrDirPath}'")
        if ( not os.path.isdir(sbsImgOrDirPath) ):
            self.sbsDir = os.path.dirname(sbsImgOrDirPath)
            self.currSbsPath = sbsImgOrDirPath                 # currently processed image
        else:
            self.sbsDir = sbsImgOrDirPath
            self.currSbsPath = FileOrder(self.sbsDir).first()  # currently processed image

        # provide 'self.outDir' and 'self.tmpDir' - either given or under input
        newOutDir = os.path.join(self.sbsDir, AhConfig.OUTDIR_NAME)
        if ( (self.outDir == "") or
             (os.path.normpath(newOutDir) != os.path.normpath(self.outDir)) ):
            if ( self.tmpDir != "" ):
                 self.clean_tmp_dir()  # delete old tmpDir
            self.outDir = os.path.join(self.sbsDir, AhConfig.OUTDIR_NAME)
            self.tmpDir = GenerateTimestampedFilePath(self.outDir, "ANAHALD_TMP",
                                                      ext="", nameSuffOrEmpty="")
        os.makedirs(self.outDir, exist_ok=True)
        os.makedirs(self.tmpDir, exist_ok=True)
        print(f"-D- Temporary directory: '{self.tmpDir}'")

        # generate the default anaglyph
        self.switch_image(self.currSbsPath)
    ####


    # If 'isPreview'=True, makes small image in temporary directory;
    #          otherwise makes full-size image in output directory
    ## Example_01:  hr.switch_hald_and_gamma(haldId="ahg_oleg_cp", gamma=0.9)
    def switch_hald_and_gamma(self, *, haldId="ahg_oleg_id", gamma=1.0, isPreview=True):
        if ( not self.is_ready() ):
            print(f"-E- Not ready for 'switch_hald_and_gamma'")
            return(0)
        oldHaldId = self.currHaldId
        outDir = self.tmpDir          if  ( isPreview )  else  self.outDir
        maxWd = Halder.previewWidth   if  ( isPreview )  else  -1
        maxHt = Halder.previewHeight  if  ( isPreview )  else  -1
        ret = AnahaldNetBase.apply_hald_make_ana(self.currSbsPath,
                                  haldId, self.haldDirs, outDir, gamma=gamma,
                                  maxWidth=maxWd, maxHeight=maxHt,
                                  isPreview=isPreview)
        if ( ret is not None ):
            self.currAnaPath = ret
            self.currHaldId  = haldId
            self.currGamma   = gamma
            self.clean_tmp_all_but_one(preserve=self.currAnaPath)
            return(1)
        else:
            print(f"-E- Failed switching to hald '{haldId}', gamma {gamma}")
            return(0)
    ####


    # If image path given, switches to it.
    # If "-"/"+" given, switches to the previous/next image in the same dir
    # Chooses the new image path and renders the image with current HALD and gamma
    # Returns path of the created anaglyph or None on error.
    def switch_image(self, newSbsPathOrMinusOrPlus):
        if ( not self.is_ready() ):
            print(f"-E- Not ready for 'switch_image'")
            return(0)
        newSbsPath = self.choose_new_source_image(newSbsPathOrMinusOrPlus)
        if ( newSbsPath == ""  ):
            return("")  # at end
        ret = AnahaldNetBase.apply_hald_make_ana(newSbsPath,
              "ahg_oleg_id", self.haldDirs, self.tmpDir, gamma=1.0,
              maxWidth = Halder.previewWidth, maxHeight = Halder.previewHeight,
              isPreview=True)
        if ( ret is not None ):
            self.currSbsPath = newSbsPath
            self.currAnaPath = ret
            self.currHaldId  = "ahg_oleg_id" # reset currently chosen HALD
            self.currGamma   = 1.0           # reset currently chosen gamma value
            self.clean_tmp_all_but_one(preserve=self.currAnaPath)
            return(self.currAnaPath)
        else:
            raise Exception(f"Failed switching to '{newSbsPath}'")
    ####

        
    # If image path given, switches to it.
    # If "-"/"+" given, switches to the previous/next image in the same dir
    # Only returns the new SBS image path
    def choose_new_source_image(self, newSbsPathOrMinusOrPlus):
        print(f"-D- Called choose_new_source_image({newSbsPathOrMinusOrPlus})")
        if ( not self.is_ready() ):
            print(f"-E- Not ready for 'choose_new_source_image'")
            raise Exception(f"-E- Not ready for 'choose_new_source_image'")
        if ( (newSbsPathOrMinusOrPlus == "+") or
             (newSbsPathOrMinusOrPlus == "-") ):
            imgOrder = FileOrder(self.sbsDir)
            if ( newSbsPathOrMinusOrPlus == "+" ):
                newSbsPath = imgOrder.next(self.currSbsPath)
            else:
                newSbsPath = imgOrder.prev(self.currSbsPath)
        else:
            newSbsPath = newSbsPathOrMinusOrPlus
        if ( (newSbsPath != "") and (not os.path.exists(newSbsPath)) ):
            raise Exception(f"Inexistent image '{newSbsPath}'")
        ##DO NOT: self.currSbsPath = newSbsPath
        print(f"-D- New SBS image for is '{newSbsPath}'")
        return(newSbsPath)
    ####


    # Returns list of filenames of all HALD files
    # For now picks all TIFF images in HALD directories
    # TODO: ?use HALD name pattern?
    def list_hald_filenames(self):
        HALD_EXTENSIONS = ['tif']
        allHaldFilenames = []
        for hDir in self.haldDirs:
            haldFilenamesInDir = FileOrder(hDir, HALD_EXTENSIONS).get_all_leaves()
            allHaldFilenames.extend(haldFilenamesInDir)
        return(allHaldFilenames)
    ####


    # Returns dictionary of {id : original-case-sensitive-name}
    def get_haldid_to_filename_map(self):
        haldNames = self.list_hald_filenames()
        idToName = {Halder.hald_filename_to_id(name): name  for name in haldNames}
        return(idToName)
    ####


    # Returns (haldId, gamma) or ("", 1.0) on error or unknown HALD
    def auto_choose_hald_and_gamma(self):
        if ( not os.path.exists(MODEL_PATH) ):
            print(f"-E- Missing auto-choice model file '{MODEL_PATH}'")
            return("", 1.0)
        ah = LoadSavedAnahaldResnet(MODEL_PATH)
        if ( ah is None ):
            print(f"-E- Failed loading auto-choice model file '{MODEL_PATH}'")
            return("", 1.0)

        haldId = ah.predict_hald(self.currSbsPath)
        gamma = AnahaldNetBase.choose_gamma_for_sample_hald(haldId)
        return(haldId, gamma)
    ####


    def clean_tmp_all_but_one(self, *, preserve=None):
        assert(self.tmpDir != "")
        print(f"-D- Cleanup in '{self.tmpDir}'")
        pattern = os.path.join(self.tmpDir, "*.*")
        if ( preserve is not None ):
            preserve = os.path.basename(preserve).lower()
        match = glob.glob(pattern, recursive=False)
        for fPath in match:
            fName = os.path.basename(fPath).lower()
            if ( (preserve is None) or (fName != preserve ) ):
                os.remove(fPath)
        return
    ####


    def clean_tmp_dir(self):
        if ( self.tmpDir == "" ):
            return
        print(f"-D- Deleting tmp directory '{self.tmpDir}'")
        if os.path.exists(self.tmpDir):
            try:
                shutil.rmtree(self.tmpDir)
            except OSError as e:
                print(f"-E-: {self.tmpDir}: {e.strerror}")
        else:
            print(f"-W- Temporary directory '{self.tmpDir}' does not exist.")
        return
    ####


    @staticmethod
    def hald_filename_to_id(filenameOrPath):
        haldPattern = r"hald__([-a-z_A-Z0-9]+)__16.tif"
        haldName = os.path.basename(filenameOrPath).lower()
        match = re.search(haldPattern, haldName)
        if ( match is None ):
            return(haldName)  # take non-standard name as is
        return(match.group(1))
    ####


    # # Copies the last made anaglyph into output directory; cleanes temp directory
    # def save_current_anaglyph(self):
    #     pass
#################################################################################



#################################################################################
class FileOrder:
    def __init__(self, dirPath, extensions=None):
        self.dirPath = dirPath
        self.includedExt = extensions if (extensions is not None) else ['bmp', 'jpg','jpeg', 'bmp', 'png', 'tif', 'gif']
        self.orderedList = self._find_images()
        self.orderedList.sort()


    def get_all_leaves(self):
        return(self.orderedList)

    
    def find_index(self, filePath):
        leafName = os.path.basename(filePath)
        try:
            # TODO: optimize search for ordered list
            index = next(i for i, v in enumerate(self.orderedList)
                         if v.lower() == leafName.lower())
            return(index)
        except StopIteration:
            return(-1)

        
    def first(self):
        if ( len(self.orderedList) > 0 ):
            return(os.path.join(self.dirPath, self.orderedList[0]))
        else:
            return("")

    
    def prev(self, filePath):
        leafName = os.path.basename(filePath)
        curr = self.find_index(leafName)
        if ( (curr == -1) or (curr == 0) ):
            return("")
        return(os.path.join(self.dirPath, self.orderedList[curr-1]))

    
    def next(self, filePath):
        leafName = os.path.basename(filePath)
        curr = self.find_index(leafName)
        if ( (curr == -1) or (curr == len(self.orderedList)-1) ):
            return("")
        return(os.path.join(self.dirPath, self.orderedList[curr+1]))
        

    def _find_images(self):
        fileNamesList = []
        #namesList = glob.glob('*.jpg', root_dir=)
        for fPath in glob.glob(os.path.join(self.dirPath, '*.*'), recursive=False):
            #print("Check ", fPath)
            if ( any(fPath.lower().endswith(ext) for ext in self.includedExt) ):
                #pureName = os.path.splitext(os.path.basename(fPath))[0]
                fileName = os.path.basename(fPath)
                fileNamesList.append(fileName)
        return(fileNamesList)

#################################################################################
