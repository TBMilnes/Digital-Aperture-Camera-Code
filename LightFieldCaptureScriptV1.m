% Display digital aperture

% Housekeeping
clear;
tic; addpath panel;
timeStampedFolder = datestr(now,'yyyy-dd-mmm-HH-MM');
mkdir(timeStampedFolder);

% Initialize XML file
XMLFile = fopen(strcat(timeStampedFolder,'\TheXMLFile.xml'),'w');
fprintf(XMLFile, '<lightfield> \n');

% Create panelled figure w/o toolbar
if ~exist('apertureFigureHandle')
    %clear;
    apertureFigureHandle = figure;
    p = panel;
    pA = p.pack();
    
    % Wait for user to align aperture figure
    waitforbuttonpress
    
    % Initialize camera
    vid = videoinput('dcam',1);
    src = getselectedsource(vid)
    src.AutoExposure = 205;
    src.Brightness = 1023;
    src.Gain = 680;
    src.Gamma = 0;
    src.WhiteBalance = [501, 411];
    src.WhiteBalanceMode = 'manual';
    src.Shutter = 4095;
    src.shutterMode = 'manual';
    src.gainMode = 'manual';
    capturedImageFigureHandle = figure;
    start(vid);
end

% Initialize and display aperture image
apertureImage = zeros(500);
figure(apertureFigureHandle); select(pA);
colormap('Gray');
image(apertureImage); drawnow;

% Calibrate light field range -- way too done-by-hand
LFWidth = 10; LFHeight = 10;
padding = 0.3;
% Raw calibration
xMin = 180; xMax = 376;
yMin = 116; yMax = 453;
xRange = xMax - xMin + 1; yRange = yMax - yMin + 1;
% Padding re-map
xMin = xMin + round(padding*xRange); xMax = xMax - round(padding*xRange);
yMin = yMin + round(padding*yRange); yMax = yMax - round(padding*yRange);
xRange = xMax - xMin + 1; yRange = yMax - yMin + 1;

% Capture background light transmission for digital rejection
backgroundLight = zeros(580,780);
for ii = 1:100
    ccc = getsnapshot(vid);
    backgroundLight = backgroundLight + double(ccc(:,:,3));
    pause(0.2);
end
backgroundLight = uint8(backgroundLight / ii);
figure; imshow(backgroundLight);

% Step through light field blocks
for jj = 1:LFHeight
    for ii = 1:LFWidth
        disp(sprintf('Light Field Position: %i,%i',jj,ii));
        % Open aperture
        apertureImage(yMin+round((jj-1)/LFHeight*yRange): ...
            yMin+round(jj/LFHeight*yRange), ...
            xMin+round((ii-1)/LFWidth*xRange): ...
            xMin+round(ii/LFWidth*xRange)) = 255;
        select(pA); image(apertureImage);
        apertureImage(:,:) = 0;
        
        % Capture snapshot stack
        capturedImage = zeros(580,780);
        for bb = 1:50
            ccc = getsnapshot(vid);
            capturedImage = capturedImage + double(ccc(:,:,3));
            pause(0.2);
        end
        
        % Average stack and auto-correct exposure
        capturedImage = (capturedImage / bb) - double(backgroundLight);
        sorted = sort(reshape(capturedImage,580*780,1));
        capturedImage = ...
            uint8(capturedImage / sorted(round(length(sorted)*.997)) * 255);
        
        % Save corrected image and write XML entry
        figure(capturedImageFigureHandle); imshow(capturedImage);
        fileName = strcat('LightField',num2str(ii),'_',num2str(jj));
        filePath = strcat(timeStampedFolder,'/',fileName);
        imwrite(capturedImage, strcat(filePath,'.jpg'), 'jpeg');
        fprintf(XMLFile, '<subaperture src="%s.jpg" u="%i" v="%i"/>\n', ...
            fileName, ii, jj);
    end
end

% Terminate parent tag and close XML file
fprintf(XMLFile,'</lightfield>\n');
fclose(XMLFile);

% Zip files and inject checksum
cd(timeStampedFolder)
fileList = dir; filesToZip = '';
for ii = 1:length(fileList)
    if fileList(ii).isdir == 0
        filesToZip = [filesToZip, ' ', fileList(ii).name];
    end
end
system(sprintf('C:\\"Program Files"\\7-Zip\\7z a %s.zip %s', ... 
    timeStampedFolder, filesToZip));
cd ..
system(sprintf('C:\\Python23\\python fzip-prepare.py %s\\%s.zip', ...
    timeStampedFolder, timeStampedFolder));
