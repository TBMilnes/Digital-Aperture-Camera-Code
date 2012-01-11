% Housekeeping
if exist('vid','var')
    disp('Clearing old vid structure')
    for ii=1:numberOfCamerasInArray
        stop(vid{ii}); delete(vid{ii});
    end
end
clear; tic; t=0;

% Create folder for saving image files
timeStampedFolder = strcat('WebcamDomeCapture_',datestr(now,'yyyy-dd-mmm-HH-MM'));
mkdir(timeStampedFolder)

% Get information about winvideo cameras connected to this machine
winVideoInfo = imaqhwinfo('winvideo');
numberOfSystemCameras = length(winVideoInfo.DeviceIDs);
disp(sprintf('Number of system cameras: %i',numberOfSystemCameras))

% Initialize winvideo cameras
numberOfCamerasInArray = 0;
for ii=1:numberOfSystemCameras
    if strncmp(winVideoInfo.DeviceInfo(ii).DefaultFormat,'YUY2_1280x1024',14)
        numberOfCamerasInArray = numberOfCamerasInArray + 1
        vid{numberOfCamerasInArray} = videoinput('winvideo',winVideoInfo.DeviceIDs{ii},'YUY2_1280x1024');
        src{numberOfCamerasInArray} = getselectedsource(vid{numberOfCamerasInArray});
    end
end
disp(sprintf('Number of cameras in the array: %i',numberOfCamerasInArray))

% Initialize trigger parameters
frameDelay = 50;
framesPerTrigger = 10;
for ii=1:numberOfCamerasInArray
    vid{ii}.TriggerFrameDelay = frameDelay;
    vid{ii}.FramesPerTrigger = framesPerTrigger;
end

% Because of speed restrictions on USB, must fire cameras one by one...
imageData = zeros(1024,1280,3,numberOfCamerasInArray);
start(vid{1});
for ii = 1:numberOfCamerasInArray
    disp(sprintf('Capturing from camera %i of %i',ii,numberOfCamerasInArray));
    captureInProgress = true;
    while captureInProgress
        pause(0.25);
        if vid{ii}.FramesAcquired == framesPerTrigger
            captureInProgress = false;
            if ii<numberOfCamerasInArray
                start(vid{ii+1});
            end
        end
    end
    rawData=getdata(vid{ii});
    % Convert raw data frames from YCbCrto RGB and average them
    for jj=1:size(rawData,4)
        imageData(:,:,:,ii) = imageData(:,:,:,ii) + double(ycbcr2rgb(rawData(:,:,:,jj)));
    end
    imageData(:,:,:,ii) = imageData(:,:,:,ii)/framesPerTrigger/255;
    disp(sprintf('    Capture took %i seconds', round(toc-t))); t = toc;
end

% Save averaged image data to folder
for ii=1:numberOfCamerasInArray
    imwrite(imageData(:,:,:,ii),strcat(timeStampedFolder,'\WebcamImage',num2str(ii),'.jpg'),'JPEG','Quality',100);
end

% Show results
figure; imaqmontage(imageData);
disp(sprintf('Acquisition time was %i seconds', round(toc)));


% % Trigger array, almost simultaneous since cameras are already start()ed
% for ii=1:numberOfCamerasInArray
%     trigger(vid{ii});
% end
%     
% % Collect logged image data when it becomes available
% completedCaptures = zeros(1,numberOfCamerasInArray);
% imageData = zeros(1024,1280,3,numberOfCamerasInArray);
% while sum(completedCaptures) < numberOfCamerasInArray
%     for ii=1:length(completedCaptures)
%         if completedCaptures(ii)==0 && vid{ii}.FrameAcquired==framesPerTrigger
%             rawData=getdata(vid{ii});
%             % Convert raw data frames from YCbCrto RGB and average them
%             for jj=1:size(rawData,4)
%                 imageData(:,:,:,ii) = imageData(:,:,:,ii) + double(ycbcr2rgb(rawData(:,:,:,jj)));
%             end
%             imageData(:,:,:,ii) = imageData(:,:,:,ii)/framesPerTrigger/255;
%             completedCaptures(ii) = 1;
%         end
%     end
%     pause(1);
% end
% 



% % Auto-exposure
% src = getselectedsource(vid{2});
% src.FocusMode = 'manual';
% src.Focus = 9;
% src.ExposureMode = 'manual';
% src.Exposure = -7;
% src.WhiteBalanceMode = 'manual';
% src.WhiteBalance = 6500;
% src.BacklightCompensation = 'off';
% button = true;
% src = getselectedsource(vid{2});
% src.BacklightCompensation = 'off' %No nociceable change, maybe a frame brighter
% src.Brightness = 1 %No nociceable change
% src.Contrast = 33
% src.ExposureMode = 'manual'
% src.Exposure = -1
% src.FocusMode = 'manual' %No nociceable change
% src.Focus = 9 %No nociceable change
% src.FrameRate = '7.5000'
% src.Gain = 1
% src.Gamma = 100
% src.Hue = 1
% src.Pan = 1
% src.Saturation = 65
% src.Sharpness = 4
% src.Tilt = 1
% src.WhiteBalance = 6400
% src.WhiteBalanceMode = 'manual'
% src.Zoom = 1
% while(button)
%         imageD = getsnapshot(vid{1});
%         image(ycbcr2rgb(imageD));
%         YoDude = mean(mean(mean(imageD)))
% end

% % I think the next step is to define all values for the webcam.  It seems like the camera respects focus settings but not exposure ones.  Should re-do property tests in RGB space. 
% % Setting src parameters has some effect on captured images, for example
% setting exposure higher makes images lighter.  However, there is also
% still some automatic adjustment going that is yet to be determined.  Test
% setting parameters indevidually while preview is running.