# bsw_run.py -- 
#
# Copyright (C) 2014 Gerard Choinka
# All rights reserved.
#
# This software may be modified and distributed under the terms
# of the BSD license.  See the LICENSE file for details.


import os
import re
import shutil
import cv
import time
import math
import subprocess
import sys


bswTemplate="""
# Book Scan Wizard Script                                                                                                                                                        
# http://bookscanwizard.sourceforge.net                                                                                                                                                                                                                                                                                      
                                                                                                                                                                                                                                                                                                                                                                  
# the source directory                                                                                                                                                           
LoadImages = {LoadImages}                                                                                                                                      
                                                                                                                                                                                 
# Override source DPI e.g. 300                                                                                                                                                            
SetSourceDPI = {SetSourceDPI}                                                                                                                                                               
                                                                                                                                                                                 
# The Destination directory e.g. tiff                                                                                                                                                     
SetDestination = {SetDestination}                                                                                                                                                            
                                                                                                                                                                                 
# Sets the final DPI and compression
SetTiffOptions = {SetTiffOptionsFinalDPI} NONE

# Configure all pages
Pages=all
Rotate = {Rotate}

#740,695, 4921,683, 5103,6698, 820,6869 # image0003lef R
PerspectiveAndCrop = {PerspectiveAndCrop} 

#Pages = all
#RemovePages = image0000rig, image0234lef, image0004rig, image0005lef, image0007lef, image0006rig
"""
class BswTemplateSettingWasNotSet(BaseException):
    def __init__(self, name):
        BaseException.__init__(self) 
        self.name=name

class BswTemplateSettingNode(object):
    def __init__(self, settingName, settingDefault, settingNeed, disable, comment, prefixLine, postfixLine):
        self.settingName = settingName
        self.settingDefault = settingDefault
        self.settingNeed = settingNeed
        self.value = None
        self.disable = False
        self.comment = comment
        self.prefixLine = prefixLine
        self.postfixLine = postfixLine
        
    def setValue(self, value):
        self.value = value

    def getValue(self):
        return self.value
        
    def getValue2(self):
        if self.getValue() != None:
            return self.getValue()
        elif not self.isNeeded():
            return self.settingDefault
        else:
            raise BswTemplateSettingWasNotSet(self.getKey())
        
    def getKey(self):
        return self.settingName
        
    def isNeeded(self):
        return self.settingNeed
        
    def getDefaut(self):
        return self.settingDefault
        
    def hasValue(self):
        return self.value != None
        
class BswTemplate(object):
    
    templateSettings=[
        BswTemplateSettingNode("LoadImages",None, True, False, "the source directory", "", ""),
        BswTemplateSettingNode("SetDestination",None, True, False, "The Destination directory e.g. tiff", "", ""),
        BswTemplateSettingNode("SetSourceDPI",None, True, False, "Override source DPI e.g. 300", "", ""),
        BswTemplateSettingNode("SetTiffOptions","300 NONE", False, False, "Sets the final DPI and compression", "", ""),
        BswTemplateSettingNode("Rotate",None, False, False, "do rotate? -90,0,90, 180", "Pages=all", ""),
        BswTemplateSettingNode("PerspectiveAndCrop",None, False, True, "4 corners", "", ""),
        BswTemplateSettingNode("ScaleToDPI",None, False, True, "", "", ""),  
        BswTemplateSettingNode("Color",None, False, True, "", "", "")   
        ]
    
    def __init__(self):
        self.settings=BswTemplate.templateSettings
        
    def setSetting(self, key, value):
        for s in range(0, len(self.settings)):
            if self.settings[s].getKey() == key:
                self.settings[s].setValue(value)
                break
    
        
    def getFile(self):
        filecontent=""

        for s in range(0, len(self.settings)):
            if self.settings[s].hasValue() and not self.settings[s].disable:
                filecontent += "#"+self.settings[s].comment+"\n"
                filecontent += self.settings[s].prefixLine+"\n"
                filecontent += self.settings[s].getKey() + "="+self.settings[s].getValue2()+"\n"
                filecontent += self.settings[s].postfixLine+"\n"
                


        return filecontent
        



if len(sys.argv) >= 1:
    workdir=sys.argv[1]
else:
    print("Missing argumnet",)
    exit(2)
    
camPosfixes=["lef", "rig", "a4h"]


def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc: # Python >2.5
        if exc.errno == errno.EEXIST:
            pass
        else: 
            raise


imgDir=workdir+"/raw";




filesInImageDir = os.listdir(imgDir)                  

onlyJpegFilter = re.compile(".jpg$", re.IGNORECASE)
filesOnlyJpeg = [f for f in filesInImageDir if onlyJpegFilter.search(f)] 


linkDir=workdir+"/links"
resDir=workdir+"/result"
infoDir=workdir+"/info"
if os.path.exists(linkDir): shutil.rmtree(linkDir)
if os.path.exists(resDir):  shutil.rmtree(resDir)
if os.path.exists(infoDir): shutil.rmtree(infoDir)

mkdir_p(resDir)
mkdir_p(infoDir)



roi = [(0,0), (0,0), (0,0), (0,0)]
roiPointcurrent = 0
doRotate = False
refresh=False
length_mm=0

