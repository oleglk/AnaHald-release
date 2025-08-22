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

# search_ana.py

import glob
import os
import sys
import re
import random
import pickle
from datetime import datetime
import numpy as np
import pandas as pd


# DT2022:
# import sys;  sys.path.append('C:\\Oleg\\Gitwork\\Anahald\\Code\\Choice')
# from search_ana import *

# SZBOX12
# import sys;  sys.path.append('C:\\ANY\\Gitwork\\Anahald\\Code\\Choice')
# from search_ana import *
# import os;  os.chdir('C:\\ANY\\Gitwork\\Anahald')


# RELOAD:  import importlib;  import search_ana;  importlib.reload(search_ana);  from search_ana import *


########################## Global variables to become class-static ##############
_HALD_NAME_PREFIX = "ahg_"

_HALD_ORDER = ["ahg_oleg_id", "ahg_oleg_cp", "ahg_oleg_mc", "ahg_oleg_gp",
               "ahg_oleg_ec", "ahg_oleg_xc", "ahg_oleg_sf"]
_HALD_ORDER_ABC = sorted(_HALD_ORDER)

_RANDOM_SEED = 88

_HIST_KEYS_ORDER = ['0.00-0.33', '0.33-0.45', '0.45-0.67', '0.67-1.50', '1.50-2.20', '2.20-3.00', '3.00-510.00']

_DT_HYPERPARAM__MAX_DEPTH = 4
_DT_HYPERPARAM__MIN_SAMPLES_LEAF = 3
#################################################################################


# choiceAna = FindAnaglyphs('D:\\Work\\RMA_WA\\OUT\\Anaglyph_RR\\ALL_CHOSEN')
def FindAnaglyphs(anaDir):
    fileNamesList = []
    #namesList = glob.glob('*.jpg', root_dir=)
    includedExt = ['bmp', 'jpg','jpeg', 'bmp', 'png', 'tif', 'gif']

    for fPath in glob.glob(os.path.join(anaDir, '*.*'), recursive=False):
        #print("Check ", fPath)
        if ( any(fPath.lower().endswith(ext) for ext in includedExt) ):
            #pureName = os.path.splitext(os.path.basename(fPath))[0]
            fileName = os.path.basename(fPath)
            fileNamesList.append(fileName)
    return(fileNamesList)


# Returns ID of the HALD LUT; example: "ahg_oleg_cp"
def DetectHaldFromFilename(filePath, haldPrefix=_HALD_NAME_PREFIX):
    leafName = os.path.basename(filePath)
    (rootName, ext) = os.path.splitext(leafName)
    pattern = "_({}[^.]+)$".format(haldPrefix)
    #print("@@@ pattern='{}'".format(pattern))
    mh = re.search(pattern, rootName)
    if ( mh is None ):
        return(None)
    return(mh.group(1))


# Returns the original image name without extention;
##      example: "DSC123456_ahg_oleg_cp.JPG" => "DSC123456"
def DetectSourceFromFilename(filePath, haldPrefix=_HALD_NAME_PREFIX):
    leafName = os.path.basename(filePath)
    (rootName, ext) = os.path.splitext(leafName)
    pattern = "(.+)_{}[^.]+$".format(haldPrefix)
    #print("@@@ pattern='{}'".format(pattern))
    mh = re.search(pattern, rootName)
    if ( mh is None ):
        return(None)
    return(mh.group(1))


