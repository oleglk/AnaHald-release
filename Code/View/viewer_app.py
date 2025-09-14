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

# viewer_app.py

import os
import sys

from tkinter import *

# loading Python Imaging Library
from PIL import ImageTk, Image

# To get the dialog box to open when required 
from tkinter import filedialog




################## HOW TO LOAD THE CODE #########################################
# DT2022:
# import sys;  sys.path.append('C:\\Oleg\\Gitwork\\Anahald\\Code\\View')
# import os;  os.chdir(r'D:\Work\RMA_WA')
# from viewer_app import *

# SZBOX12
# import sys;  sys.path.append('C:\\ANY\\Gitwork\\Anahald\\Code\\View')
# import os;  os.chdir('C:\\ANY\\Gitwork\\Anahald')
# from viewer_app import *


# RELOAD:
# import importlib;  import viewer_app;  importlib.reload(viewer_app);  from viewer_app import *;  import view_contr;  importlib.reload(view_contr);  from view_contr import *;  import halder;  importlib.reload(halder);  from halder import *;  import choose_hald_base;  importlib.reload(choose_hald_base);  from choose_hald_base import *;  import AnahaldDataset;  importlib.reload(AnahaldDataset);  from AnahaldDataset import *;  import search_ana;  importlib.reload(search_ana);  from search_ana import *
#################################################################################


SCRIPT_PATH = os.path.realpath(__file__)
VIEWER_DIR  = os.path.dirname(SCRIPT_PATH)
sys.path.append(VIEWER_DIR)
CHOICE_DIR  = os.path.join(VIEWER_DIR, "..", "Choice")
sys.path.append(CHOICE_DIR)

HALD_ROOT  = os.path.join(VIEWER_DIR, "..", "..", "SAMPLE_HALDS")
HALD_DIRS = [HALD_ROOT, os.path.join(HALD_ROOT, "ADD")]


from halder import *
from view_contr import *
from viewer_gui import *



########################### Utilities ###########################################


########################### MAIN ################################################
root = Tk()

view = AhViewerGUI(root)
model = Halder("", HALD_DIRS, outDir="")  # TODO: take outDir from cmd-line
controller = AhViewController(view, model)

view.set_controller(controller)

root.mainloop()
