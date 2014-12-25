/* whiteup.ijm -- ImageJ macro
 *
 * Copyright (C) 2014 Gerard Choinka
 * All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the BSD license.  See the LICENSE file for details.
 */
 
 
macro_title="whiteup";
macro_version=0.1;
postfix=macro_title+toString(random()*10000)

closeOnEnd=true;
bachMode=true;
showAtEnd=false;

function noLogWindowPrint(s)
{
    if(!bachMode)
        print(s);
}

projectionType="[Average Intensity]"

workDir="/tmp/fiji";
destinationDPI = newArray(170, 300);




argvStr = getArgument();
argv = split(argvStr, "\n");


if(argv.length >= 1)
{
    workDir = argv[0];
}
else
{   
    workDir = getDirectory("Choose an work Directory");
    if(workDir == "")
    {
        showMessage("No Directory Choosed");
        exit();
    }
}


normDir=workDir+"/result/norm";
whiteDir=workDir+"/result/white";
gr170Dir=workDir+"/result/gr170";
gr300Dir=workDir+"/result/gr300";
sw170Dir=workDir+"/result/sw170";
sw300Dir=workDir+"/result/sw300";


File.makeDirectory(normDir);
File.makeDirectory(whiteDir);
File.makeDirectory(gr170Dir);
File.makeDirectory(gr300Dir);
File.makeDirectory(sw170Dir);
File.makeDirectory(sw300Dir);

pageTypes=newArray("a4h", "lef", "rig");

if(bachMode)
{
    setBatchMode(true);
}

for(k=0; k < lengthOf(pageTypes); ++k)
{        
    if(File.exists(workDir+"/links/"+pageTypes[k]+"/book.bsw"))
    {
        bswFileContent = File.openAsString(workDir+"/links/"+pageTypes[k]+"/book.bsw");
        bswFileLines   = split(bswFileContent, "\n");

        srcDpi = 300;
        for(i = 0; i < lengthOf(bswFileLines); ++i)
        {
            if(matches(bswFileLines[i], "SetSourceDPI.*"))
            {
                srcDpi=parseFloat(replace(replace(bswFileLines[i], "SetSourceDPI[^=]*=[ ]*", ""), "#.*$", "")); 
            }
        }


        run("Image Sequence...", "open=["+normDir+"] increment=1 scale=100 file=["+pageTypes[k]+"] or=[] sort use");
        pagesStack="pagesStack"+toString(k)+postfix;
        rename(pagesStack);

        if(nSlices() == 1)
        {
            filelist = getFileList(normDir);
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

        modal_value = 0;
        selectWindow(pagesStack);
        sliceBegin = 1;
        sliceEnd=nSlices();
        for(j=sliceBegin;j <= sliceEnd; ++j)
        {
            selectWindow(pagesStack);
            setSlice(j);
            getStatistics(area, mean, min, max, std, histogram);

            max_value=0;
            modal_value_tmp=0;
            for(i=0; i<lengthOf(histogram); ++i)
            {
                if(histogram[i] > max_value)
                {
                    max_value = histogram[i];
                    modal_value_tmp = i;
                }
            }
            modal_value = modal_value + modal_value_tmp/(sliceEnd-sliceBegin+1);
        }
        
        modal_value = modal_value * 1.05;

        for(j=sliceBegin;j <= sliceEnd; ++j)
        {
            selectWindow(pagesStack);
            setSlice(j);
            sliceName = getInfo("slice.label");
            if(nSlices() == 1)
                sliceName = getTitle();

            tonormSlice="tonormSlice"+toString(j)+postfix;
            run("Duplicate...", "title=["+tonormSlice+"]");
            run("Multiply...", "value="+toString(255.0/modal_value,6));
        
            gr170Img="gr170Img"+toString(j)+postfix;
            gr300Img="gr300Img"+toString(j)+postfix;
            sw170Img="sw170Img"+toString(j)+postfix;
            sw300Img="sw300Img"+toString(j)+postfix;

            
            
            selectWindow(tonormSlice);
            run("Scale...", "x="+toString(170/srcDpi)+" y="+toString(170/srcDpi)+" width=[] height=[] interpolation=Bilinear average create title=["+gr170Img+"]");
            saveto_dir = gr170Dir  + "/" ;
            saveto_filename = sliceName + ".jpeg";
            saveAs("Jpeg", saveto_dir + saveto_filename);
            close();  
            
            selectWindow(tonormSlice);
            run("Scale...", "x="+toString(300/srcDpi)+" y="+toString(300/srcDpi)+" width=[] height=[] interpolation=Bilinear average create title=["+gr300Img+"]");
            saveto_dir = gr300Dir  + "/" ;
            saveto_filename = sliceName + ".jpeg";
            saveAs("Jpeg", saveto_dir + saveto_filename);
            close();  
            
            selectWindow(tonormSlice);
            run("Scale...", "x="+toString(170/srcDpi)+" y="+toString(170/srcDpi)+" width=[] height=[] interpolation=Bilinear average create title=["+sw170Img+"]");
            run("Make Binary", "method=Yen background=Dark calculate");
            saveto_dir = sw170Dir  + "/" ;
            saveto_filename = sliceName + ".tiff";
            saveAs("Tiff", saveto_dir + saveto_filename);
            close();  
            
            selectWindow(tonormSlice);
            run("Scale...", "x="+toString(300/srcDpi)+" y="+toString(300/srcDpi)+" width=[] height=[] interpolation=Bilinear average create title=["+sw300Img+"]");
            run("Make Binary", "method=Yen background=Dark calculate");
            saveto_dir = sw300Dir  + "/" ;
            saveto_filename = sliceName + ".tiff";
            saveAs("Tiff", saveto_dir + saveto_filename);
            close();  
            
            selectWindow(tonormSlice);
            saveto_dir = whiteDir  + "/" ;
            saveto_filename = sliceName + ".tiff";
            saveAs("Tiff", saveto_dir + saveto_filename);
            close();   
            noLogWindowPrint(saveto_dir + saveto_filename);
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