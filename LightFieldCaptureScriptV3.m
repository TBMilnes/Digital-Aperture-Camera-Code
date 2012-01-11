% Light field capture script for Holoeye SLM & AVT Stingray

%%C:\Documents and Settings\tom\Desktop\Digital Aperture Code>"c:\Program Files\IrfanView\i_view32" mask.bmp /one /pos=(1366,1) /fs

% There is something wrong with camera triggering mode which prevents the
% camera from running long exposures.  Solve this.  Might need to
% re-install CMU driver.

% Housekeeping
clear;
tic; addpath panel;
timeStampedFolder = datestr(now,'yyyy-dd-mmm-HH-MM');
mkdir(timeStampedFolder);

% Initialize XML file
XMLFile = fopen(strcat(timeStampedFolder,'\TheXMLFile.xml'),'w');
fprintf(XMLFile,'<lightfield> \n');

% Define light field range -- way too done-by-hand
LFWidth = 10; LFHeight = 10; padding = 0; %16x12

% Initialize camera
vid = videoinput('avtmatlabadaptor_r2009a',1,'F7M0_RGB8_780x580'); %New AVT driver
% vid.FramesPerTrigger = 100;
set(vid,'Timeout',100);
src = getselectedsource(vid);
ExtendedShutter = 1900000; %ExtendedShutter = ExtendedShutter*LFWidth*LFHeight;
%src.ExtendedShutter = 10000000; %microseconds
% src.Brightness = 1023;
% src.Gain = 680;
% src.Gamma = 0;
src.WhitebalanceUB = 532%418;%501;%
src.WhitebalanceVR = 367%396;%411;%
%src.WhiteBalanceMode = 'manual';
set(src,'Shutter',4095); %src.Shutter = 4095;
% src.shutterMode = 'manual';
% src.gainMode = 'manual';
apertureImageFigureHandle = figure;
capturedImageFigureHandle = figure;
% start(vid);

% Initialize and display aperture image
apertureImage = zeros(768,1024);
figure(apertureImageFigureHandle); imshow(apertureImage);
imwrite(apertureImage,'apertureImage.bmp')
system('"c:\Program Files\IrfanView\i_view32" apertureImage.bmp /one /pos=(2390,1) /fs &');%(1366,1)

% Capture background light transmission for digital rejection
backgroundLight = zeros(580,780,3);
for ii = 1:50%15
    src.ExtendedShutter=10; src.ExtendedShutter=ExtendedShutter; ccc=getsnapshot(vid);
    ccc = ccc(end:-1:1,:,:);%Flip image across x-axis
    backgroundLight = backgroundLight + double(ccc(:,:,:));
    pause(0.2);
    disp('aquired an image');
end
backgroundLight = uint8(backgroundLight / ii);
figure; imshow(backgroundLight);

% Raw calibration
xMin = 129; xMax = 896;
yMin = 1; yMax = 768;%<--For square-grid apertures %yMin = 1; yMax = 768;
xRange = xMax - xMin + 1; yRange = yMax - yMin + 1;
% Padding re-map
xMin = xMin + round(padding*xRange); xMax = xMax - round(padding*xRange);
yMin = yMin + round(padding*yRange); yMax = yMax - round(padding*yRange);
xRange = xMax - xMin + 1; yRange = yMax - yMin + 1;

% Step through light field blocks
for jj = 1:LFHeight
    for ii = 1:LFWidth
        disp(sprintf('Light Field Position: %i,%i',jj,ii));
        % Open new aperture
        apertureImage(:,:) = 0;
        apertureImage(yMin+round((jj-1)/LFHeight*yRange): ...
            yMin+round(jj/LFHeight*yRange), ...
            xMin+round((ii-1)/LFWidth*xRange): ...
            xMin+round(ii/LFWidth*xRange)) = 255;
        figure(apertureImageFigureHandle); imshow(apertureImage);
        imwrite(apertureImage,'apertureImage.bmp')
        system('"c:\Program Files\IrfanView\i_view32" apertureImage.bmp /one /pos=(2390,1) /fs &');%(1366,1)
        
        % Capture snapshot stack
        capturedImage = zeros(580,780,3);
        for bb = 1:50%10
            src.ExtendedShutter=10; src.ExtendedShutter=ExtendedShutter; ccc=getsnapshot(vid);
            ccc = ccc(end:-1:1,:,:);%Flip image across x-axis
            capturedImage = capturedImage + double(ccc(:,:,:));
            pause(0.2);
        end
%         get(vid)
        % Average stack and auto-correct exposure
        capturedImage = (capturedImage / bb) - double(backgroundLight);
        %figure(capturedImageFigureHandle); imshow(uint8(capturedImage*255));
        sorted = sort(reshape(capturedImage,580*780*3,1));
        capturedImage = ...
            uint8(capturedImage / sorted(round(length(sorted)*.990)) * 255);%.997
        
        % Save corrected image and write XML entry
        figure(capturedImageFigureHandle); imshow(capturedImage);
        fileName = strcat('LightField',num2str(ii),'_',num2str(jj));
        filePath = strcat(timeStampedFolder,'/',fileName);
        imwrite(capturedImage, strcat(filePath,'.jpg'), 'jpeg','Quality',100);
        fprintf(XMLFile, '<subaperture src="%s.jpg" u="%i" v="%i"/>\n', ...
            fileName, ii, jj);
    end
end

% Stop camera (remember we set FramesPerTrigger to enourmous value) 
stop(vid)

% Terminate parent tag and close XML file
fprintf(XMLFile,'</lightfield>\n')
fclose(XMLFile)

% Terminate irfanview because it locks the XML file for some unknown reason...
system('"c:\Program Files\IrfanView\i_view32" /killmesoftly');

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