# Returns dictionary of {fileName :: haldID} or 0 on error.
# Anaglyphs without HALD-id are mapped to 'dummyHaldId'.
# If 'outCsvPathOrEmpty' given, stores the dictionary as CSV there.
## Example 1:  ANADIR='D:\\Work\\RMA_WA\\OUT\\Anaglyph_RR\\ALL_CHOSEN';  haldDict = FindAnaglyphsAndDetectHalds(ANADIR, outCsvPathOrEmpty="TMP/ana_to_hald.csv");  len(haldDict)
## Example 2:  ANADIR='D:\\Photo\\Anaglyph_RR\\Anaglyph_NORR';  haldDict = FindAnaglyphsAndDetectHalds(ANADIR, outCsvPathOrEmpty="D:/Work/RMA_WA/TMP/ana_to_hald__noRR.csv");  len(haldDict)
# TODO: use keyword-only arguments
def FindAnaglyphsAndDetectHalds(anaDir, haldPrefix=_HALD_NAME_PREFIX,
                                dummyHaldId="ahg_oleg_id", outCsvPathOrEmpty=""):
    anaNamesList = FindAnaglyphs(anaDir)
    cntUnMatched = 0
    pathToHald = {}    # for the return object
    usedHaldList = []  # for CSV; order will match that of 'anaNamesList'
    for anaName in anaNamesList:
        haldId = DetectHaldFromFilename(anaName, haldPrefix)
        if ( haldId is None ):
            cntUnMatched += 1
            haldId = dummyHaldId
        usedHaldList.append(haldId)
        pathToHald[anaName] = haldId
    print("-I- Found %d anaglyphs, matched to HALDs %d anaglyph(s)" %
          (len(anaNamesList), (len(anaNamesList) - cntUnMatched)))
    if ( outCsvPathOrEmpty != "" ):
        dfDict = {"AnaFileName" : anaNamesList,    "HaldId" : usedHaldList}
        pdDFrame = pd.DataFrame(dfDict)
        pdDFrame.to_csv(outCsvPathOrEmpty, index=False, header=True)
        print("-I- Stored %d anaglyph-path-to-HALD mapping(s) in '%s'" %
              (len(pathToHald), outCsvPathOrEmpty))
    return(pathToHald)


# Based on properly named anaglyphs under 'anaDir',
#   returns dictionary of {sourceSBS_pureFileName :: haldID} or 0 on error.
# Images whose anaglyphs lack HALD-id are mapped to 'dummyHaldId'.
# If 'outCsvPathOrEmpty' given, stores the dictionary as CSV there.
## Example 1:  ANADIR='D:\\Work\\RMA_WA\\OUT\\Anaglyph_RR\\ALL_CHOSEN';  haldDict = MapSbsToHalds(ANADIR, outCsvPathOrEmpty="TMP/sbs_to_hald.csv");  len(haldDict)
## Example 2:  ANADIR='D:\\Photo\\Anaglyph_RR\\Anaglyph_NORR';  haldDict = MapSbsToHalds(ANADIR, outCsvPathOrEmpty="D:/Work/RMA_WA/TMP/sbs_to_hald__noRR.csv");  len(haldDict)
def MapSbsToHalds(anaDir, haldPrefix=_HALD_NAME_PREFIX,
                                dummyHaldId="ahg_oleg_id", outCsvPathOrEmpty=""):
    anaPathToHald = FindAnaglyphsAndDetectHalds(anaDir, haldPrefix=haldPrefix,
                                dummyHaldId=dummyHaldId, outCsvPathOrEmpty="")
    sbsNameToHald = {}
    cntDuplicat = 0
    for anaPath in anaPathToHald:
        sbsName = DetectSourceFromFilename(anaPath, haldPrefix=haldPrefix)
        if ( sbsName is None ):
            # assume dummy "ID" HALD, thus no suffix - take filename as is
            sbsName = os.path.splitext(anaPath)[0]
        if ( sbsName in sbsNameToHald ):
            cntDuplicat += 1
            print(f"-W- Duplicated choice of HALD for '{sbsName}': '{sbsNameToHald[sbsName]}' and '{anaPathToHald[anaPath]}'")
        sbsNameToHald[sbsName] = anaPathToHald[anaPath]
    print("-I- Found %d SBS-name-to-HALD mapping(s); %d duplication(s) occurred" %
              (len(sbsNameToHald), cntDuplicat))
    if ( outCsvPathOrEmpty != "" ):
        # orderings of keys() and values follow insertion order, thus correlated
        dfDict = {"SbsFileName" : sbsNameToHald.keys(),
                  "HaldId"      : sbsNameToHald.values()}
        pdDFrame = pd.DataFrame(dfDict)
        pdDFrame.to_csv(outCsvPathOrEmpty, index=False, header=True)
        print("-I- Stored %d SBS-name-to-HALD mapping(s) in '%s'" %
              (len(sbsNameToHald), outCsvPathOrEmpty))
    return(sbsNameToHald)


