% Display digital aperture
% Light field capture script for Holoeye SLM & AVT Stingray

%%C:\Documents and Settings\tom\Desktop\Digital Aperture Code>"c:\Program Files\IrfanView\i_view32" mask.bmp /one /pos=(1366,1) /fs

% Housekeeping
if exist('vid'), delete(vid), end
clear; tic;
timeStampedFolder = datestr(now,'yyyy-dd-mmm-HH-MM');
timeStampedFolder=strcat('MultipleSnapshotCapture_',timeStampedFolder);
mkdir(timeStampedFolder);

% Initialize camera
vid = videoinput('avtmatlabadaptor_r2009a',1,'F7M0_RGB8_780x580'); %New AVT driver
set(vid,'Timeout',100);
src = getselectedsource(vid);
ExtendedShutter = 1500000;
src.Gain = 680;
src.WhitebalanceUB = 501;
src.WhitebalanceVR = 411;
capturedImageFigureHandle = figure;

continueCapture=1; imageNumber=1;
while(continueCapture)
    % Capture snapshot stack
    capturedImage = zeros(580,780,3);
    for ii = 1:10%50
        disp(sprintf('Capturing image: %i',ii));
        src.ExtendedShutter=10; src.ExtendedShutter=ExtendedShutter; ccc=getsnapshot(vid);
        ccc = ccc(end:-1:1,:,:); ccc = ccc(:,end:-1:1,:);%Flip image
        capturedImage = capturedImage + double(ccc(:,:,:));
    end
    % Average stack, save image, display result
    capturedImage = uint8(capturedImage/ii);
    filePath = strcat(timeStampedFolder,'/','CapturedImage',num2str(imageNumber));
    imwrite(capturedImage, strcat(filePath,'.jpg'), 'jpeg');
    figure(capturedImageFigureHandle); imshow(capturedImage);
    
    % Display preview for alignment--resetting camera as an adaptor bug workaround
    vid=videoinput('avtmatlabadaptor_r2009a',1,'F7M0_RGB8_780x580'); %New AVT driver
    preview(vid);
    
    % Await user direction
    w = input('Press "enter" key alone to continue or "space + enter" to finish capture\n','s');
    if isempty(w) %Continue
        imageNumber = imageNumber + 1;
        closepreview(vid);
    else %Finish
        continueCapture=0;
        closepreview(vid);
    end
end