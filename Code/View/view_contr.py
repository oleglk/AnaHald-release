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

# view_contr.py - MVC controller for Anahald Viewer


from datetime import datetime
import os
import sys
from pathlib import Path
import re
import subprocess
from PIL import Image
from tempfile import TemporaryDirectory



################## HOW TO LOAD THE CODE #########################################
# DT2022:
# import sys;  sys.path.append('C:\\Oleg\\Gitwork\\Anahald\\Code\\View')
# from view_contr import *
# import os;  os.chdir(r'D:\Work\RMA_WA')

# SZBOX12
# import sys;  sys.path.append('C:\\ANY\\Gitwork\\Anahald\\Code\\View')
# from view_contr import *
# import os;  os.chdir('C:\\ANY\\Gitwork\\Anahald')


# RELOAD:
# import importlib;  import view_contr;  importlib.reload(view_contr);  from view_contr import *;  import halder;  importlib.reload(halder);  from halder import *;  import choose_hald_base;  importlib.reload(choose_hald_base);  from choose_hald_base import *;  import AnahaldDataset;  importlib.reload(AnahaldDataset);  from AnahaldDataset import *;  import search_ana;  importlib.reload(search_ana);  from search_ana import *
#################################################################################


SCRIPT_PATH = os.path.realpath(__file__)
VIEWER_DIR  = os.path.dirname(SCRIPT_PATH)
sys.path.append(VIEWER_DIR)
CHOICE_DIR  = os.path.join(VIEWER_DIR, "..", "Choice")
sys.path.append(CHOICE_DIR)

from halder import *
from viewer_gui import *


class AhViewController:
    def  __init__(self, view, model):
        self.view = view
        self.model = model
        self.view.rootWnd.protocol("WM_DELETE_WINDOW", self.on_closing)
    ####


    # Obtains SBS path, instructs conroller to make default anaglyph.
    # Returns (anaglyph-path, hald-id, gamma)
    def point_at_image(self, sbsPath):
        try:
            self.model.point_at_image_or_dir(sbsPath)
        except Exception as e:
            print(f"-E- Failed to show image: {e}")
            return("", "ahg_oleg_id", 1.0)  # "" indicates failure to switch image
        return(self.model.currAnaPath,
               self.model.currHaldId, self.model.currGamma)


    def goto_prev(self):
        try:
            ret = self.model.switch_image("-")
        except Exception as e:
            print(f"-E- Failed to show previous image: {e}")
            return(0)  # 0 indicates failure to switch image
        return(ret)

    def goto_next(self):
        try:
            ret = self.model.switch_image("+")
        except Exception as e:
            print(f"-E- Failed to show next image: {e}")
            return(0)  # "" indicates failure to switch image
        return(ret)

        
    def get_haldid_list(self):
        haldIdToFile = self.model.get_haldid_to_filename_map()
        return(["ahg_oleg_id"] + [x for x in haldIdToFile.keys()])


    def apply_hald_and_gamma(self, haldId, gamma, isPreview):
        if ( self.model.switch_hald_and_gamma(haldId=haldId, gamma=gamma,
                                              isPreview=isPreview) ):
            return(self.model.currAnaPath)
        else:
            return("")

        
    def auto_choose_hald_and_gamma(self):
        return(self.model.auto_choose_hald_and_gamma())

    
    def on_closing(self):
        self.model.clean_tmp_dir()
        self.view.rootWnd.destroy()  # Destroy the window and exit the mainloop


