/* norm_light.ijm -- ImageJ macro
 *
 * Copyright (C) 2014 Gerard Choinka
 * All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the BSD license.  See the LICENSE file for details.
 */

macro_title="bswclone";
macro_version=0.3;

postfix=macro_title+toString(random()*10000)

dialog_title = macro_title + " v" + d2s(macro_version, 2);

bachMode=true;
showAtEnd=false;

function noLogWindowPrint(s)
{
    if(!bachMode)
        print(s);
}

argvStr = getArgument();
argv = split(argvStr, "\n");

if(argv.length >= 1)
{
    bswFileName = argv[0];
}
else
{   

    bswFileName = File.openDialog("Choose an BSW File");
    if(bswFileName == "")
    {
        showMessage("No File Choosed");
        exit();
    }
}

if(!File.exists(bswFileName))
{
    noLogWindowPrint("The File \""+bswFileName+"\" does not Exist, "+macro_title+" closes\n");
    eval("script", "System.exit(0);"); 
    exit();
}

x=newArray(0, 0, 0, 0);
y=newArray(0, 0, 0, 0);

bswFileContent = File.openAsString(bswFileName);
bswFileLines = split(bswFileContent, "\n");

for(i = 0; i < lengthOf(bswFileLines); ++i)
{
    if(matches(bswFileLines[i], "LoadImages.*"))
    {       
        srcDir=replace(replace(bswFileLines[i], "LoadImages[^=]*=[ ]*", ""), "#.*$", "");; 
    }
    if(matches(bswFileLines[i], "SetSourceDPI.*"))
    {
        srcDpi=parseFloat(replace(replace(bswFileLines[i], "SetSourceDPI[^=]*=[ ]*", ""), "#.*$", "")); 
    }
    if(matches(bswFileLines[i], "SetDestination.*"))
    {       
        resultDir=replace(replace(bswFileLines[i], "SetDestination[^=]*=[ ]*", ""), "#.*$", "");; 
    }
    if(matches(bswFileLines[i], "PerspectiveAndCrop.*"))
    {
        perspectiveAndCrop=replace(replace(bswFileLines[i], "PerspectiveAndCrop[^=]*=[ ]*", ""), "#.*$", "");
        perspectiveAndCrop=replace(perspectiveAndCrop, "\\s{1,}", ",");

        perspectiveAndCropArray=split(perspectiveAndCrop, ",");
    
        for(j=0;j<4; ++j)
        {
            x[j] = parseInt(perspectiveAndCropArray[j*2]);
            y[j] = parseInt(perspectiveAndCropArray[j*2+1]);
        }
    }
    if(matches(bswFileLines[i], "Color.*"))
    {       
        desColor=replace(replace(bswFileLines[i], "Color[^=]*=[ ]*", ""), "#.*$", "");; 
    }
}


leftside_a=abs(x[0]-x[3]);
leftside_b=abs(y[0]-y[3]);

leftside_c= sqrt(leftside_a*leftside_a+leftside_b*leftside_b);

rightside_a=abs(x[1]-x[2]);
rightside_b=abs(y[1]-y[2]);

rightside_c=sqrt(rightside_a*rightside_a+rightside_b*rightside_b);

middle_pixel = (leftside_c+rightside_c)*0.5;
    

xsize_mm = middle_pixel/srcDpi*25.4;
sourcedpi = srcDpi;

setBatchMode(bachMode);

run("Close All");
run("Image Sequence...", "open=["+srcDir+"] number=[] starting=1 increment=1 scale=100 file=[] or=[] sort use");


srcImgID = getImageID();
srcImgTitle = getTitle();

if(nSlices() == 1)
{
    filelist = getFileList(srcDir);
    filename = "";
    for(i = 0; i < lengthOf(filelist); ++i)
    {
        if(matches(filelist[i], ".*(jpg|jpeg|JPG|JPEG)$"))
        {
            filename = filelist[i];
            filename = substring(filename, 0, lastIndexOf(filename,"."));
        }
    }
    noLogWindowPrint(filename);
    rename(filename);
    srcImgTitle = filename;
}


xsize=getWidth();
ysize=getHeight();


degree = 0;
ydiff = y[0] - y[1];
xdiff = x[0] - x[1];

