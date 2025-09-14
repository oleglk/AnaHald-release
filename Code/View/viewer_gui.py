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

# viewer_gui.py - see https://www.geeksforgeeks.org/python/loading-images-in-tkinter-using-pil/

import os
import tkinter as tk
from tkinter import *
from tkinter import ttk

# loading Python Imaging Library
from PIL import ImageTk, Image

# To get the dialog box to open when required 
from tkinter import filedialog

# rely on 'Choice\' directory being already in sys.path
from ah_cfg import *             # configuration settings


APP_NAME = "Anahald Image Viewer"


class AhViewerGUI:
    """GUI for choosing Anahald sample HALDs for an image
    """
    def __init__(self, rootWnd):
        self.controller = None
        
        self.minWinWidth     = 800 #1024
        self.minWinHeight    = 600 #720
        if ( (AhConfig.WINDOW_WIDTH  < self.minWinWidth)    or
             (AhConfig.WINDOW_HEIGHT < self.minWinHeight)   or
             (AhConfig.WINDOW_WIDTH  > rootWnd.winfo_screenwidth()) or
             (AhConfig.WINDOW_HEIGHT > rootWnd.winfo_screenheight()) ):
            msg = f"Window dimensions must be {self.minWinWidth}x{self.minWinHeight}...{rootWnd.winfo_screenwidth()}x{rootWnd.winfo_screenheight()}; please fix in Code/Choice/ah_cfg.py"
            print(f"-E- {msg}")
            tk.messagebox.showerror("Configuration error", msg)
            self.winWidth     = self.minWinWidth
            self.winHeight    = self.minWinHeight
        else:
            self.winWidth     = AhConfig.WINDOW_WIDTH
            self.winHeight    = AhConfig.WINDOW_HEIGHT
        self.maxImgWidth  = self.maxImgHeight = int(self.winHeight / 1.25)

        self.currImgPath = None
        self.rootWnd = rootWnd

        self.halds = []
        self.haldsStringVar = StringVar()

        self.gammaValVar    = DoubleVar()  # will reflect gamma scale

        # Set Title as Image Loader
        self.rootWnd.title(APP_NAME)
        # Set the resolution of window
        self.rootWnd.geometry(f"{self.winWidth}x{self.winHeight}+10+10")
        # Prohibit Window to be resizable
        self.rootWnd.resizable(width = False, height = False)

        # Create open-image button and place it into the window using grid layout
        btnOpen = Button(self.rootWnd, text ='Open SBS image',
                         command=self.open_img, underline=0)
        btnOpen.grid(column = 0, row=3, columnspan=1, pady=5)
        self.rootWnd.bind("<o>", lambda event: btnOpen.invoke())

        # Create file-browsing buttons(prev, next)
        btnPrev = Button(self.rootWnd, text ='Prev',
                         command=self.prev_img, underline=0)
        btnPrev.grid(column = 1, row=3, columnspan=1, pady=5)
        self.rootWnd.bind("<p>", lambda event: btnPrev.invoke())
        btnNext = Button(self.rootWnd, text ='Next',
                         command=self.next_img, underline=0)
        btnNext.grid(column = 2, row=3, columnspan=1, pady=5)
        self.rootWnd.bind("<n>", lambda event: btnNext.invoke())

        # Create preview-hald button and place it into the window using grid layout
        self.btnPreview = Button(self.rootWnd, text ='Preview',
                   command=lambda: self.apply_hald_and_gamma(True), underline=1)
        self.btnPreview.grid(column = 3, row=3, columnspan=1, pady=5)
        self.btnPreview.config(state=tk.DISABLED)  # no image, nothing to preview
        self.rootWnd.bind("<r>", lambda event: self.btnPreview.invoke())

        # Create save-result button and place it into window using grid layout
        self.btnSave = Button(self.rootWnd, text ='Save',
                   command=lambda: self.apply_hald_and_gamma(False), underline=0)
        self.btnSave.grid(column = 3, row=4, columnspan=1, pady=5)
        self.btnSave.config(state=tk.DISABLED)  # no image, nothing to save
        self.rootWnd.bind("<s>", lambda event: self.btnSave.invoke())

        # Create empty HALD-id listbox
        ttk.Label(self.rootWnd, text="Select HALD:", underline=7
                  ).grid(column=4, row=1, sticky="sew", pady=5)
        self.haldListbox = Listbox(self.rootWnd, height=10,
                                   listvariable=self.haldsStringVar)
        self.haldListbox.grid(column=4, row=2, rowspan=1, sticky="nsew",
                              padx=5, pady=5)
        # enabled "Preview" button indicates changes not reflected by shown image
        self.haldListbox.bind("<<ListboxSelect>>",
                              lambda e: self.btnPreview.config(state=tk.NORMAL))
        hlSc = Scrollbar(self.rootWnd, orient=tk.VERTICAL,
                         command=self.haldListbox.yview)
        hlSc.grid(column=5, row=2, rowspan=1, sticky="ns")
        self.haldListbox.config(yscrollcommand=hlSc.set)
        self.rootWnd.bind("h", self.set_focus_on_halds)

        self.progress = ttk.Label(self.rootWnd, text="Idle")
        self.progress.grid(column = 1, row=4, columnspan=2, pady=5)

        # Create gamma scale with label; make gamma-scale selectable
        self.gammaLbl = Label(self.rootWnd, text="Current Gamma: 1.00",
                              underline=8)
        self.gammaLbl.grid(column=4, row=3, pady=5)
        self.gammaLbl.bind("<Button-1>", self.set_focus_on_gamma)
        self.gammaScl = Scale(self.rootWnd, from_=0.5, to=1.5, resolution=0.01,
                    orient=tk.HORIZONTAL, takefocus=1, highlightthickness = 1,
                    variable=self.gammaValVar, command=self.update_gamma_label)
        self.gammaScl.grid(column=4, row=4, pady=5)
        self.gammaScl.bind("<Button-1>", self.set_focus_on_gamma)
        self.rootWnd.bind("g", self.set_focus_on_gamma)
        self.gammaValVar.set(1.0)

        # Create auto-choice button
        self.btnAuto = Button(self.rootWnd, text ='Auto',
                              command=self.auto_choose_hald_and_gamma, underline=0)
        self.btnAuto.grid(column = 0, row=4, columnspan=1, pady=5)
        self.rootWnd.bind("<a>", lambda event: self.btnAuto.invoke())
        self.btnAuto.config(state=tk.DISABLED)  # no image, nothing to save

        # Create a label to host the image
        self.panel = Label(self.rootWnd, text=AhViewerGUI._help_str(),
                           fg="lightgrey", bg="black", font="TkHeadingFont")
        self.panel.grid(row=1, columnspan=4, rowspan=2,  sticky="NESW")

        rootWnd.rowconfigure(0, weight=0)  # reserved
        rootWnd.rowconfigure(1, weight=1)  # image
        rootWnd.rowconfigure(2, weight=1)  # image, hald-list
        rootWnd.rowconfigure(3, weight=0)  # buttons, gamma-scale
        rootWnd.rowconfigure(4, weight=0)  # buttons, progress-bar, gamma-scale
        rootWnd.columnconfigure(0, weight=1)  # image, 'Load', 'Auto'
        rootWnd.columnconfigure(1, weight=1)  # image, 'Prev', progress
        rootWnd.columnconfigure(2, weight=1)  # image, 'Next', progress
        rootWnd.columnconfigure(3, weight=1)  # image, 'Preview', 'Save'
        rootWnd.columnconfigure(4, weight=1)  # hald-list, gamma-scale
        rootWnd.columnconfigure(5, weight=0)  # hald-list-scrollbar
    ####

    def set_controller(self, contr):
        self.controller = contr
        self.halds = self.controller.get_haldid_list()
        print(f"-I- Available HALDs: ({self.halds})")
        self.haldsStringVar.set(self.halds)
        
        
    # Select SBS image file unless provided, show its anaglyph, return the anaglyph path
    def open_img(self, sbsPath=None):
        oldState_btnPreview = self.btnPreview["state"]
        self.btnPreview.config(state=tk.DISABLED)  # nothing to apply upon show
        if ( sbsPath is None ):
            # Select the Imagename  from a folder 
            sbsPath = AhViewerGUI._openfilename()
        if ( sbsPath == "" ):
            self.btnPreview.config(state=oldState_btnPreview)  #
            self.progress.config(text="Idle"); self.rootWnd.update_idletasks()
            return("")  # assume dialog was canceled

        self.progress.config(text="Working..."); self.rootWnd.update_idletasks()
        # Command to make anaglyph
        anaPath, haldId, gamma = self.controller.point_at_image(sbsPath)
        if ( anaPath == "" ):
            #print(f"-E- Failed processing '{sbsPath}'")
            tk.messagebox.showerror("Viewer error",
                                    f"Failed processing '{sbsPath}'")
            self.btnPreview.config(oldState_btnPreview)  #
            self.progress.config(text="Idle"); self.rootWnd.update_idletasks()
            return("")
        else:
            self.btnAuto.config(state=tk.NORMAL)  #

        return(self.show_new_image_anaglyph(anaPath))


    # Reset processing controls and show the given anaglyph image
    def show_new_image_anaglyph(self, anaPath):
        currSelect = self.haldListbox.curselection()
        if ( len(currSelect) > 0 ):
            self.haldListbox.selection_clear(currSelect[0])
        self.haldListbox.selection_set(0)        # reset HALD to "ahg_oleg_id"
        self.haldListbox.see(0)
        self.gammaValVar.set(1.0);  self.reset_gamma_label() # reset gamma to 1.0
        ret = self.show_image(anaPath)
        self.progress.config(text="Idle"); self.rootWnd.update_idletasks()
        self.btnSave.config(state=tk.NORMAL)  #
        return(ret)

    
    def prev_img(self):
        anaPath = self.controller.goto_prev()
        if ( anaPath == 0 ):
            tk.messagebox.showerror("Viewer error",
                                    f"Cannot switch to the previous image")
            return("")
        print(f"-D- Viewer got prev image '{anaPath}'")
        if ( (anaPath == "") or (anaPath == 0) ):    # at end or error
            return("")
        return(self.show_new_image_anaglyph(anaPath))

    def next_img(self):
        anaPath = self.controller.goto_next()
        if ( anaPath == 0 ):
            tk.messagebox.showerror("Viewer error",
                                    f"Cannot switch to the next image")
            return("")
        print(f"-D- Viewer got next image '{anaPath}'")
        if ( (anaPath == "") or (anaPath == 0) ):    # at end or error
            return("")
        return(self.show_new_image_anaglyph(anaPath))

    
    def show_image(self, anaPath):
        # open the anaglyph image
        img = Image.open(anaPath)
    
        # resize the image and apply a high-quality down sampling filter
        newW, newH = AhViewerGUI._fit_image_size(img.width, img.height,
                                     self.maxImgWidth, self.maxImgHeight)
        print(f"Image view size: {newW}x{newH}")
        img = img.resize((newW, newH), Image.LANCZOS)

        # PhotoImage class is used to add image to widgets, icons etc
        img = ImageTk.PhotoImage(img)

        # set the panel image to 'img'
        self.panel.image = img
        self.panel['image'] = img

        
        #self.btnPreview.config(state=tk.DISABLED)  # nothing to apply upon show
        self.rootWnd.title(f"{APP_NAME}:  {os.path.basename(anaPath)}")
        return(anaPath)
    ####


    def apply_hald_and_gamma(self, isPreview):
        haldIdIdxList = self.haldListbox.curselection()
        haldIdIdx = haldIdIdxList[0]  if  ( len(haldIdIdxList) > 0 )  else  0
        haldId = self.halds[haldIdIdx]
        self.progress.config(text="Working...")
        self.rootWnd.update_idletasks()
        gamma = self.gammaValVar.get()
        anaPath = self.controller.apply_hald_and_gamma(haldId, gamma, isPreview)
        self.progress.config(text="Idle")
        self.rootWnd.update_idletasks()
        if ( isPreview and (anaPath != "") ):
            self.btnPreview.config(state=tk.DISABLED)
            return(self.show_image(anaPath))
        else:
            return("")
    ####


    def auto_choose_hald_and_gamma(self):
        self.progress.config(text="Working...")
        haldId, gamma = self.controller.auto_choose_hald_and_gamma()
        self.progress.config(text="Idle")
        if ( haldId == "" ):
            tk.messagebox.showwarning("Auto-choice unavailable", "Auto-choice is not properly configured")
            return
        haldIdxInList = self._find_haldid_index(haldId)
        print(f"-D- Auto-selected HALD '{haldId}' at listbox-index {haldIdxInList}")
        if ( haldIdxInList == -1 ):
            haldIdxInList = self._find_haldid_index("ahg_oleg_id")  # must exist
            gamma = 1.0
            tk.messagebox.showwarning(f"Auto-choice returned unknown LUT '{haldId}'")

        self.haldListbox.select_clear(0, END)
        self.haldListbox.select_set(haldIdxInList)
        self.gammaValVar.set(gamma)
        self.update_gamma_label(gamma)
        self.btnPreview.config(state=tk.NORMAL)
