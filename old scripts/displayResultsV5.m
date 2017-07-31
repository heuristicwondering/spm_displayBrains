function [ ] = displayResultsV5(baseDir, subDirs, varargin)
%DISPLAYRESULTS Cycles through directories to display contrast results.
% baseDir is a folder whose children (at some depth) contain SPM.mat files
% subDirs is an optional cell-array of analyses to check.
%   FORMAT  displayResults( './usrdir/analyses', {'analysis1', 'analysis2', ...}, ...
%               { 'Im', [], 'k', 0 }, { 'Ic', [1:6] }, ...
%               { 'thresDesc', { 'FWE', 'none' }, 'u', { 0.05, 0.001 } });
%           displayResults( './usrdir/analyses', {} );
% If present, subDirs should correspond to subfolders immediately below the baseDir.
% The variable number of arguments then specifies sets of parameters
% and values.
%   For example:
%       { 'Im', [] }
%    would set the Im parameter to [] and k to 0. Here there will be one
%    set of input parameters.
%       { 'Im', [], k, 0 }, { 'Ic', [1:6] }
%    sets Im and k as above, and Ic will vary from 1 to 6. Here there will
%    be 6 sets of input parameters.
%       { 'Im', [], k, 0 }, { 'Ic', [1:6] }, ...
%           { 'thresDesc', { 'FWE', 'none' }, u, { 0.05, 0.001 } }
%   sets Im, k, and Ic as above, and then adds two other sets, { thresDesc
%   = FWE, u = 0.05 } and { thresDesc = FWE, u = 0.001 }
%   Here there will be 12 sets of input parameters.
%
%   For a helpful resource on the required parameters of the xSPM struct,
%   see: http://andysbrainblog.blogspot.com/2013/02/using-spmmat-to-stay-on-track-ii.html
%
%   **** The parameter u here specifies the alpha value. It will be
%   converted to the height threshold by SPM (See note below) ****
%
%   To quit, press 'q' when the Graphics figure is in focus.
%
%  Note: the swd parameter is set dynamically each time a contrast is
%  displayed.

global mfDRFig mfDRDirection mfDRDone;

fileIndex = 1;
paramIndex = 1;

mfDRFig = [];
mfDRDone = false;

% Inititializing required fields of the xSPM struct.
% This is implemented as a nested array of maps of possible value combinations.
paramSegments = {};

% turn varargin into our global paramSegments list
nvarg = numel( varargin );
for i = 1:nvarg
    
    paramFVSets = {};
    
    cFieldSet = varargin{i};
    
    fss = numel(cFieldSet{2});
    if fss == 0
        fss = 1;
    end
    
    for j = 1:fss
        
        paramFVPairs = containers.Map;
        
        for k = 1:2:numel(cFieldSet)
            
            cFieldName = cFieldSet{k};
            cValueArr = cFieldSet{k+1};
            if isnumeric( cValueArr ) && numel( cValueArr ) > 1
                cValueArr = num2cell( cValueArr );
            end
            
            if numel(cValueArr) == 0
                cValue = [];
            elseif iscell( cValueArr )
                cValue = cValueArr{j};
            else
                cValue = cValueArr(j);
            end
            
            paramFVPairs( cFieldName ) = cValue;
            
        end
        
        paramFVSets = [paramFVSets, {paramFVPairs}];
        
    end
    
    paramSegments = [paramSegments, {paramFVSets}];
    
end

% Create a cell array of parameter sets to try to display
xSPMarr = createxSPMarr(paramSegments);


% Recursively searching through each analysis type directory for SPM.mat files to try to display
% If no subDirs are provided, search recursively through baseDir
% Creates a list that will be iterated over
fileList = {};
if isempty( subDirs )
    fileList = searchdirs(baseDir, fileList);
else
    for sub = subDirs
        dir2search = cell2mat(fullfile(baseDir, sub));
        fileList = searchdirs(dir2search, fileList);
    end
end


% Display brains.
% If displayBrain ever fails, incrementPoints to that the next call will
% try to look at the next brain.

% loop will continue to displayBrains until we are out of the range of
% brains to display, and the script will exit.
while fileIndex <= numel(fileList) && ~mfDRDone
    try
        resultsFig = displayBrain(xSPMarr, fileIndex, paramIndex, fileList);
        
        if mfDRDirection == 1
            [fileIndex, paramIndex] = incrementPointers(fileIndex, paramIndex, xSPMarr);
        elseif mfDRDirection == 2
            [fileIndex, paramIndex] = decrementPointers(fileIndex, paramIndex, xSPMarr);
        end
        
    catch
        warning('displayResults:BrainNotFound','Failed to load brain -- File Index: %i ; Parameter Index: %i', ...
            fileIndex, paramIndex);
        [fileIndex, paramIndex] = incrementPointers(fileIndex, paramIndex, xSPMarr);
    end
