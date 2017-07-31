function [ ] = displayResultsV4(baseDir, subDirs, varargin)
%DISPLAYRESULTS Cycles through directories to display contrast results.
% baseDir is a folder whose children (at some depth) contain SPM.mat files
% subDirs is an optional cell-array of analyses to check.
%   if present, these should correspond to subfolder of the baseDir
% variable number of arguments then specifies sets of parameters
% and values.
% For example:
%   { 'Im', [] }
% would set the Im parameter to [] and k to 0.
%   { 'Im', [], k, 0 }, { 'Ic', [1:6] }
% sets Im and k as above, and Ic will vary from 1 to 6.
%   { 'Im', [], k, 0 }, { 'Ic', [1:6] }, ...
%       { 'thresDesc', { 'FWE', 'none' }, u, { 0.05, 0.001 } }
% sets Im, k, and Ic as above, and then adds two other sets, { thresDesc:
% FWE, u = 0.05 } and { thresDesc = FWE, u = 0.001 }
%
%  Note: the swd parameter is set dynamically each time a contrast is
%  displayed.

global mfDRFileList mfDRFileIndex mfDRParamIndex mfDRxSPMarr mfDRparamSegments mfDRDone;

mfDRFileList = {};
mfDRFileIndex = 1;
mfDRParamIndex = 1;

mfDRDone = false;

% Inititializing required fields of the xSPM struct.
% This is implemented as a nested array of maps of possible value combinations.
mfDRparamSegments = {};

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
	
	mfDRparamSegments = [mfDRparamSegments, {paramFVSets}];
	
end

% Create a cell array of parameter sets to try to display
mfDRxSPMarr = createxSPMarr();


% Recursively searching through each analysis type directory for SPM.mat files to try to display
% If no subDirs are provided, search recursively through baseDir
% Creates a list that will be iterated over
if isempty( subDirs )
    searchdirs(baseDir);
else
    for sub = subDirs
        dir2search = cell2mat(fullfile(baseDir, sub));
        searchdirs(dir2search);
    end
end


% Display first brain.
% If displayBrain ever fails, incrementPoints to that the next call will
% try to look at the next brain.
try
    displayBrain();
catch
    incrementPointers();
end

% loop will continue to displayBrains until we are out of the range of
% brains to display, and the script will exit.
while mfDRFileIndex <= numel(mfDRFileList) && ~mfDRDone
    try
        displayBrain();
    catch
        incrementPointers();
    end
end

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
    fprintf('\nPath for brain index %i:\n', mfDRFileIndex);
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

function [] = decrementPointers()
    global mfDRParamIndex mfDRFileIndex mfDRxSPMarr;
    % increment param index. If param index is greater than total number
    % of input sets, reset to 1 and increment file index.
    mfDRParamIndex = mfDRParamIndex - 1;
    if mfDRParamIndex < 1
        mfDRParamIndex = numel(mfDRxSPMarr);
        mfDRFileIndex = mfDRFileIndex - 1;
    end
    % don't allow us to go back past first file
    if mfDRFileIndex < 1
        mfDRFileIndex = 1;
        mfDRParamIndex = 1;
    end
end

function [] = keydownCallback(~, event)
    global mfDRFig mfDRDone;
    %currkey=get( mfDRFig,'CurrentKey' ); 
    currkey = event.Key;
    switch currkey
        case { 'return', 'rightarrow' }
            incrementPointers();
            uiresume(mfDRFig);
        case 'leftarrow'
            decrementPointers();
            uiresume(mfDRFig);
        case 'q'
            mfDRDone = true;
            close(mfDRFig);
            disp('Bye!');
    end
end

function [xSPMarr] = createxSPMarr()
    global mfDRparamSegments;

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
          paramFieldSets = mfDRparamSegments{i};
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
    global mfDRparamSegments;
    for i = 1:numel(mfDRparamSegments)
       vargout{i} = 1:numel(mfDRparamSegments{i}); 
    end
end