# Turns two {fileName :: <SOMETHING>} dictionries into order-correlated lists
# histogramDict = {          fileName :: R2C-histogram-bins}
# halddDict = {fileNameWithHaldSuffix :: haldID}
# (dictionaries stored in CSV files)
## Example 1:  (fileNamesNoSuffList, r2cBinsListOfLists, haldIDList) = CorrelateFileNameDictionaries("INP/CHOICE_DATA/dummy_hist.csv", "INP/CHOICE_DATA/dummy_hald.csv")
## Example 2:  (fileNames, r2cBinsLists, haldIDs) = CorrelateFileNameDictionaries("INP/CHOICE_DATA/hist_rr.csv", "INP/CHOICE_DATA/ana_to_hald.csv")
def CorrelateFileNameDictionaries(histogramDictCSVPath, haldDictCSVPath):
    try:
        histogramDictDFrame = pd.read_csv(histogramDictCSVPath, index_col=None)
    # Process the DataFrame
    except Exception as e:
        print(f"-E- Error reading histogram dictionary from '{histogramDictCSVPath}': {e}")
        return  0
    try:
        haldDictDFrame = pd.read_csv(haldDictCSVPath, index_col=None)
    except Exception as e:
        print(f"-E- Error reading HALD dictionary from '{haldDictCSVPath}': {e}")
        return  0
    fileNamesHist = histogramDictDFrame['filename'].tolist() # TODO: error-check
    fileNamesHald = haldDictDFrame['AnaFileName'].tolist()   # TODO: error-check
    (fileNamesHistSorted, fileNamesHaldSorted) = \
                              FindCommonFileNames(fileNamesHist, fileNamesHald)
    if ( len(fileNamesHistSorted) == 0 ):
        print("-E- No correlated filenames found")
        return  0
    print(f"-I- Found {len(fileNamesHistSorted)} correlated filename(s)")
    #return  (fileNamesHistSorted, fileNamesHaldSorted);  # OK_TMP
    # build order-correlated lists of histograms and HALDs
    r2cBinsListOfLists = [];  haldIDList = [];  # for sorted resulting lists
    histogramDictDFrame.set_index('filename', inplace=True)
    haldDictDFrame.set_index('AnaFileName', inplace=True)
    #print(f"@@@@@@\n{histogramDictDFrame}\n@@@@@@\n{haldDictDFrame}\n@@@@@@")
    for i in range(0, len(fileNamesHistSorted)):
        fileNameForHist = fileNamesHistSorted[i]
        fileNameForHald = fileNamesHaldSorted[i]
        histRow = histogramDictDFrame.loc[fileNameForHist]
        haldRow = haldDictDFrame.loc[fileNameForHald]
        #print(f"\n@@@@ '{fileNameForHist}' =>\n{histRow};  \n----\n'{fileNameForHald}' =>\n{haldRow}")
        r2cBinsListOfLists.append(histRow)
        haldIDList.append(haldRow)
    return( (fileNamesHistSorted, r2cBinsListOfLists, haldIDList) )
#

