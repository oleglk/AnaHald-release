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

# choose_hald_for_image.py
## Usage example:
##    set IMAGEMAGICK_CONVERT_OR_MAGICK=c:\ANY\Tools\ImageMagick-7.1.1-34\magick.exe  &  python c:\ANY\GitWork\AnaHald\Code\Choice\choose_hald_for_image.py  ALL_SBS_1080\DSC00022-00034.TIF  TMP

import os
import sys
import glob
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import models, transforms, datasets


MODEL_FILENAME = "anahald_model_params__96d5__20250814-231159.pth"


if ( os.getenv("IMAGEMAGICK_CONVERT_OR_MAGICK") is None ):
    print(f"-E- Please define environment variable 'IMAGEMAGICK_CONVERT_OR_MAGICK' with path of ImageMagick 'convert' or 'magick' utility")
    input("\nPress Enter to close...")
    sys.exit(1)


SCRIPT_PATH = os.path.realpath(__file__)
SCRIPT_DIR  = os.path.dirname(SCRIPT_PATH)
sys.path.append(SCRIPT_DIR)
from choose_hald_resnet import *

MODEL_DIR  = os.path.join(SCRIPT_DIR, "..", "..", "CHOICE_MODELS")
MODEL_PATH = os.path.join(MODEL_DIR, MODEL_FILENAME)
if ( not os.path.exists(MODEL_PATH) ):
    print(f"-E- Missing model file '{MODEL_PATH}'")
    input("\nPress Enter to close...")
    sys.exit(1)

ah = LoadSavedAnahaldResnet(MODEL_PATH)
if ( ah is None ):
    print(f"-E- Failed loading model file '{MODEL_PATH}'")
    input("\nPress Enter to close...")
    sys.exit(1)

# check existence of HALD directories
HALD_ROOTDIR = os.path.join(SCRIPT_DIR, "..", "..", "SAMPLE_HALDS")
HALD_DIRS = [HALD_ROOTDIR, os.path.join(HALD_ROOTDIR, "ADD")]
for hd in HALD_DIRS:
    if ( not os.path.exists(hd) ):
        print(f"-E- Missing sample-HALD directory '{hd}'")
        input("\nPress Enter to close...")
        sys.exit(1)
#################################################################################

if ( len(sys.argv) < 2 ):
    print("\n-E- Usage:  python choose_hald_for_image.py INPUT-SBS-IMAGE-GLOB-1 ... INPUT-SBS-IMAGE-GLOB-n  [OUTPUT-DIRECTORY]")
    input("\nPress Enter to close...")
    sys.exit(1)

inpPath1 = sys.argv[1]
inpDir = os.path.dirname(inpPath1)

# decide on output directory - either given or ANA/ under input directory
if ( (len(sys.argv) >= 3) and
     (os.path.isdir(sys.argv[-1] or (not os.path.exists(sys.argv[-1])))) ):
    outDir = sys.argv[-1]
    inpPatterns = sys.argv[1:-1]
else:
    outDir = os.path.join(inpDir, "ANA")
    inpPatterns = sys.argv[1:]
os.makedirs(outDir, exist_ok=True)

print(f"-I- Run configuration:  HALD directories = '{HALD_DIRS}', output directory = '{outDir}'")

# Perform HALD choice(s) and conversion(s)
errCnt = 0
for pattern in inpPatterns:
    inpPaths = glob.glob(pattern)
    for inpPath in inpPaths:
        res = ah.choose_hald_make_ana(inpPath, HALD_DIRS, outDir)
        if ( res is None ):
            errCnt += 1

input("\nPress Enter to close...")
sys.exit(errCnt)
