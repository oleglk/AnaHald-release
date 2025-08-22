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

# choose_hald_base.py

from datetime import datetime
import os
from pathlib import Path
import subprocess
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import models, transforms, datasets
from PIL import Image

from AnahaldDataset import *
from search_ana import *


################## HOW TO LOAD THE CODE #########################################
# DT2022 - Anaconda:
# import sys;  sys.path.append('C:\\Oleg\\Gitwork\\Anahald\\Code\\Choice')
# from choose_hald_base import *
#
# SZBOX12 - WinPython - need to change directory
# import sys;  sys.path.append('C:\\ANY\\Gitwork\\Anahald\\Code\\Choice')
# from choose_hald_base import *
# # import os;  os.chdir('C:\\ANY\\Gitwork\\Anahald')
# # os.environ["IMAGEMAGICK_CONVERT_OR_MAGICK"] = "C:/ANY/Tools/ImageMagick-7.1.1-34/magick.exe"
#
# RELOAD - ANYWHERE:
# import importlib;  import choose_hald_base;  importlib.reload(choose_hald_base);  from choose_hald_base import *;  import AnahaldDataset;  importlib.reload(AnahaldDataset);  from AnahaldDataset import *;  import search_ana;  importlib.reload(search_ana);  from search_ana import *
#################################################################################


NUM_HALDS = 7
NUM_EPOCHS = 2
MIN_ACCURACY_FOR_EARLY_STOP = 99.0
SUFFICIENT_ACCURACY_TO_STOP = 96.5


