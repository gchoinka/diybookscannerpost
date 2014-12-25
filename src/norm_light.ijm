/* norm_light.ijm -- ImageJ macro
 *
 * Copyright (C) 2014 Gerard Choinka
 * All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the BSD license.  See the LICENSE file for details.
 */
 
macro_title="norm_light";
macro_version=0.1;
postfix=macro_title+toString(random()*10000)

closeOnEnd=true;
bachMode=true;
showAtEnd=false;


projectionType="[Average Intensity]"

workDir="/tmp/fiji";


argvStr = getArgument();
argv = split(argvStr, "\n");

if(argv.length >= 1)
{
    workDir = argv[0];
}
else
{   
    workDir = getDirectory("Choose an work Directory");
    if(workDir == ""){
        showMessage("No Directory Choosed");
        exit();
    }
}


normDir=workDir+"/result/norm";

File.makeDirectory(normDir);

pageTypes=newArray("a4h", "lef", "rig");

if(bachMode)
{
    setBatchMode(true);
}

for(k=0; k < lengthOf(pageTypes); ++k)
{
    if(File.exists(workDir+"/links/"+pageTypes[k]+"/book.bsw"))
    {      
    run("Image Sequence...", "open=["+workDir+"/result/] increment=1 scale=100 file=["+pageTypes[k]+"] or=[] sort use");
    pagesStack="pagesStack"+toString(k)+postfix;
    rename(pagesStack);
    
    if(nSlices() == 1)
    {
      filelist = getFileList(workDir+"/result/");
      filename = "";
      for(i = 0; i < lengthOf(filelist); ++i)
      {
        if(matches(filelist[i], ".*"+pageTypes[k]+"\\.(tif|tiff|TIF|TIFF)$"))
        {
          filename = filelist[i];
          filename = substring(filename, 0, lastIndexOf(filename,"."));
        }
      }
      print(filename);
      rename(filename);
      pagesStack = filename;
    }
          
    selectImage(pagesStack);
    sliceBegin = 1;
    sliceEnd = nSlices();
    pagesStackZAVG="pagesStackZAVG"+toString(k)+postfix;
    for(j=sliceBegin; j <= sliceEnd; ++j)
    {
        selectImage(pagesStack);
        setSlice(j);

        if(j == sliceBegin)
        {
        run("Select None");
        run("Duplicate...", "title=["+pagesStackZAVG+"]");
        run("32-bit");
        }
        else
        {
        imageCalculator("Add", pagesStackZAVG, pagesStack);
        }
    }   


    selectImage(pagesStackZAVG);
    run("Divide...", "value="+toString(sliceEnd-sliceBegin+1));         
    run("Gaussian Blur...", "sigma=50");
    
    selectImage(pagesStack);
    sliceBegin = 1;
    sliceEnd = nSlices();
    minavg = 0;
    maxavg = 0;
    for(j=sliceBegin; j <= sliceEnd; ++j)
    {
        selectImage(pagesStack);
        setSlice(j);
        tonormSlice="tonormSlice"+toString(j)+postfix;
        run("Duplicate...", "title=["+tonormSlice+"]");
        run("32-bit");
        imageCalculator("Subtract stack", tonormSlice, pagesStackZAVG);
        getStatistics(area, mean, min, max, std, histogram);

        minavg = minavg + min/(sliceEnd-sliceBegin+1);
        maxavg = maxavg + max/(sliceEnd-sliceBegin+1);
        close();    
    }   


    selectImage(pagesStack);
    sliceBegin = 1;
    sliceEnd = nSlices();
    for(j=sliceBegin; j <= sliceEnd; ++j)
    {
        selectImage(pagesStack);
        setSlice(j);
        sliceName = getInfo("slice.label");
    
        if(nSlices() == 1)
        sliceName = getTitle();
        
        tonormSlice="tonormSlice"+toString(j)+postfix;
        run("Duplicate...", "title=["+tonormSlice+"]");
        run("32-bit");
        imageCalculator("Subtract stack", tonormSlice, pagesStackZAVG);
        run("Subtract...", "value="+toString(minavg)+" slice");
        run("Divide...", "value="+toString(maxavg-minavg)+" slice");
        setMinAndMax(-0.1,1.1);
        run("8-bit");

        saveto_dir = normDir  + "/" ;
        saveto_filename = sliceName + ".tiff";
        saveAs("Tiff", saveto_dir + saveto_filename);
        close();    
        print(saveto_dir + saveto_filename);
    }   
    }
}
if(bachMode && showAtEnd)
{
    setBatchMode("exit and display");
}

function getModalValue()
{
    getStatistics(area, mean, min, max, std, histogram);
    max_value=0;
    modal_value=0;
    for(i=0; i<lengthOf(histogram); ++i)
    {
        if(histogram[i] > max_value)
        {
                max_value = histogram[i];
                modal_value_tmp = i;
        }
    }
    return modal_value;  
}

eval("script", "System.exit(0);");