# Returns 2 order-correlated lists of filenames - without- and with suffix
## Example:      (lstNoSuff, lstWithSuff) = FindCommonFileNames({'f1.a','f2.a'}, {'f3_P.b','f2_Q.b','f1_R.b'})
def FindCommonFileNames(fileNamesNoSuff, fileNamesWithSuff):
    allFileNamesNoSuffSorted   = sorted(fileNamesNoSuff)
    allFileNamesWithSuffSorted = sorted(fileNamesWithSuff)
    fileNamesNoSuffSorted = [];  fileNamesWithSuffSorted = [];  # for the output
    i = 0;  iMax = len(allFileNamesNoSuffSorted)-1
    j = 0;  jMax = len(allFileNamesWithSuffSorted)-1
    iterLeft = iMax + jMax + 4;  # protection from infinite cycle
    while ((i <= iMax) and (j <= jMax)) and (iterLeft > 0):
        iterLeft = iterLeft - 1
        # if ( (i > iMax) and (j <= jMax) ):  i = iMax; #compare tail vs the last
        # if ( (j > jMax) and (i <= iMax) ):  j = jMax; #compare tail vs the last
        str1Full = os.path.splitext(allFileNamesNoSuffSorted[i]  )[0].lower()
        str2Full = os.path.splitext(allFileNamesWithSuffSorted[j])[0].lower()
        str2TillSuffix = str2Full[:len(str1Full)]
        # print(f"@@@@ [{i},{j}] 1='{str1Full}' 2='{str2Full}'")
        if   (  str1Full <  str2TillSuffix ):
            i = i + 1
            continue
        elif (  str1Full >  str2TillSuffix ):
            j = j + 1
            continue
        else: # str1Full == str2TillSuffix
            fileNamesNoSuffSorted.append(allFileNamesNoSuffSorted[i])     # orig1
            fileNamesWithSuffSorted.append(allFileNamesWithSuffSorted[j]) # orig2
            i = i + 1
            j = j + 1
    print(f"@@@@ iterLeft at return = {iterLeft}")
    return  (fileNamesNoSuffSorted, fileNamesWithSuffSorted)
#


# Returns two tuples of order-correlated (names, r2cBinsListOfLists, haldIDList)
# Intended for splitting inputs into training and validation sets.
# 'fractForFirst' tells a part allocated to 1st set (0.8 means 80 out of 100)
## Example 1:  (fileNames, r2cBinsLists, haldIDs) = CorrelateFileNameDictionaries("INP/dummy_hist.csv", "INP/dummy_hald.csv");    ((names1,bins1,halds1), (names2,bins2,halds2)) = SplitFileNameToHistAndHaldDictionaries(0.6, fileNames, r2cBinsLists, haldIDs)
## Example 2:  (fileNames, r2cBinsLists, haldIDs) = CorrelateFileNameDictionaries("INP/CHOICE_DATA/hist_rr.csv", "INP/CHOICE_DATA/ana_to_hald.csv");    ((names1,bins1,halds1), (names2,bins2,halds2)) = SplitFileNameToHistAndHaldDictionaries(0.7, fileNames, r2cBinsLists, haldIDs)
def SplitFileNameToHistAndHaldDictionaries(fractForFirst,
                            fileNamesList, r2cBinsListOfLists, haldIDList):
    if ( fractForFirst > 1.0 ):
        raise Exception(f"Fraction for 1st set must be <=1; got {fractForFirst}")
    random.seed(a=_RANDOM_SEED); # ensure stable choice of training vs validation
    nItems = len(fileNamesList)
    period = 10
    cntFor1 = round(fractForFirst * nItems)
    cntFor2 = nItems - cntFor1
    indicesFor1 = random.sample(range(0, nItems), cntFor1)
    fileNamesList1=[];  r2cBinsListOfLists1=[];  haldIDList1=[]
    fileNamesList2=[];  r2cBinsListOfLists2=[];  haldIDList2=[]
    for i in range(0, nItems):
        if ( i in indicesFor1 ):
            fileNamesList1.append(fileNamesList[i])
            r2cBinsListOfLists1.append(r2cBinsListOfLists[i])
            haldIDList1.append(haldIDList[i])
        else:
            fileNamesList2.append(fileNamesList[i])
            r2cBinsListOfLists2.append(r2cBinsListOfLists[i])
            haldIDList2.append(haldIDList[i])
    ###print(f"@@@@ len(haldIDList1)={len(haldIDList1)}, len(haldIDList2)={len(haldIDList2)}")
    return  ((fileNamesList1, r2cBinsListOfLists1, haldIDList1),
             (fileNamesList2, r2cBinsListOfLists2, haldIDList2))
