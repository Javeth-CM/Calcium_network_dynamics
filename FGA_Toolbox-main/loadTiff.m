function imgStack = loadTiff(imgFile, imgInfo, addWait, isBioFormat)
%LOADTIFF - Load a multipage image stack either in *.tif or *.nd2 files
% USAGE: imgStack = loadTiff(imgFile, imgInfo, addWait, isBioFormat)
% OUTPUT:
%       imgStack: a matrix of dimension xyt containing one image of the timelapse per each 't'
%
% INPUTS:
%       imgFile: the complete file name (including the path) of the image stack that you want to load
%       imgInfo: the basic information of the image, as an array of 1-by-4 dimension containing, in order:
%                the image width, height, number of planes, image type (if unit8 or unit16)
%       addWait: boolean value to add a wait bar in the form of an help diolog
%       isBioFormat: boolean value to use if the image is stored as a *.nd2 file
%
% See also: TIFF,  BFOPEN

% Author: Alessandro Moro
% Dept. Functional Genomics,
% Center for Neurogenomics and Cognitive Research (CNCR),
% email: a.moro@vu.nl

% First check if we need a wait message
if addWait
    hWait = helpdlg('Loading image without progress. It''s faster!');
end

% Gather the info
imgWidth = imgInfo(1);
imgHeight = imgInfo(2);
imgNumber = imgInfo(3);
imgType = sprintf('uint%d', imgInfo(4));
imgStack = zeros(imgHeight, imgWidth, imgNumber, imgType);

% Divide the code if we need to use bioformats or not
if isBioFormat
    % Open the images from the reader (it should save time and memory)
    reader = bfGetReader(imgFile);
    % Now loop through the planes and load one plane at the time into the imgStack
    for p=1:imgNumber
        imgStack(:,:,p) = bfGetPlane(reader, p);
    end
    % Close the reader to let the file be accessible
    reader.close()
else
    % Open the file as a Tiff image
    imgStackID = fopen(imgFile, 'r');
    tstack = Tiff(imgFile);
    % Read and save the first image to initialize the stack
    imgStack(:,:,1) = tstack.read();
    % Move to the downstream images one by one
    for n = 2:imgNumber
        nextDirectory(tstack);
        imgStack(:,:,n) = tstack.read();
    end
    % now close the file so that it can be access from other applications
    fclose(imgStackID);
end

% If needed, close the wait message
if addWait
    delete(hWait)
end
end