def doRefresh():
    global refresh
    global outputbuffer
    global image
    global length_mm
    
    font = cv.InitFont(cv.CV_FONT_HERSHEY_SIMPLEX,3,3,1)
    outputbuffer = cv.CloneImage(image)

    cv.Line(outputbuffer, roi[0], roi[1], cv.Scalar(255,255,255,255))
    cv.Line(outputbuffer, roi[1], roi[2], cv.Scalar(255,255,255,255))
    cv.Line(outputbuffer, roi[2], roi[3], cv.Scalar(255,255,255,255))
    cv.Line(outputbuffer, roi[3], roi[0], cv.Scalar(255,255,255,255))

    cv.PutText(outputbuffer, "0", roi[0], font, cv.Scalar(255,255,255,255))
    cv.PutText(outputbuffer, "1", roi[1], font, cv.Scalar(255,255,255,255))
    cv.PutText(outputbuffer, "2", roi[2], font, cv.Scalar(255,255,255,255))
    cv.PutText(outputbuffer, "3", roi[3], font, cv.Scalar(255,255,255,255))
    
    cv.PutText(outputbuffer, "vSide %04dmm"%length_mm, (300,300), font, cv.Scalar(255,255,255,255))
    cv.ShowImage('a_window', outputbuffer)
    refresh = False

def on_mouse (event, x, y, flags, param):
    global roiPointcurrent
    global image
    global roi
    global refresh
    global doRotate
    
    if event == cv.CV_EVENT_LBUTTONDOWN:
        roi[roiPointcurrent] = (x,y)
        refresh = True
        
    if event == cv.CV_EVENT_RBUTTONDOWN:
        roiPointcurrent=(roiPointcurrent+1) % 4
        
    if doRotate == True:        
        timg = cv.CreateImage((image.height,image.width), image.depth, image.channels)
        cv.Transpose(image, timg);
        cv.Flip(timg, timg, 1);
        image = cv.CloneImage(timg)
        doRotate = False
        refresh = True
    
    if refresh:
        doRefresh()


cv.NamedWindow('a_window',0)       
cv.SetMouseCallback('a_window', on_mouse, None)

bswFiles=[]
        
for posfixe in camPosfixes:
    thisLinkDir=linkDir+"/"+posfixe
    mkdir_p(thisLinkDir)
    camPosfixesFilter = re.compile(posfixe+".jpg$", re.IGNORECASE)
    files = [f for f in filesOnlyJpeg if camPosfixesFilter.search(f)] 
    
    if len(files) == 0:
        continue
    
    
    for f in files:
        os.symlink(imgDir+"/"+f, thisLinkDir+"/"+f);
        
    
    roi = [(0,0), (0,0), (0,0), (0,0)]
    roiPointcurrent=0
    aFile = thisLinkDir+"/"+files[len(files)/2]
    image=cv.LoadImage(aFile, cv.CV_LOAD_IMAGE_COLOR)

    overlay = cv.CloneImage(image)
    outputbuffer = cv.CloneImage(image)    

    cv.ShowImage('a_window', outputbuffer)
    
    length_mm_tup = str()
    goon = True
    while goon:
        key = cv.WaitKey()
        if(key == 27): #esc
            goon = False
        if key == 65288: # backspace
            length_mm_tup = length_mm_tup[:len(length_mm_tup)-1]
            length_mm = int("0"+length_mm_tup)
            refresh = True
        if key == 65361: # left
            doRotate= True
        if key == 10: #enter
            if length_mm == 0:
                print("Please give a length of the long side of the book in mm")
            else:
                goon = False
        if key >= ord('0') and key <= ord('9'):
            length_mm_tup += chr(key)
            length_mm = int("0"+length_mm_tup)
            refresh = True
            
        if refresh:
            doRefresh()
            
    
    leftside_a=math.fabs(roi[0][0]-roi[3][0])
    leftside_b=math.fabs(roi[0][1]-roi[3][1])
    
    leftside_c=math.sqrt(leftside_a*leftside_a+leftside_b*leftside_b)
    
    rightside_a=math.fabs(roi[1][0]-roi[2][0])
    rightside_b=math.fabs(roi[1][1]-roi[2][1])
    
    rightside_c=math.sqrt(rightside_a*rightside_a+rightside_b*rightside_b)
    
    sourcedpi = math.floor((leftside_c+rightside_c)*0.5)/length_mm*25.4
    destinationspi = 170
    
        
    bswt = BswTemplate();

    bswt.setSetting("LoadImages", thisLinkDir)
    bswt.setSetting("SetDestination", resDir)
    bswt.setSetting("SetSourceDPI", "%d" % sourcedpi)
    bswt.setSetting("SetTiffOptions", "%d NONE" % destinationspi)
    bswt.setSetting("ScaleToDPI", "%d" % destinationspi)
    bswt.setSetting("Color", "gray")
    pandc="%d,%d %d,%d %d,%d %d,%d" % (roi[0][0],roi[0][1],roi[1][0],roi[1][1],roi[2][0],roi[2][1],roi[3][0],roi[3][1]) 
    bswt.setSetting("PerspectiveAndCrop", pandc)
    configFile= bswt.getFile()
    
    f = open(thisLinkDir+"/book.bsw", 'w')
    f.write(configFile)
    f.close()
    
    bswFiles.append(thisLinkDir+"/book.bsw")
   
    
cv.DestroyWindow('a_window') 
