end

close(mfDRFig);
close(resultsFig);

end

% Recursively search directory for SPM.mat files.
function [fileList] = searchdirs(dir2search, fileList)
    directories = dir(dir2search);
    for i = 3:numel(directories)
        if directories(i).isdir
           fileList = searchdirs(fullfile(directories(i).folder, directories(i).name), fileList);
        elseif strcmp(directories(i).name, 'SPM.mat')
            % If and SPM.mat file is found, add to file list
            fileList = [fileList, {directories(i)}];          
        end
    end
end

% Display the brain 
function resultsFig = displayBrain(xSPMarr, fileIndex, paramIndex, fileList)
    
    global mfDRFig;

    matFile = fileList{fileIndex};
    
    SPMpath = fullfile(matFile.folder, matFile.name);
    
    swd = matFile.folder;
    %[swd, ~] = fileparts(matFile);

    % Try to display SPM with each parameter combination
    if isempty( xSPMarr ) % No parameter combinations were specified. The GUI should ask for parameters
        xSPM =  struct();
    else
        xSPM = xSPMarr{paramIndex};
    end
    
    xSPM.swd = swd;
        
    % display glass brains
    [hReg, xSPM0, ~] = spm_results_ui('Setup',xSPM);

    mfDRFig = spm_figure('GetWin','Graphics');
    
    set(mfDRFig,'KeyPressFcn',@keydownCallback);
    
    fprintf('\n*****************************************************\n');
    fprintf('Here''s your brain! (Press ''q'' to quit)\n');
    fprintf('\nPath for brain index %i:\n', fileIndex);
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
    % this not working?
     %figure(mfDRFig);
     %set(0,'CurrentFigure', mfDRFig);
     
     resultsFig = hReg.Parent.Parent;
     
     uiwait(mfDRFig);
end

function [fileIndex, paramIndex] = incrementPointers(fileIndex, paramIndex, xSPMarr)
    % increment param index. If param index is greater than total number
    % of input sets, reset to 1 and increment file index.
    paramIndex = paramIndex + 1;
    if paramIndex > numel(xSPMarr)
        paramIndex = 1;
        fileIndex = fileIndex + 1;
    end
end

function [fileIndex, paramIndex] = decrementPointers(fileIndex, paramIndex, xSPMarr)
    % increment param index. If param index is greater than total number
    % of input sets, reset to 1 and increment file index.
    paramIndex = paramIndex - 1;
    if paramIndex < 1
        paramIndex = numel(xSPMarr);
        fileIndex = fileIndex - 1;
    end
    % don't allow us to go back past first file
    if fileIndex < 1
        fileIndex = 1;
        paramIndex = 1;
    end
end

function [] = keydownCallback(~, event)
    global mfDRDirection mfDRFig mfDRDone;
    %currkey=get( mfDRFig,'CurrentKey' ); 
    currkey = event.Key;
    dir = 0;
    switch currkey
        case { 'return', 'rightarrow' }
            mfDRDirection = 1; % in lieu of return value
            uiresume(mfDRFig);
        case 'leftarrow'
            mfDRDirection = 2; % ibid.
            uiresume(mfDRFig);
        case 'q'
            mfDRDone = true;
            uiresume(mfDRFig);
           % close(mfDRFig);
            disp('Bye!');
    end
end

function xSPMarr = createxSPMarr(paramSegments)

    xSPMarr = {};
    
    if isempty(paramSegments) % If no parameter combinations to specify, the GUI will ask for them.
        return
    end

    % Creating a list (column vectors) of indices to create combinations of
    % parameter specifications.
    paramSetLengths = createVecs(paramSegments);    
    paramSetInd = combvec(paramSetLengths{1:end});
    
    % Loop through each index combination
    for j = 1:size(paramSetInd, 2)
       xSPM = struct();
       indx = paramSetInd(:,j);
       
       % Get the map associated with each index
       for i = 1:numel(indx)
          paramFieldSets = paramSegments{i};
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

function vargout = createVecs(paramSegments)
    for i = 1:numel(paramSegments)
       vargout{i} = 1:numel(paramSegments{i}); 
    end
end