#


def AssembleFeaturesDataframe(r2cBinsListOfLists):
    df = pd.DataFrame({
        'b_0' : [y.iloc[0] for y in r2cBinsListOfLists],
        'b_1' : [y.iloc[1] for y in r2cBinsListOfLists],
        'b_2' : [y.iloc[2] for y in r2cBinsListOfLists],
        'b_3' : [y.iloc[3] for y in r2cBinsListOfLists],
        'b_4' : [y.iloc[4] for y in r2cBinsListOfLists],
        'b_5' : [y.iloc[5] for y in r2cBinsListOfLists],
        'b_6' : [y.iloc[6] for y in r2cBinsListOfLists],
    })
    return(df)
#


def AssembleLabelsDataframe(haldIDList):
    df = pd.DataFrame({
        'haldId' : [y.iloc[0] for y in haldIDList],
    })
    # convert categorical data into binary-one-hot format
    # ++ do enforce HALD order by increasing correction aggressivity
    # haldOrder = ["ahg_oleg_id", "ahg_oleg_cp", "ahg_oleg_mc", "ahg_oleg_gp",
    #              "ahg_oleg_ec", "ahg_oleg_xc", "ahg_oleg_sf"]
    df = pd.get_dummies(df, prefix_sep='_')  # ABC order - inconvenient
    # df['haldId'] = pd.Categorical(df['haldId'],
    #                               categories=haldOrder, ordered=True)
    return(df)
#


def DecodeOneHotLabel(oneHotArray):
    if ( False == np.any(oneHotArray) ):
        print(f"-F- Missing True bit in one-hot encoding: {oneHotArray}")
        #raise Exception("Missing True bit in one-hot encoding")
        return("")
    try:
        idxOfTrue = np.where(oneHotArray == True)[0][0]
    except ValueError as e:
        print(f"-F- Missing True bit in one-hot encoding: {e}")
        raise e
    if ( idxOfTrue >= len(_HALD_ORDER_ABC) ):
        raise Exception(f"Invalid one-hot encoding for HALD-ID: '{oneHotArray}'")
    return  _HALD_ORDER_ABC[idxOfTrue];  # will raise exception if out-of-bounds
#


def PredictHaldId(decTree, histogramBinsList):
    oneHotNestedArray = decTree.predict([histogramBinsList]);  # like [[FFFTFFF]]
    return(DecodeOneHotLabel(oneHotNestedArray[0]))
    

# Ensures list of histogram values in ascending order.
## Example: OneHistogramDictToValues({'0.00-0.33': 0, '0.33-0.45': 1, '0.45-0.67': 2, '0.67-1.50': 3, '1.50-2.20': 4, '2.20-3.00': 5, '3.00-510.00': 6})
def OneHistogramDictToValues(histogramBinsDict):
    histogramBinsList = []
    for binKey in _HIST_KEYS_ORDER:
        histogramBinsList.append(histogramBinsDict[binKey])
    return(histogramBinsList)

#


#################################################################################
## Utilities
################################################################################
def GenerateTimestampedFilePath(dirPath, namePref, ext, nameSuffOrEmpty=""):
    if ( nameSuffOrEmpty == "" ):
        nameSuff = datetime.now().strftime("%Y%m%d-%H%M%S")
    else:
        nameSuff = nameSuffOrEmpty
    leafName = f"{namePref}__{nameSuff}.{ext}"
    fullPath = os.path.join(dirPath, leafName)
    return(fullPath)


# Saves list of text lines in a text file with auto-generated name
def DumpListIntoTextFile(linesList, dirPath, namePref, ext):
    fullPath = GenerateTimestampedFilePath(dirPath, namePref, ext)
    return(WriteListIntoTextFile(linesList, fullPath))


