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

# AnahaldDataset.py

import os
import random
import pandas as pd
import csv
from PIL import Image

import torch
from torch.utils.data import Dataset, DataLoader
import torchvision.transforms as transforms

################## HOW TO LOAD THE CODE #########################################
# DT2022 - Anaconda:
# import sys;  sys.path.append('C:\\Oleg\\Gitwork\\Anahald\\Code\\Choice')
# from AnahaldDataset import *
#
# SZBOX12 - WinPython - need to change directory
# import sys;  sys.path.append('C:\\ANY\\Gitwork\\Anahald\\Code\\Choice')
# from AnahaldDataset import *
# # import os;  os.chdir('C:\\ANY\\Gitwork\\Anahald')
#
# RELOAD - ANYWHERE:
# import importlib;  import AnahaldDataset;  importlib.reload(AnahaldDataset);  from AnahaldDataset import *;  import search_ana;  importlib.reload(search_ana);  from search_ana import *
#################################################################################


SBS_WIDTH     = 480
SBS_HEIGHT    = 240
SBS_EXT       = "TIF" # assume all SBS-s have same extension; TODO: case on Linux
BATCH_SIZE    = 32
SHUFFLE_IMGS  = True

NORMALIZE_MEAN=[0.485, 0.456, 0.406]  # matches ImageNet
NORMALIZE_STD=[0.229, 0.224, 0.225]   # matches ImageNet
# NORMALIZE_MEAN=[0.5]*3
# NORMALIZE_STD=[0.5]*3


#################################################################################
class AnahaldDataset(Dataset):
    def __init__(self, csv_file, sbs_dir, sbs_ext, transform=None):
        self.sbs_dir = sbs_dir
        self.sbs_ext = sbs_ext
        self.transform = transform
        try:
            self.annotations = pd.read_csv(csv_file)
        except Exception as e:
            print(f"-E- Error reading CSV from '{csv_file}': {e.__str__()}")
            self.is_valid = False
        else:
            # Create a mapping: label string -> integer
            self.label2idx = {label: idx for idx, label in enumerate(
                sorted(self.annotations.iloc[:, 1].unique()))}
            # Create a mapping: integer      -> label string
            self.idx2label = {idx: label  for idx, label in enumerate(
                sorted(self.annotations.iloc[:, 1].unique()))}
            self.is_valid = True

    def __len__(self):
        return len(self.annotations)

    def __getitem__(self, idx):
        #print(f"-D- @@@@ idx={idx} => {self.annotations.iloc[idx, 0]}, {self.annotations.iloc[idx, 1]}")
        filename = f"{self.annotations.iloc[idx, 0]}.{self.sbs_ext}"
        label_str = self.annotations.iloc[idx, 1]
        label = self.label2idx[label_str]
        img_path = os.path.join(self.sbs_dir, filename)
        try:
            image = Image.open(img_path).convert("RGB")
        except Exception as e:
            print(f"-E- Error reading CSV from '{img_path}': {e.__str__()}")
            raise
        if self.transform:
            image = self.transform(image)
        return image, label, filename  # include filename for debugging


    # Returns map {label_code :: label_string} (codes to HALD name suffixes)
    def GetLabelCodesMap(self):
        assert(self.is_valid)
        return(self.idx2label)


    def SetLabelCodesMap(self, idx2labelDict):
        self.idx2label = idx2labelDict
#################################################################################



