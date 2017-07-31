function [ ] = displayResultsV2()
%DISPLAYRESULTS Cycles through directories to display contrast results.
% 

clear

global mfDRFileList mfDRFileIndex mfDRParamIndex mfDRxSPMarr mfDRparamSetList mfDRDone;

mfDRFileList = {};
mfDRFileIndex = 1;
mfDRParamIndex = 1;

mfDRDone = false;

% Stuff specific to study.
%
% Directories to search through for SPM.mat files to display.
baseDir = '/home/mkfinne2/Mindfulness/First_Level_Analysis';
subDirs = {'NoMask', 'Using_Amgydala_ROI', 'Using_Average_Mask', 'Using_Individual_Masks'};

% Inititializing required fields of the xSPM struct.
% This is implemented as a nested array of maps of possible value combinations.
mfDRparamSetList = {};

% Initializing Im, and k - These aren't being changed.
% swd - working directory will be filled in during the search for SPM.mat files
% Im - no masking images are currently being used
% k - using 0 cluster extent threshhold
paramFieldSets = {containers.Map( { 'Im', 'k' }, ...
    { [], 0 } )};

mfDRparamSetList = [mfDRparamSetList, {paramFieldSets}];

% Initializing Ic
% Ic - index of the contrasts I want to look at
paramFieldSets = {};
for i = 1:6 % Range of contrast indices to display
    paramFieldSets = [paramFieldSets, {containers.Map( { 'Ic' }, { i } )}];
end

mfDRparamSetList = [mfDRparamSetList, {paramFieldSets}];

% Initializing threshDesc, u
% threshDesc - type of correction used
% u - familywise p-value, this will be converted to a critical statistic
% value when spm_getspm in spm_results_ui is called. (It passes u to spm_uc 
% which treats it as an alpha value. This makes absolutely no sense to me, 
% but whatevs.)
paramFieldSets = {};

tempMap = containers.Map( { 'thresDesc', 'u' }, ...
    { 'FWE', 0.05 } );
paramFieldSets = [paramFieldSets, {tempMap}];

tempMap = containers.Map( { 'thresDesc', 'u' }, ...
    { 'none', 0.001 } );
paramFieldSets = [paramFieldSets, {tempMap}];

mfDRparamSetList = [mfDRparamSetList, {paramFieldSets}];

% Create a cell array of parameter sets to try to display
mfDRxSPMarr = createxSPMarr();


% Recursively searching through each top-level directory for SPM.mat files to try to display
% Creates a list that will be iterated over
for sub = subDirs
   dir2search = cell2mat(fullfile(baseDir, sub));
   
   searchdirs(dir2search);
    
end


% mfDRFileIndex = 1, because we're just starting
try
    displayBrain();
catch
    incrementPointers();
end

while mfDRFileIndex <= numel(mfDRFileList) && ~mfDRDone
    try
        displayBrain();
    catch
        incrementPointers();
    end
end

disp('exiting');

end

% Recursively search directory for SPM.mat files.
function [] = searchdirs(dir2search)

    global mfDRFileList;

    directories = dir(dir2search);
    
    for i = 3:numel(directories)
        if directories(i).isdir
           searchdirs(fullfile(directories(i).folder, directories(i).name));
        elseif strcmp(directories(i).name, 'SPM.mat')
            % If and SPM.mat file is found, add to file list
            mfDRFileList = [mfDRFileList, {directories(i)}];          
        end
    end
end

% Display the brain 
function [] = displayBrain()

    global mfDRParamIndex mfDRxSPMarr mfDRFileList mfDRFileIndex mfDRFig;

    matFile = mfDRFileList{mfDRFileIndex};
    
    SPMpath = fullfile(matFile.folder, matFile.name);
    SPM = load(SPMpath);
    SPM = SPM.SPM;
    
    swd = matFile.folder;
    %[swd, ~] = fileparts(matFile);

    % Try to display SPM with each parameter combination
    xSPM = mfDRxSPMarr{mfDRParamIndex};
    xSPM.swd = swd;
        
    % display glass brains
    [hReg, xSPM0, SPM] = spm_results_ui('Setup',xSPM);

    mfDRFig = spm_figure('GetWin','Graphics');
    
    set(mfDRFig,'KeyPressFcn',@keydownCallback);
    
    fprintf('\n*****************************************************\n');
    fprintf('Here''s your brain!\n');
    fprintf('\nPath:\n');
    fprintf('%s\n', SPMpath );
    fprintf('\nContrast Name:\n');
    fprintf('%s\n', xSPM0.title);
    fprintf('\nStatistical Thresholds:\n');
    fprintf('Description: %s\n', xSPM0.thresDesc);
    fprintf('Height Threshold: %.2f\n', xSPM0.u);
    fprintf('Cluster Extent: %i\n', xSPM0.k);
    
    % display interactive results table
    TabDat = spm_list('List',xSPM0, hReg);
    
    % Focus on graphics figure
    figure(mfDRFig);
    
    uiwait(mfDRFig);
end

function [] = incrementPointers()
    global mfDRParamIndex mfDRFileIndex mfDRxSPMarr;
    % increment param index. If param index is greater than total number
    % of input sets, reset to 1 and increment file index.
    mfDRParamIndex = mfDRParamIndex + 1;
    if mfDRParamIndex > numel(mfDRxSPMarr)
        mfDRParamIndex = 1;
        mfDRFileIndex = mfDRFileIndex + 1;
    end
end

function [] = keydownCallback(varargin)
    global mfDRFig mfDRDone;
    currkey=get( mfDRFig,'CurrentKey' ); 
    if strcmp(currkey, 'return')
        incrementPointers();
        uiresume(mfDRFig);
    elseif strcmp( currkey, 'q' )
        mfDRDone = true;
        close(mfDRFig);
        disp('Bye!');
    end
end

function [xSPMarr] = createxSPMarr()
    global mfDRparamSetList;

    xSPMarr = {};

    % Creating a list (column vectors) of indices to create combinations of
    % parameter specifications.
    paramSetLengths = createVecs();    
    paramSetInd = combvec(paramSetLengths{1:end});
    
    % Loop through each index combination
    for j = 1:size(paramSetInd, 2)
       xSPM = struct();
       indx = paramSetInd(:,j);
       
       % Get the map associated with each index
       for i = 1:numel(indx)
          paramFieldSets = mfDRparamSetList{i}
          tempMap = paramFieldSets{indx(i)};
          tempKeys = keys(tempMap);
          
          % Add map fields to struct
          for k = 1:numel(tempKeys)
              xSPM = setfield(xSPM, tempKeys{k}, tempMap(tempKeys{k}));
          end
       end
       
       xSPMarr{j} = xSPM;
    end
end

function [vargout] = createVecs()
    global mfDRparamSetList;
    for i = 1:numel(mfDRparamSetList)
       vargout{i} = 1:numel(mfDRparamSetList{i}); 
    end
end