if(xdiff > ydiff && abs(xdiff) < abs(ydiff)){ degree = 0;}
if(xdiff < ydiff && abs(xdiff) > abs(ydiff)){ degree = 90;}
if(xdiff < ydiff && abs(xdiff) < abs(ydiff)){ degree = 180;}
if(xdiff > ydiff && abs(xdiff) > abs(ydiff)){ degree = 270;}
     
startcorner=0;
if(degree == 0)
    startcorner=2;
if(degree == 90)
    startcorner=3;
if(degree == 180)
    startcorner=0;
if(degree == 270)
    startcorner=1;


selectImage(srcImgID);
correctImages="correctImage"+postfix;
run("Duplicate...", "title=["+correctImages+"]");


xrot=newArray(0,0,0,0);
yrot=newArray(0,0,0,0);

selectImage(correctImages);
if(degree == 0)
{
    run("Rotate 90 Degrees Left");
    roi_rotate90_right(x,y,xrot, yrot, xsize, ysize);
}
if(degree == 180)
{
    run("Rotate 90 Degrees Right");
    roi_rotate90_left(x,y,xrot, yrot, xsize, ysize);
}
makeSelection("point", xrot, yrot);
make_rect(0);


selectImage(srcImgID);
sliceTo = nSlices();
sliceFrom = 1;

for(i = sliceFrom; i <= sliceTo; ++i)
{
    selectImage(srcImgID);
    setSlice(i);
    sliceName="";
    if(nSlices() == 1)
        sliceName = getTitle();
    else
        sliceName = getInfo("slice.label");

    run("Select None");
    workImage="workImage"+toString(i)+postfix;
    run("Duplicate...", "title=["+workImage+"]");

    if(degree == 0)
    {
        run("Rotate 90 Degrees Left");
        roi_rotate90_right(x,y,xrot, yrot, xsize, ysize);
    }
    if(degree == 180)
    {
        run("Rotate 90 Degrees Right");
        roi_rotate90_left(x,y,xrot, yrot, xsize, ysize);
    }
    makeSelection("point", xrot, yrot);

    run("Landmark Correspondences", "source_image=["+workImage+"] template_image=["+correctImages+"] "+
        "transformation_method=[Least Squares] alpha=1 mesh_resolution=1 transformation_class=Perspective interpolate");

    this_tansformImgTitle="this_tansformImgTitle"+toString(i)+"_"+postfix;
    rename(this_tansformImgTitle);

    makeSelection("point",xrot,yrot);
    run("To Bounding Box");

    run("Crop");

    if(desColor == "gray")
        run("8-bit");

    saveto_dir = resultDir  + "/" ;
    saveto_filename = sliceName + ".tiff";
    saveAs("Tiff", saveto_dir + saveto_filename);
    close();

    selectImage(workImage);
    close();
    noLogWindowPrint(saveto_dir + saveto_filename);
}

selectImage(srcImgID);
close();
selectImage(correctImages);
close();

if(bachMode && showAtEnd)
{
    setBatchMode("exit and display");
}

    
function filler(num, digs) 
{
    f = "";
    for(k = 1; k < digs; ++k)
    {
        if(num < pow(10,k))
        {
            f = f + "0";
        }
    }
    return f; 
}


function make_rect(startcorner)
{
    run("To Bounding Box");
    getSelectionBounds(rx, ry, rwidth, rheight);
    run("Select None");

    nx=newArray(4);
    ny=newArray(4);

    nx[startcorner%4]=rx;        ny[startcorner%4]=ry;
    startcorner++;
    nx[startcorner%4]=rx+rwidth; ny[startcorner%4]=ry;
    startcorner++;
    nx[startcorner%4]=rx+rwidth; ny[startcorner%4]=ry+rheight;
    startcorner++;
    nx[startcorner%4]=rx;        ny[startcorner%4]=ry+rheight;

    makeSelection("point",nx, ny);
}

function roi_rotate90_left(x0,y0,x1,y1,xsize,ysize)
{
    for(i=0;i < 4; ++i)
    {
        x1[i] = ysize - y0[i];
        y1[i] = x0[i];
    }
}

function roi_rotate90_right(x0,y0,x1,y1,xsize,ysize)
{
    for(i=0;i < 4; ++i)
    {
        x1[i] = y0[i];
        y1[i] = xsize -x0[i];
    }
}

eval("script", "System.exit(0);"); 