# Saves list of text lines in text file 'outPath'
def WriteListIntoTextFile(linesList, outPath):
    try:
        with open(outPath, 'w') as f:
            for line in linesList:
                f.write(f"{line}\n")
    except Exception as e:
        print(f"-E- Error saving text list in '{outPath}': {e}")
        return(0)
    return(1)


# Saves arbitrary string of text in text file 'outPath'
def WriteStringIntoTextFile(s, outPath):
    try:
        with open(outPath, 'w') as f:
            f.write(f"{s}")
    except Exception as e:
        print(f"-E- Error saving text string in '{outPath}': {e}")
        return(0)
    return(1)


def ReadListFromTextFile(inpPath):
    linesList = []
    try:
        with open(inpPath, 'r') as f:
            for line in f:
                linesList.append(line.strip()) # remove newline characters
    except Exception as e:
        print(f"-E- Error reading list of lines from '{inpPath}': {e}")
        return(0)
    return(linesList)


def SaveDecTreeData(outDirPath, namesTrn, namesVal, decisionTree):
    (trnNamesPath,valNamesPath,modelPath,treePath) = MakeOutFilePaths(outDirPath)
    if ( 0 == WriteListIntoTextFile(namesTrn, trnNamesPath) ):
        return(0);  # error already printed
    if ( 0 == WriteListIntoTextFile(namesVal, valNamesPath) ):
        return(0);  # error already printed
    try:
        pickle.dump(decisionTree, open(modelPath, 'wb'))
    except Exception as e:
        print(f"-E- Error saving decision tree in '{modelPath}': {e}")
        return(0)
    print(f"-I- Saved decision tree in '{modelPath}'")
    treeAsAscii = export_text(decisionTree)
    if ( 0 == WriteStringIntoTextFile(treeAsAscii, treePath) ):
        return(0);  # error already printed
    return(1)


def LoadDecisionTree(inpPicklePath):
    try:
        with open(inpPicklePath, 'rb') as file:
            loadedModel = pickle.load(file)
    except Exception as e:
        print(f"-E- Error loading decision tree from '{inpPicklePath}': {e}")
        return(0)
    print(f"-I- Loaded decision tree from '{inpPicklePath}'")
    return(loadedModel)


## Example: (trnNamesPath,valNamesPath,modelPath,treePath) = MakeOutFilePaths("TMP")
def MakeOutFilePaths(outDirPath):
    nameSuff = datetime.now().strftime("%Y%m%d-%H%M%S")
    trnNamesPath = GenerateTimestampedFilePath(outDirPath,
                                        "anahald_train_imgs", "txt", nameSuff)
    valNamesPath = GenerateTimestampedFilePath(outDirPath,
                                        "anahald_valid_imgs", "txt", nameSuff)
    modelDumpPath = GenerateTimestampedFilePath(outDirPath,
                                        "anahald_model_pickle", "pkl", nameSuff)
    modelTreePath = GenerateTimestampedFilePath(outDirPath,
                                        "anahald_model_tree", "txt", nameSuff)
    return(trnNamesPath, valNamesPath, modelDumpPath, modelTreePath)
#
#################################################################################




