% Display digital aperture

% Housekeeping
if(exist('s1')),fclose(s1);end
clear;
tic; addpath panel;
timeStampedFolder = datestr(now,'yyyy-dd-mmm-HH-MM');
mkdir(timeStampedFolder);

% Initialize XML file
XMLFile = fopen(strcat(timeStampedFolder,'\TheXMLFile.xml'),'w');
fprintf(XMLFile, '<lightfield> \n');

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

% Initialize serial interface; usually port 26
s1 = serial('COM26');
set(s1,'Terminator','CR'); %Character 13
fopen(s1); pause(0.5);
fprintf(s1,'v'); pause(0.5); fprintf(s1,'0'); %Turn off MCU verbosity
set(s1,'Timeout',1); fread(s1); set(s1,'Timeout',30); %Clear buffer

% Calibrate light field range -- entire screen for now
apertureWidthStart = 51; apertureWidthEnd = 290;%111,230;
apertureHeightStart = 1; apertureHeightEnd = 240;
blockSize = 24;

% Capture background light transmission for digital rejection
backgroundLight = zeros(580,780,3);
for ii = 1:100
    ccc = getsnapshot(vid);
    backgroundLight = backgroundLight + double(ccc);
    %pause(0.2);
end
backgroundLight = uint8(backgroundLight / ii);
figure; imshow(backgroundLight);

% Step through light field blocks
for ii = apertureHeightStart:blockSize:apertureHeightEnd
    for jj = apertureWidthStart:blockSize:apertureWidthEnd
        disp(sprintf('Light Field Position: %i,%i',jj,ii));
        % Open aperture
        fprintf(s1,'O'); pause(0.5);
        fprintf(s1,num2str(jj));pause(0.5);
        fprintf(s1,num2str(ii));pause(0.5);
        fprintf(s1,num2str(jj+blockSize-1));pause(0.5);
        fprintf(s1,num2str(ii+blockSize-1));pause(0.5);
        char(fread(s1,1))' %Wait for MCU to report 'S'uccess
        
        % Capture snapshot stack
        capturedImage = zeros(580,780,3);
        for bb = 1:50
            ccc = getsnapshot(vid);
            capturedImage = capturedImage + double(ccc);
            %pause(0.2);
        end
        
        % Average stack and auto-correct exposure
        capturedImage = (capturedImage / bb) - double(backgroundLight);
        sorted = sort(reshape(capturedImage,580*780*3,1));
        capturedImage = ...
            uint8(capturedImage / sorted(round(length(sorted)*.997)) * 255);
        
        % Save corrected image and write XML entry
        figure(capturedImageFigureHandle); imshow(capturedImage);
        fileName = strcat('LightField',num2str(jj),'_',num2str(ii));
        filePath = strcat(timeStampedFolder,'/',fileName);
        imwrite(capturedImage, strcat(filePath,'.jpg'), 'jpeg');
        fprintf(XMLFile, '<subaperture src="%s.jpg" u="%i" v="%i"/>\n', ...
            fileName, jj, ii);
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