#################################################################################
class StereoTransform:
    def __init__(self, output_size=(SBS_HEIGHT, SBS_WIDTH/2)):
        self.output_size = output_size
        
        # Define shared transforms
        self.shared_transforms = transforms.Compose([
            transforms.RandomHorizontalFlip(p=0.5),
            transforms.RandomVerticalFlip(p=0.2),
            transforms.ColorJitter(brightness=0.3, contrast=0.3),
            transforms.Resize((int(output_size[0]), int(output_size[1]))),
        ])
        ###MAYBE-ADD:  transforms.ColorJitter(brightness=0.3, contrast=0.3),

        self.to_tensor = transforms.ToTensor()
        self.normalize = transforms.Normalize(mean=NORMALIZE_MEAN,
                                              std=NORMALIZE_STD)

    def __call__(self, stereo_image):
        # Split stereo image into left and right
        w, h = stereo_image.size
        left = stereo_image.crop((0, 0, w // 2, h))
        right = stereo_image.crop((w // 2, 0, w, h))

        # Set random seed to ensure the same transform is applied
        seed = random.randint(0, 99999)
        random.seed(seed)
        torch.manual_seed(seed)
        left = self.shared_transforms(left)

        random.seed(seed)
        torch.manual_seed(seed)
        right = self.shared_transforms(right)

        # To tensor and normalize
        left = self.normalize(self.to_tensor(left))
        right = self.normalize(self.to_tensor(right))

        return(torch.cat([left, right], dim=2))  # return as side-by-side
#################################################################################



#################################################################################
class InferenceStereoTransform:
    def __init__(self, output_size=(SBS_HEIGHT, SBS_WIDTH/2)):
        self.output_size = output_size
        
        # Define shared transforms
        self.shared_transforms = transforms.Compose([
            transforms.Resize((int(output_size[0]), int(output_size[1]))),
        ])

        self.to_tensor = transforms.ToTensor()
        self.normalize = transforms.Normalize(mean=NORMALIZE_MEAN,
                                              std=NORMALIZE_STD)

    def __call__(self, stereo_image):
        # Split stereo image into left and right
        w, h = stereo_image.size
        left = stereo_image.crop((0, 0, w // 2, h))
        right = stereo_image.crop((w // 2, 0, w, h))

        left = self.shared_transforms(left)
        right = self.shared_transforms(right)

        # To tensor and normalize
        left = self.normalize(self.to_tensor(left))
        right = self.normalize(self.to_tensor(right))

        return(torch.cat([left, right], dim=2))  # return as side-by-side
#################################################################################


# TODO: comment
def MakeAnahaldDataloaders(csv_file, sbs_dir, shuffle=SHUFFLE_IMGS):
    # transform = transforms.Compose([
    #     transforms.Resize((SBS_HEIGHT, SBS_WIDTH)),
    #     transforms.ToTensor(),
    #     transforms.Normalize(mean=[0.485, 0.456, 0.406],
    #                          std=[0.229, 0.224, 0.225])
    # ])
    # normalized using the same mean and std as ImageNet

    transform = StereoTransform(output_size=(SBS_HEIGHT, int(SBS_WIDTH/2)))
    
    full_dataset = AnahaldDataset(
        csv_file=csv_file,
        sbs_dir=sbs_dir,
        sbs_ext=SBS_EXT,
        transform=transform
    )
    if ( full_dataset.is_valid == False ):
        print(f"-E- Failed loading (full) dataset")
        return(None, None)

    # Split dataset into training-and validation, create the two DataLoader-s
    train_size = int(0.8 * len(full_dataset))
    val_size = len(full_dataset) - train_size
    generator = torch.Generator().manual_seed(42)  # for reproducibility
    train_dataset, val_dataset = torch.utils.data.random_split(full_dataset,
                                   [train_size, val_size], generator=generator)
    train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE,
                              shuffle=shuffle)
    val_loader   = DataLoader(val_dataset, batch_size=BATCH_SIZE,
                              shuffle=False)
    return(train_loader, val_loader, full_dataset)
##
#################################################################################



def ListAnahaldDataloader(dataloader, typeStr):
    try:
        for images, labels, filenames in dataloader:
            for i in range(len(filenames)):
                print(f"@@@@ Filename: {filenames[i]}, Shape: {images[i].shape}, Label: {labels[i].item()}")
    except Exception as e:
        print(f"-E- Failed listing '{typeStr}' dataloader ")
        return(0)
    print(f"-I- Success listing '{typeStr}' dataloader ")
    return(1)
                


## Example: DEBUG__TestAnahaldDataloaders('sbs_to_hald.csv', 'ALL_SBS_1080')
def DEBUG__TestAnahaldDataloaders(csv_file, sbs_dir):
    result = 1  # as if OK
    trainDL, validDl, dSet = MakeAnahaldDataloaders(csv_file, sbs_dir,
                                                    shuffle=False)
    for (dataloader, typeStr) in ((trainDL, "training"),
                                  (validDl, "validation")):
        if ( dataloader is None ):
            return  0
        print("\n")
        result &= ListAnahaldDataloader(dataloader, typeStr)
    return(result)
##
