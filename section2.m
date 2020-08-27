%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% VIDEO FOR MULTIPLE AND MOVING CAMERAS (VMMC)
% IPCV @ UAM
% Marcos Escudero-Vi�olo (marcos.escudero@uam.es)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all
close all
clc
%% PARAMETER DEFINITION %%
%%define dataset path
params.Directory    = fullfile('Images/section2_3');

%%Detector parameters
params.detector     =  'SIFT'; %'LoG_ss', 'SURF', 'SIFT', DoH, KAZE...
params.nscales      =       5;
params.noctaves     =       5;
params.sigma0       =      1.6; % as we are using Matlab functions this is the minimum value allowed
params.npoints      =      1000;
params.MetricThreshold =   5;
params.KazeThreshold =     1e-4;

%%Descriptor parameters (see doc extractFeatures for explanation and additional parameters)
params.descriptor   =  'DSP-SIFT'; % 'SIFT', 'SURF', 'DSP-SIFT'...
params.desOnDecom   =   false; % describe on scale-space (linear or non-linear) decomposition (if available)
params.Upright      =   false; % set to true to avoid orientation estimation.
% for DSP-SIFT
params.dsp.ns       =      10;% number of sampled scales
params.dsp.sc_min   =     1/6;% smallest scale (relative to detection) 
params.dsp.sc_max   =       1;% biggest scale (relative to detection) 
%%Matching parameters (see doc matchFeatures for explanation and additional parameters)
params.MaxRatio     =   0.4;
params.MatchThreshold =   30;
params.Metric       =  'SSD';
%% END OF PARAMETER DEFINITION %%

%% addpaths
addpath(genpath('./detectors/'));
addpath(genpath('./descriptors/'));
addpath(genpath('./toolbox/'));

%% preload dataset
params.Scene = imageDatastore(params.Directory);
numImages    = numel(params.Scene.Files);

%% initialize (sort of)
ima{numImages}           = [];
points{numImages}        = [];
decomposition{numImages} = [];
features{numImages}      = [];

%% get sigmas
k = 1;
params.sigmas = zeros(1,params.noctaves*params.nscales);
for o = 0:params.noctaves-1
    params.sigmas(k:(k+params.nscales-1)) = params.sigma0.*pow2([0:(params.nscales-1)]/params.nscales + o);
    k = k+params.nscales;
end

%% detect & describe
for j = 1:numImages
%% Load and convert images %%
ima{j}      =       readimage(params.Scene, j);
%ima{j}      =       imresize(ima{j},0.2);
gima        =       im2double(rgb2gray(ima{j}));

%% PoI Detection %%
sprintf('Detecting for image: %d',j)
[points{j},decomposition{j}] =  myDetector(gima,params);

%% PoI Description %%
sprintf('Describing for image: %d',j)
[features{j},points{j}]      =  myDescriptor(points{j},decomposition{j},params);

%% show detections
figure(j)
imshow(ima{j}); hold on;
plot(points{j},'showOrientation',true);

end

%% PoI Matching (assumes two images, i.e. numImages == 2) %%
indexPairs       = matchFeatures(features{1},features{2},'MaxRatio',params.MaxRatio,'Metric',params.Metric, 'MatchThreshold', params.MatchThreshold) ;
matchedPoints{1} = points{1}(indexPairs(:,1));
matchedPoints{2} = points{2}(indexPairs(:,2));
figure(numImages+1); showMatchedFeatures(ima{1},ima{2},matchedPoints{1},matchedPoints{2});
legend('matched points 1','matched points 2');

%% Homography estimation and warp %% 

%% A) Estimate the transformation between ima(2) and ima(1).
if numel(matchedPoints{2}.Scale) < 4
   sprintf('Unable to match enough points -> End of program')
   return;
end
tform21  = estimateGeometricTransform(matchedPoints{2}, matchedPoints{1},...
         'projective', 'Confidence', 99.9, 'MaxNumTrials', 2000);
        
warpedImage = imwarp(ima{2}, tform21, 'OutputView', imref2d(size(ima{1})));
% show results
ima2         = zeros(size(ima{1}));
for ch=1:3
ima2(:,:,ch) = imresize(ima{2}(:,:,ch),size(ima{1}(:,:,ch)));
end
multi = cat(4,ima{1},ima2,ima{1},warpedImage);
figure(numImages+2);aa = montage(multi);
result21 = aa.CData;
disp  = 20;
figure(numImages+2);clf,imshow(result21)
text(disp,disp,'Image 1','Color','red','FontSize',14)
text(disp + size(result21,2)/2,disp,'Image 2','Color','red','FontSize',14)
text(disp,disp + size(result21,1)/2,'Image 1','Color','red','FontSize',14)
text(disp + size(result21,2)/2,disp + size(result21,1)/2,'Image 2 to 1','Color','red','FontSize',14)

%% B) Estimate the transformation between ima(1) and ima(2).
tform12  = estimateGeometricTransform(matchedPoints{1}, matchedPoints{2},...
         'projective', 'Confidence', 99.9, 'MaxNumTrials', 2000);
        
warpedImage = imwarp(ima{1}, tform12, 'OutputView', imref2d(size(ima{2})));
% show results
for ch=1:3
ima1(:,:,ch) = imresize(ima{1}(:,:,ch),size(ima{2}(:,:,ch)));
end
multi = cat(4,ima1,ima{2},warpedImage,ima{2});
figure(numImages+3);aa = montage(multi);
result12 = aa.CData;
figure(numImages+3);clf,imshow(result12)
text(disp,disp,'Image 1','Color','red','FontSize',14)
text(disp + size(result12,2)/2,disp,'Image 2','Color','red','FontSize',14)
text(disp,disp + size(result12,1)/2,'Image 1 to 2','Color','red','FontSize',14)
text(disp + size(result12,2)/2,disp + size(result12,1)/2,'Image 2','Color','red','FontSize',14)


%% Estimate F
[F,inliersIndex] = estimateFundamentalMatrix(matchedPoints{1},matchedPoints{2}, 'Method','RANSAC',...
    'NumTrials',2000,'DistanceThreshold',2);

fprintf('Number of inliers: %d\n', sum(inliersIndex))

addpath(genpath('./vgg_ui/'));
addpath(genpath('./vgg_multiview/'));
addpath(genpath('./vgg_numerics/'));
addpath(genpath('./vgg_general/'));

vgg_gui_F(ima{1}, ima{2}, F')



