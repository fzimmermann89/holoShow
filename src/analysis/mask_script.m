function handles_return = mask_script(handles)
% Performs:
%     - common mode correction
%     - shifting of scattering pattern and mask


%% PARAMETERS

HP_filter = handles.HPfiltering;
HP_radius = handles.HPfrequency;
LP_filter = handles.LPfiltering;
LP_radius = handles.LPfrequency;
IF_filter = handles.IF_filtering;
IF_value = handles.IF_value;
CM_thresh = handles.cm_thresh;
rowsToshift = round(handles.ycenter);
columnsToShift =  round(handles.xcenter);
slit = handles.add_slit;
shift = handles.add_shift;
SMOOTH_FACTOR = 5; % smooth parameter for mask
DO_SMOOTHING = true;

% Switches for what to show
showMASKS = false; % show used mask
showCM = false; % show common mode correction
showSMOOTH = false; % show smoothed mask and pattern

%% LOAD DATA & MASK

origdata = handles.hologram.orig;
try
    origdata = origdata  .* (~handles.hummingbird_mask);
catch
    warning('could not apply hummingbird mask')
end

origdata(abs(origdata)>=handles.adu_max) = 0; % set saturated pixels to 0
if IF_filter
    origdata(abs(origdata)>IF_value) = 0;
end
origdata(origdata<-50)=0;

if handles.load_mask
    mask = handles.origmask;
else
    mask = ones(1024);
end

mask(origdata==0)=0;

if showMASKS
    figure(11) %#ok<*UNRCH>
    subplot(131); imagesc(handles.origmask);axis square;
    subplot(132); imagesc(mask);axis square;
    subplot(133); imagesc(origdata);axis square;
end

%% CENTER PICTURE & COMMON MODE

% CORRECTION OF CENTER SHIFT
data = simpleshift(origdata,[rowsToshift columnsToShift]);
mask = simpleshift(mask,[rowsToshift columnsToShift]);

% SECOND CORRECTION THROUH VARIANCE AND DETECTOR SHIFTS
sdata = simpleshift(data,[slit, shift]);
smask = simpleshift(mask,[slit, shift]);
data(513+slit:end,:) = sdata(513+slit:end,:);
mask(513+slit:end,:) = smask(513+slit:end,:);
mask(513:513+slit,:) = 0;
data(isnan(data)) = 0;

% HIGHPASS FILTERING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Modified see below!
if HP_filter
    [X, Y] = meshgrid(-512:511,-512:511);
    lowp = X.^2+Y.^2<HP_radius^2;
    mask(lowp)=0;
end

% LOWPASS FILTERING
if LP_filter
    [X, Y] = meshgrid(-512:511,-512:511);
    highp = X.^2+Y.^2>LP_radius^2;
    mask(highp)=0;
end

% COMMON MODE CORRECTION
if handles.do_cm
    for m=1:1024
        dat = data(1:512-columnsToShift,m);
        dat = dat(mask(1:512-columnsToShift,m)>0);
        dat = dat(dat<CM_thresh);
        CM = median(dat);
        if ~isnan(CM)
            data(1:512-columnsToShift,m) = data(1:512-columnsToShift,m)-CM.*mask(1:512-columnsToShift,m);
        end
        
        dat = data(513-columnsToShift:1024,m);
        dat = dat(mask(513-columnsToShift:1024,m)>0);
        dat = dat(dat<CM_thresh);
        CM = median(dat);
        if ~isnan(CM)
            data(513-columnsToShift:1024,m) = data(513-columnsToShift:1024,m)-CM.*mask(513-columnsToShift:1024,m);
        end
    end
end
data(data<handles.adu_min)=0;

if showCM
    figure(22);
    subplot(221);
    imagesc(log(abs(origdata)).*mask,[0 8]);
    colormap(fire);
    axis square;
    subplot(222);
    imagesc(mask);
    axis square;
    subplot(223); imagesc(log(abs(data)).*mask,[0 max(log(abs(data(:))))]); axis square;
end

%% SMOOTH MASK

if DO_SMOOTHING
    blurred=imgaussfilt(mask,SMOOTH_FACTOR);
    newMask = 1-(blurred<0.99);
    newMask=imgaussfilt(newMask,SMOOTH_FACTOR);
else
    newMask = mask;
end

newMask(~mask)=0;

if showSMOOTH
    figure(3);
    subplot(121); imagesc(newMask); axis square; colormap gray; colorbar;
    subplot(122); imagesc(log(abs(newMask)),[0 8]); axis square; colormap fire; colorbar;
end

handles.mask = newMask;
handles.hardmask = mask;
handles.hologram.masked = data.*newMask;

handles_return = handles;