#################################################################################
class AnahaldNetBase:
    def __init__(self, csv_or_pth_file, sbs_dir, out_dir=""):
        # if CSV path given, net is trained; otherwise - parameters are loaded
        extension = (os.path.splitext(csv_or_pth_file)[1]).lower()
        isTrainRequest = (extension == ".csv")
        self._validationAccuracies = []
        self.idx2label = None
        self.outDir = out_dir
        self.inference_transforms = InferenceStereoTransform(
                                           output_size=(SBS_HEIGHT, SBS_WIDTH/2))
        self._prepare_model(isTrainRequest)  # overloaded per network class
        if ( isTrainRequest ):  # prepare the network for training
            self.criterion = nn.CrossEntropyLoss()
            self.optimizer = torch.optim.Adam(self.model.parameters(),
                                          lr=1e-4, weight_decay=1e-4)
            self.train_loader, self.val_loader, self.dataset = MakeAnahaldDataloaders(
                                                        csv_or_pth_file, sbs_dir)
            self.isValid = not ((self.train_loader is None) or
                                (self.val_loader is None))
        else:                   # provide empty network for loading saved model
            self.isValid = True

            
    def _prepare_model(self, isTrainRequest):
        assert(True, "AnahaldNetBase._prepare_model() should not be called")
    

    def train_model(self, num_epochs=NUM_EPOCHS):
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        for epoch in range(num_epochs):
            self.model.train()
            running_loss = 0.0
            total_batches = 0
            correct = 0
            total = 0
            for images, labels, filenames in self.train_loader:
                images, labels = images.to(device), labels.to(device)

                # Forward pass
                self.optimizer.zero_grad()
                outputs = self.model(images)
                #print(f"-D- Epoch {epoch+1}: outputs='{outputs}', labels='{labels}'")
                loss = self.criterion(outputs, labels)
                _, predicted = torch.max(outputs, 1)  # decode one-hot encoding
                total += labels.size(0)
                correct += (predicted == labels).sum().item()

                # Backward pass and optimization
                self.optimizer.zero_grad()
                loss.backward()
                self.optimizer.step()

                # loss tracking
                running_loss += loss.item()  # accumulates loss over batches in epoch
                total_batches += 1

            avg_loss_per_batch = running_loss / total_batches
            trn_accuracy = 100 * correct / total
            val_accuracy = self.validate_model(loud=False)
            self.model.train()  # restore training mode
            print(f"-I- Epoch [{epoch+1}/{num_epochs}]>  Loss: {avg_loss_per_batch:.4f}  "
                  f"Train-Accuracy: {trn_accuracy:.2f}%  "
                  f"Valid-Accuracy: {val_accuracy:.2f}%")

            self._validationAccuracies.append(val_accuracy)
            if ( val_accuracy >= SUFFICIENT_ACCURACY_TO_STOP ):
                print(f"-I- Epoch [{epoch+1}/{num_epochs}]>  Training stopped early, since accuracy of {val_accuracy} is achieved")
                if ( self.outDir != "" ):
                    self.save_model(self.outDir)
                return(avg_loss_per_batch)
            if ( (val_accuracy >= MIN_ACCURACY_FOR_EARLY_STOP) and
                 (not self._AccuracyGrows()) ):
                print(f"-W- Epoch [{epoch+1}/{num_epochs}]>  Training aborted early, since accuracy doesn't grow")
                return(avg_loss_per_batch)

        return(avg_loss_per_batch)


    def validate_model(self, loud=False):
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model.eval()
        running_val_loss = 0.0
        correct = 0
        total = 0
        if ( loud ):
            print(f"-I- ... Calculating validation accuracy ...")
        with torch.no_grad():
            for images, labels, filenames in self.val_loader:
                images, labels = images.to(device), labels.to(device)
                outputs = self.model(images)
                loss = self.criterion(outputs, labels)
                running_val_loss += loss.item()

                _, predicted = torch.max(outputs, 1)  # decode one-hot encoding
                total += labels.size(0)
                correct += (predicted == labels).sum().item()
        avg_val_loss = running_val_loss / len(self.val_loader)
        val_accuracy = 100 * correct / total
        if ( loud ):
            print(f"-I- Validation>  "
                f"Val Loss: {avg_val_loss:.4f} "
                f"Val Accuracy: {val_accuracy:.2f}%")
        return(val_accuracy)


    def _AccuracyGrows(self):
        numEpochsToCheck = 10
        numEpochs = len(self._validationAccuracies)
        if ( numEpochs <= numEpochsToCheck ):
            return(True)
        lastAccuracies = self._validationAccuracies[-numEpochsToCheck:]
        sumDeltas = 0
        for i in range(0, len(lastAccuracies)-1):
            sumDeltas += lastAccuracies[i+1] - lastAccuracies[i]
        return(sumDeltas > 0)

        
    def save_model(self, outDirPath):
        (_trnNamesPath,_valNamesPath,modelPath,labelMapPath
         ) = AnahaldNetBase._make_outfile_paths(outDirPath)
        currDevice = next(self.model.parameters()).device
        self.model.to("cpu")  # predictions run on CPU; types should be compatible
        try:
            os.makedirs(outDirPath, exist_ok=True)
            torch.save(self.model.state_dict(), modelPath)
        except Exception as e:
            print(f"-E- Error saving model in '{modelPath}': {e}")
            return(0)
        finally:
            self.model.to(currDevice)  # return to the old device
        print(f"-I- Saved model in '{modelPath}'")
        AnahaldNetBase.store_dictionary_in_csv(self.dataset.GetLabelCodesMap(),
                                               labelMapPath)
        return(1)

    
    # Loads the model state (only) from 'inpParamsPath'.
    def load_model(self, inpParamsPath):
        # load model - weights
        try:
            self.model.load_state_dict(torch.load(inpParamsPath))
        except Exception as e:
            print(f"-E- Error loading model weights from '{inpParamsPath}': {e}")
            return(0)
        print(f"-I- Loaded model weights from '{inpParamsPath}'")
        # load the map of label codes to label strings (HALD file suffixes)
        labelMapPath = AnahaldNetBase._model_filepath_to_labelmap_filepath(
                                                                   inpParamsPath)
        idx2label1 = AnahaldNetBase.read_dictionary_from_csv(labelMapPath) #str:lst
        if ( idx2label1 == 0 ):
            print(f"-E- Error loading HALD codes from '{labelMapPath}'")
            return(0)
        print(f"-I- Loaded HALD codes from '{labelMapPath}'")
        self.idx2label = {int(strCode):nameList[0]
                     for (strCode, nameList) in idx2label1.items()}  # int : str
        return(1)


    # Example:  haldStr = ah.predict_hald("ALL_SBS_1080/DSC_0111.TIF")
    def predict_hald(self, imgPath):
        assert(self.isValid)
        assert(self.idx2label is not None)
        image = Image.open(imgPath).convert("RGB")
        # Apply transforms
        transformed_image = self.inference_transforms(image)
        # Add a batch dimension if your model expects a batch
        transformed_image_t = transformed_image.unsqueeze(0)

        # infere
        self.model.eval()
        with torch.no_grad():
            output = self.model(transformed_image_t)
            _, predicted_idx_t = torch.max(output, 1)  # decode one-hot encoding
            predicted_idx = int(predicted_idx_t[0])

        # convert index to HALD-name-suffix string
        if ( predicted_idx not in self.idx2label ):
            print(f"-E- Unknown HALD code '{predicted_idx}'")
            return(None)
        haldStr = self.idx2label[predicted_idx]
        print(f"-I- Predicted HALD for '{imgPath}' is '{haldStr}' (code: {predicted_idx})")
        return(haldStr)


    # Makes anaglyph out of SBS image 'sbsPath' using auto-predicted HALD.
    # Returns path of the created anaglyph or None on error.
    ## Example 1:  ah.choose_hald_make_ana("ALL_SBS_1080/DSC00033.TIF", ["d:/Work/RMA_WA/INP/HALD", "d:/Work/RMA_WA/INP/HALD/ADD"], "TMP")
    ## Example 2:  ah.choose_hald_make_ana("ALL_SBS_1080/DSC00033.TIF", ["C:/ANY/GitWork/AnaHald/INP/HALD", "C:/ANY/GitWork/AnaHald/INP/HALD/ADD"], "TMP")
    def choose_hald_make_ana(self, sbsPath, haldDirs, outDir):
        haldId = self.predict_hald(sbsPath)
        if ( haldId is None ):
            return(None)  # error already printed
        return(AnahaldNetBase.apply_hald_make_ana(sbsPath, haldId, haldDirs, outDir))
    

    ## Example: (trnNamesPath,valNamesPath,modelPath) = MakeOutFilePaths("TMP")
    @staticmethod
    def _make_outfile_paths(outDirPath):
        nameSuff = datetime.now().strftime("%Y%m%d-%H%M%S")
        trnNamesPath = GenerateTimestampedFilePath(outDirPath,
                                        "anahald_train_imgs", "txt", nameSuff)
        valNamesPath = GenerateTimestampedFilePath(outDirPath,
                                        "anahald_valid_imgs", "txt", nameSuff)
        modelDumpPath = GenerateTimestampedFilePath(outDirPath,
                                        "anahald_model_params", "pth", nameSuff)
        labelMapPath = GenerateTimestampedFilePath(outDirPath,
                                        "anahald_label_codes", "csv", nameSuff)
        return(trnNamesPath, valNamesPath, modelDumpPath, labelMapPath)


    ## Example:  store_dictionary_in_csv({0:"name0",1:"name1",2:"name2"},  "TMP/dict00.csv")
    @staticmethod
    def store_dictionary_in_csv(theDict, outPath):
        try:
            # note, enclosing dictionary in a list avoids error
            #   "If using all scalar values, you must pass an index"
            df = pd.DataFrame([theDict]);
            df.to_csv(outPath, index=False)    # Writing to CSV
        except Exception as e:
            print(f"-E- Failed saving dictionary in '{outPath}': {e.__str__()}")
            return(0)
        print(f"-I- Success saving dictionary in '{outPath}'")
        return(1)
        

    # Returns dictionary where keys are strings and values are 1-element lists
    @staticmethod
    def read_dictionary_from_csv(inpPath):
        try:
            df = pd.read_csv(inpPath)
            theDict = df.to_dict('list')
        except Exception as e:
            print(f"-E- Failed reading dictionary from '{inpPath}': {e.__str__()}")
            return(0)
        #print(f"-D- Success reading dictionary from '{inpPath}'")
        return(theDict)


    # Makes anaglyph out of SBS image 'sbsPath' using HALD 'haldId'.
    # Returns path of the created anaglyph or None on error.
    ## Example 1:  AnahaldNetBase.apply_hald_make_ana("ALL_SBS_1080/DSC00033.TIF", "ahg_oleg_gp", ["d:/Work/RMA_WA/INP/HALD"], "TMP")
    ## Example 2:  AnahaldNetBase.apply_hald_make_ana("ALL_SBS_1080/DSC00033.TIF", "ahg_oleg_gp", ["C:/ANY/GitWork/AnaHald/INP/HALD"], "TMP")
    @staticmethod
    def apply_hald_make_ana(sbsPath, haldId, haldDirs, outDir):
        IMC = os.getenv("IMAGEMAGICK_CONVERT_OR_MAGICK")
        if ( IMC is None ):
            print(f"-E- Please define environment variable 'IMAGEMAGICK_CONVERT_OR_MAGICK' with path of ImageMagick 'convert' or 'magick' utility")
            return(None)
        IMC_DIR = os.path.dirname(IMC).strip('"')
        IMC_NAME = os.path.basename(IMC).strip('"')
        os.makedirs(outDir, exist_ok=True)
        if ( haldId != "ahg_oleg_id" ):
            # find HALD file in provided directories
            haldName = f"hald__{haldId}__16.TIF"
            for haldDir in haldDirs:
                haldPath = f"{haldDir}/{haldName}"
                if ( os.path.exists(haldPath) ):
                    #print(f"-D- Found HALD '{haldPath}'")
                    break
                else:
                    #print(f"-D- Not found HALD '{haldPath}'")
                    haldPath = None
            if ( haldPath is None ):
                print(f"-E- Inexistent HALD file '{haldName}'; checked directories : {haldDirs}")
                return(None)
            haldArgs = [Path(haldPath).resolve(), "-hald-clut"]
        else:
            haldArgs = []
        # build output file path
        pureName, ext = os.path.splitext(os.path.basename(sbsPath))
        outPath = f"{outDir}/{pureName}_{haldId}.jpg"
        gamma = AnahaldNetBase.choose_gamma_for_sample_hald(haldId)
        cmdAsList = [IMC_NAME, Path(sbsPath).resolve(),  "-gamma", str(gamma)] + haldArgs +  ["-crop","50%x100%", "-swap","0,1",  "-define","compose:args=20",  "-compose","stereo", "-composite",  "-depth","8", "-quality","92"  , Path(outPath).resolve()]
        print(f"-I- Running command:  {' '.join([str(x) for x in cmdAsList])}")
        try:
            oldDir = os.getcwd()
            if ( IMC_DIR != '' ):
                os.chdir(IMC_DIR) # workaround for "Access is denied" on Anaconda
            result = subprocess.run(cmdAsList,
                                    capture_output=True, text=True, check=True)
            isOk = True
        except Exception as e:
            os.chdir(oldDir)
            print(f"Error executing command: {e}")
            #print(f"Stderr: {e.stderr}") #stderr available in specific exception
            return(None)
        finally:
            os.chdir(oldDir)
        # success
        return(outPath)


    def choose_gamma_for_sample_hald(haldId):
        haldPrefixToGamma = {"ahg_oleg_id":1.00,
                             "ahg_oleg_cp":1.00,
                             "ahg_oleg_mc":1.00,
                             "ahg_oleg_gp":1.00,
                             "ahg_oleg_ec":0.95,
                             "ahg_oleg_xc":0.88,
                             "ahg_oleg_sf":0.88}
        if ( haldId in haldPrefixToGamma ):
            return(haldPrefixToGamma[haldId])
        else:
            return(1.00)


    @staticmethod
    def _model_filepath_to_labelmap_filepath(modelDumpPath):
        lP = modelDumpPath.replace("anahald_model_params", "anahald_label_codes")
        labelMapPath = lP.replace(".pth", ".csv")
        return(labelMapPath)
#################################################################################