#################################################################################
## The prediction
#################################################################################
## Example:  PredictHaldForImageInHistogramCSV(decTree, 'DSC03568.TIF', "INP/CHOICE_DATA/real__hist.csv", histogramDictDFrame=None)
def PredictHaldForImageInHistogramCSV(decTree, imgName, histogramDictCSVPath, *,
                                      histogramDictDFrame=None):
    if ( histogramDictDFrame is None ):
        try:
            histogramDictDFrame = pd.read_csv(histogramDictCSVPath,
                                              index_col='filename')
        except Exception as e:
            print(f"-E- Error reading histogram dictionary from '{histogramDictCSVPath}': {e}")
            return(0)
    ## (orient='index' creates a dictionary where keys are index values,
    ##   and values are dictionaries representing row data.
    fileNameToHist = histogramDictDFrame.to_dict(orient='index')
    if ( imgName not in fileNameToHist ):
        print(f"-E- Image '{imgName}' missing from '{histogramDictCSVPath}': {e}")
        return(0)
    ## 'fileNameToHist' example: {'DSC00790-01435.TIF': {'0.00-0.33': 0.0, '0.33-0.45': 0.01, '0.45-0.67': 0.63, '0.67-1.50': 98.88, '1.50-2.20': 0.47, '2.20-3.00': 0.01, '3.00-510.00': 0.0}, 'DSC03215-02292.TIF': {'0.00-0.33': 9.84, '0.33-0.45': 2.27, '0.45-0.67': 4.96, '0.67-1.50': 82.82, '1.50-2.20': 0.1, '2.20-3.00': 0.01, '3.00-510.00': 0.0}, ...}
    histogramBinsList = OneHistogramDictToValues(fileNameToHist[imgName])
    if ( histogramBinsList == 0 ):
        return(0);  # error already printed
    print(f"@@@@ HISTOGRAM({imgName}) = '{histogramBinsList}'")
    haldId = PredictHaldId(decTree, histogramBinsList)
    return(haldId)


## Example:  decTree=LoadDecisionTree("TMP/anahald_model_pickle__OVERFIT.pkl");   imgNamesList=ReadListFromTextFile("TMP/anahald_train_imgs__OVERFIT.txt");    imgNameToPredHaldId = PredictHaldsForListedImages(decTree, imgNamesList, "INP/CHOICE_DATA/real__hist.csv", outCsvPathOrEmpty="TMP/predict__OVERFIT.csv", expectedHaldCSVPathOrEmpty="INP/CHOICE_DATA/real__ana_to_hald.csv")
def PredictHaldsForListedImages(decTree, imgNamesList, histogramDictCSVPath,
                          *, histogramDictDFrame=None, outCsvPathOrEmpty="",
                                              expectedHaldCSVPathOrEmpty=""):
    if ( histogramDictDFrame is None ):
        try:
            histogramDictDFrame = pd.read_csv(histogramDictCSVPath,
                                              index_col='filename')
        except Exception as e:
            print(f"-E- Error reading histogram dictionary from '{histogramDictCSVPath}': {e}")
            return(0)
    imgNameToPredHaldId = {}
    for imgName in imgNamesList:
        haldId = PredictHaldForImageInHistogramCSV(decTree, imgName,
                  histogramDictCSVPath, histogramDictDFrame=histogramDictDFrame)
        imgNameToPredHaldId[imgName] = haldId;  # (or 0 on error)
    # if requested, output predictions
    if ( outCsvPathOrEmpty != "" ):
        # (keys should represent rows instead of columns, thus orient='index')
        df = pd.DataFrame.from_dict(imgNameToPredHaldId, orient='index',
                                    columns=['haldid'])
        # workaround: output CSV without header, since cannot build it properly
        df.to_csv(outCsvPathOrEmpty, index=True, header=False)
        print("-I- Stored %d image-name-to-HALD mapping(s) in '%s'" %
              (len(imgNameToPredHaldId), outCsvPathOrEmpty))
    # if requested, verify predicted vs. expected - compute accuracy
    if ( expectedHaldCSVPathOrEmpty != "" ):
        try:
            expDf = pd.read_csv(expectedHaldCSVPathOrEmpty,
                                index_col='AnaFileName')
        except Exception as e:
            print(f"-E- Error reading expected-hald dictionary from '{expectedHaldCSVPathOrEmpty}': {e}")
            return(0)
        imgNameToExpHaldId = expDf.to_dict(orient='index')
        # imgNameToExpHaldId == {name::{'HaldId'::haldId}}
        VerifyPredictionAccuracyForListedImages(imgNameToPredHaldId,
                               imgNameToExpHaldId, haldPrefix=_HALD_NAME_PREFIX)
    return  imgNameToPredHaldId