####

    
    def update_gamma_label(self, val):
        self.gammaLbl.config(text=f"Current Gamma: {float(val):.2f}")
        self.btnPreview.config(state=tk.NORMAL)  # change in gamma - allow preview
    ####

    def reset_gamma_label(self):
        self.gammaLbl.config(text=f"Current Gamma: 1.00")
    ####

        
    def set_focus_on_halds(self, event):
        """Callback function to set focus on the HALD listbox."""
        self.haldListbox.focus_set()

        
    def set_focus_on_gamma(self, event):
        """Callback function to set focus on the gamma scale."""
        self.gammaScl.focus_set()


    def _find_haldid_index(self, haldId):
        haldList = self.haldListbox.get(0, END)
        # haldList = self.haldsStringVar.get()  # returns a string - inconvenient
        #print(f"-D- _find_haldid_index({haldList})")
        try:
            index = haldList.index(haldId)
        except ValueError:
            return(-1)
        return(index)


    ##################### Utilities #############################################
    @staticmethod
    def _openfilename():
        # open file dialog box to select image
        # The dialogue box has a title "Open"
        filename = filedialog.askopenfilename(title ='Open')
        return filename    

    @staticmethod
    def _fit_image_size(oldW, oldH, maxW, maxH):
        width_ratio = maxW / oldW
        height_ratio = maxH / oldH
        scaling_factor = min(width_ratio, height_ratio)
        newW = int(oldW * scaling_factor)
        newH = int(oldH * scaling_factor)
        return(newW, newH)

    @staticmethod
    def _help_str():
        formatStr = "TIFF"  if  ( AhConfig.MAKE_TIFF )  else  "JPEG"
        hs = f"""
Anahald Image Viewer
(Oleg Kosyakovsky, 2025)


Open first image with <Open SBS image> button,
then browse using <Prev> and <Next>.

Select HALD LUT and gamma,
then press <Preview> to render the image on-screen.

Press <Save> to store full-size image
in '{AhConfig.OUTDIR_NAME}' folder in {formatStr} format.

If properly configured, pressing <Auto> button
selects recommended HALD LUT and gamma;
press <Preview> to observe the effect.
"""
        return(hs)
############ End of class AhViewerGUI ###########################################


##################### Main      ################################################
# # Create a window
# root = Tk()

# AhViewerGUI(root)

# root.mainloop()
