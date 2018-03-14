// this reads .tif files taken at a particular magnification so that there's a constant pixel/mm ratio, converts the pictures to binary using a particular thresholding technique, and then measures some statistics about them

//pop up with measurement options
Dialog.create("Select Functions");
Dialog.addCheckbox("Create binary images", true);
Dialog.addCheckbox("Measure binary images", true);
Dialog.show();
binary = Dialog.getCheckbox();
meas=Dialog.getCheckbox();

// if "Create binary images" was selected:
if(binary==true){

	// select a directory
	dir=getDirectory("Choose a directory");
	list=getFileList(dir);

	// make sure min and mode are measured
	run("Set Measurements...", "modal min display redirect=None decimal=3");

	// cycle through files in the selected directory
	for (i=0; i<list.length; i++) {

		// if it's a .tif file, then open it
		if(endsWith(list[i], ".tif")){
			open(dir+list[i]);
			
			// convert to greyscale image
			run("8-bit");
			
			// select the region of interest
			waitForUser("select the region of interest, and crop");
			run("Select None");
			
			//rolling background subtraction
			run("Subtract Background...", "rolling=300 light disable");
			
			// get the min and mode greyscale values
			run("Measure");
			mode=getResult("Mode");
			min=getResult("Min");
			
			// set the contrast according to min and mode greyscale values
			setMinAndMax(min, mode);
			run("Apply LUT");
			
			// convert to binary image, in this case using the thresholding technique "Max Entropy"
			setAutoThreshold("MaxEntropy");
			setOption("BlackBackground", false);
			run("Convert to Mask");
			
			// save the binary image
			dir=File.directory;
			name=File.nameWithoutExtension;
			saveAs("Tiff",dir+name+"_binary.tif");
			close(name+"*");
		}
	}
}

// if "Measure binary images" was selected:
if(meas== true){
	run("Clear Results");
	
	// select a directory
	if(binary==false){
		dir=getDirectory("Choose a directory for measurement");
	}
	list=getFileList(dir);
	
	// initialize arrays
	filelist=newArray(list.length);
	nround=newArray(list.length);
	nall=newArray(list.length);
	featureArea=newArray(list.length);
	maxArea=newArray(list.length);
	totalArea=newArray(list.length);
	areaFrac=newArray(list.length);
	
	// cycle through files in the selected directory
	k=0;
	for (i=0; i<list.length; i++) {
		
		// if it's a "binary.tif" file, then open it
		if(endsWith(list[i], "binary.tif")){
			filelist[k]=list[i];
			open(dir+filelist[k]);
			
			// set the measurement scale, where "distance" in px is "known" in units of mm
			run("Set Scale...", "distance=5000 known=5 pixel=1 unit=mm global"); 
			
			// make sure min and mode are measured
			run("Set Measurements...", "area modal min area_fraction display redirect=None decimal=3");
			
			// measure all features
			run("Clear Results");
			run("Analyze Particles...", "display include summarize"); 
			maxArea[k]=0;
			for (j=0; j<nResults; j++) {
				x=getResult("Area",j);
				if(maxArea[k]<x){
					maxArea[k]=x;
				}
			}
			run("Clear Results");
			
			// measure roundest features
			run("Analyze Particles...", "  circularity=0.99-1.00 display include");
			nround[k]=nResults();
			run("Clear Results");
			
			// close the image
			close(filelist[k]+"*");
			k=k+1;
		}
	}

	// get the relevant values from the summary window
	selectWindow("Summary");
	IJ.renameResults("Results");
	for (i=0; i<k; i++) {
		featureArea[i]=getResult("Total Area",i);
		areaFrac[i]=getResult("%Area",i)/100;
		nall[i]=getResult("Count",i);
		totalArea[i]=featureArea[i]/areaFrac[i];
	}
	
	// create a new summary window
	run("Clear Results");
	for (i=0; i<k; i++) {
	  
		// file name
		setResult("file",nResults,filelist[i]);
		
		// flaw density for high circularity flaws
		setResult("features with circ>0.99 per mm2",nResults-1,nround[i]/totalArea[i]);
		  
		// flaw density
		setResult("features per mm2",nResults-1,nall[i]/totalArea[i]);
		  
		// fraction of the whole image that is covered by flaws
		setResult("coverage fraction",nResults-1,areaFrac[i]);
		
		// area of whole image
		setResult("total image area",nResults-1,totalArea[i]);
		
		// area covered by flaws
		setResult("total feature area",nResults-1,featureArea[i]);
		
		// area of largest flaw
		setResult("largest feature area",nResults-1,maxArea[i]);
	}
}