# Computes and returns prediction accuracy in percents.
# imgNameToPredHaldId == {src-name-without-suffix            :: predicted-haldId}
# imgNameToExpHaldId  == {name-with-hald-suffix :: {'HaldId' :: expected-haldId}}
def VerifyPredictionAccuracyForListedImages(imgNameToPredHaldId,
                               imgNameToExpHaldId, haldPrefix=_HALD_NAME_PREFIX):
    # build map of {src-name-without-suffix::name-with-hald-suffix}
    # (imgName=IMG12.TIF;  srcName=IMG12;  resultImgName=IMG12_ahg_olef_gp.JPG)
    srcNameToResultName = {}
    for resultImgName in imgNameToExpHaldId:
        ###print("Checking expected", resultImgName) 
        srcName = DetectSourceFromFilename(resultImgName, haldPrefix)
        if ( srcName is None ):
            # assume dummy "ID" HALD, thus no suffix
            #print(f"-W- Unexpected image name format: '{resultImgName}'")
            srcName = os.path.splitext(os.path.basename(resultImgName))[0]
        srcNameToResultName[srcName] = resultImgName
    # check and count HALD choices
    cntGood=0;  cntBad = 0;  cntMiss = 0;
    for imgName in imgNameToPredHaldId:
        srcName = os.path.splitext(os.path.basename(imgName))[0]
        if ( srcName not in srcNameToResultName ):
            print(f"-W- Unexpected image name: '{imgName}'")
            cntMiss += 1
            continue
        resultImgName = srcNameToResultName[srcName];  # name with HALD suffix
        if ( resultImgName in imgNameToExpHaldId ):
            expHald  = imgNameToExpHaldId[resultImgName]['HaldId']
            predHald = imgNameToPredHaldId[imgName]
            if ( expHald == predHald ):
                cntGood += 1
            else:
                cntBad  += 1
        else:
            print(f"-E- No expected for '{imgName}' - should not happen")
            cntMiss += 1
    cntAll = cntGood + cntBad + cntMiss
    acc = 100*cntGood/cntAll
    print(f"Prediction accuracy for {cntAll} image(s) is {acc}%")
    return(acc)
#################################################################################



#################################################################################
## Utilities
################################################################################
def GenerateTimestampedFilePath(dirPath, namePref, ext, nameSuffOrEmpty=""):
    if ( nameSuffOrEmpty == "" ):
        nameSuff = datetime.now().strftime("%Y%m%d-%H%M%S")
    else:
        nameSuff = nameSuffOrEmpty
    leafName = f"{namePref}__{nameSuff}.{ext}"
    fullPath = os.path.join(dirPath, leafName)
    return(fullPath)


# Saves list of text lines in a text file with auto-generated name
def DumpListIntoTextFile(linesList, dirPath, namePref, ext):
    fullPath = GenerateTimestampedFilePath(dirPath, namePref, ext)
    return(WriteListIntoTextFile(linesList, fullPath))


# Saves list of text lines in text file 'outPath'
def WriteListIntoTextFile(linesList, outPath):
    try:
        with open(outPath, 'w') as f:
            for line in linesList:
                f.write(f"{line}\n")
    except Exception as e:
        print(f"-E- Error saving text list in '{outPath}': {e}")
        return(0)
    return(1)


# Saves arbitrary string of text in text file 'outPath'
def WriteStringIntoTextFile(s, outPath):
    try:
        with open(outPath, 'w') as f:
            f.write(f"{s}")
    except Exception as e:
        print(f"-E- Error saving text string in '{outPath}': {e}")
        return(0)
    return(1)


def ReadListFromTextFile(inpPath):
    linesList = []
    try:
        with open(inpPath, 'r') as f:
            for line in f:
                linesList.append(line.strip()) # remove newline characters
    except Exception as e:
        print(f"-E- Error reading list of lines from '{inpPath}': {e}")
        return(0)
    return(linesList)
################################################################################
