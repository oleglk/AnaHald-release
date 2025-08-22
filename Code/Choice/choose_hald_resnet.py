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

# choose_hald_resnet.py

from datetime import datetime
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import models, transforms, datasets

from choose_hald_base import *
from AnahaldDataset import *
from search_ana import *


################## HOW TO LOAD THE CODE #########################################
# DT2022 - Anaconda:
# import sys;  sys.path.append('C:\\Oleg\\Gitwork\\Anahald\\Code\\Choice')
# from choose_hald_resnet import *
#
# SZBOX12 - WinPython - need to change directory
# import sys;  sys.path.append('C:\\ANY\\Gitwork\\Anahald\\Code\\Choice')
# from choose_hald_resnet import *
# # import os;  os.chdir('C:\\ANY\\Gitwork\\Anahald\\INP\\CHOICE_DATA')
# # os.environ["IMAGEMAGICK_CONVERT_OR_MAGICK"] = "C:/ANY/Tools/ImageMagick-7.1.1-34/magick.exe"
#
# RELOAD - ANYWHERE:
# import importlib;  import choose_hald_resnet;  importlib.reload(choose_hald_resnet);  from choose_hald_resnet import *;  import choose_hald_base;  importlib.reload(choose_hald_base);  from choose_hald_base import *;  import AnahaldDataset;  importlib.reload(AnahaldDataset);  from AnahaldDataset import *;  import search_ana;  importlib.reload(search_ana);  from search_ana import *
#################################################################################


#################################################################################
class AnahaldResnet(AnahaldNetBase):
    def __init__(self, csv_or_pth_file, sbs_dir_or_dummy, out_dir=""):
        super().__init__(csv_or_pth_file, sbs_dir_or_dummy, out_dir)


    def _prepare_model(self, isTrainRequest):
        self.model = models.resnet18(weights=None) #Or resnet34, resnet50,...
        # Change the fc layer to match the number of classes in the dataset
        num_classes = NUM_HALDS
        self.model.fc = nn.Linear(self.model.fc.in_features, num_classes)
        if ( isTrainRequest ):
            device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        else:
            device = "cpu"
        self.model = self.model.to(device)
#################################################################################



## Example 1: ah = TrainAnahaldResnet('sbs_to_hald.csv', 'ALL_SBS_1080', num_epochs=3)
## Example 2: ah = TrainAnahaldResnet('sbs_to_hald__aug.csv', 'AUG_SBS_1080', num_epochs=3)
def TrainAnahaldResnet(csv_file, sbs_dir, num_epochs=NUM_EPOCHS):
    # CSV path required - net is to be trained
    extension = (os.path.splitext(csv_file)[1]).lower()
    if ( extension != ".csv" ):
        print(f"-E- Provided input file is {extension} instead of .csv; aborting")
        return(None)
    ahResNet = AnahaldResnet(csv_file, sbs_dir, "MODELS")
    if ( not ahResNet.isValid ):
        print("-E- Obtained ResNet is invalid; aborting")
        return(None)
    avg_loss_per_batch = ahResNet.train_model(num_epochs)
    print(f"-I- Training for {num_epochs} epoch(s) is finished; ultimate loss per batch: {avg_loss_per_batch}")
    
    ahResNet.validate_model()
    return(ahResNet)
        

## Example: ah = LoadSavedAnahaldResnet("MODELS/anahald_model_params__96d5__20250814-231159.pth")
def LoadSavedAnahaldResnet(pth_file):
    # PTH path required - parameters are to be loaded
    extension = (os.path.splitext(pth_file)[1]).lower()
    if ( extension != ".pth" ):
        print(f"-E- Provided input file is {extension} instead of .pth; aborting")
        return(None)
    ahResNet = AnahaldResnet(pth_file, "DUMMY_DIR", "MODELS")
    if ( not ahResNet.isValid ):
        print("-E- Obtained ResNet is invalid; aborting")
        return(None)
    if ( ahResNet.load_model(pth_file) ):
        return(ahResNet)
    else:
        return(None)  # error already printed
