function [ ] = displayResultsV6(baseDir, subDirs, varargin)
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
%  display');

% reorderableListbox by Erik Koopmans. See:
% https://www.mathworks.com/matlabcentral/fileexchange/37642-reorderable-listbox
addpath( './reorderableListbox_1.1.1' );

% global variables are mainly necessary due to use of callbacks.
% to do: replace with getter/setter functions that use 'persistent'?
global mfDRFig mfDRListCon mfDRSaveList mfDRxSPMarr mfDRFileList mfDRFileBase;
global mfDRFileIndex mfDRParamIndex mfDRParamSize mfDRFLSize mfDRParamName mfDRDone;

mfDRFileBase = baseDir;

% This creates the figure that will contain the listbox of saved brains
mfDRListfig = figure( 'Position', [50 300 1500 700], 'ToolBar', 'none', 'MenuBar', 'none' );
% create the reorderableListbox
mfDRListCon = reorderableListbox( mfDRListfig, ...
                    'Position', [0 0 1500 700], ...
                    'Callback', @listboxCallback, ...
                    'DragOverCallback', @listboxDropCallback );

set( mfDRListCon, 'FontSize', 20 );

mfDRFileIndex = 1;
mfDRParamIndex = 1;

mfDRFig = [];
resultsFig = []; % init to [] in case no brains get displayed
mfDRDone = false;
mfDRSaveList = {};
mfDRParamName = {};

paramSegments = {};

% turn varargin into our global paramSegments list
% outer loop iterates through the options end parameters
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
            elseif ischar(cValueArr)
                cValue = cValueArr;
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
mfDRxSPMarr = createxSPMarr(paramSegments);

% used in de/incrementPointers
mfDRParamSize = numel(mfDRxSPMarr);

% Recursively searching through each analysis type directory for SPM.mat files to try to display
% If no subDirs are provided, search recursively through baseDir
% Creates a list that will be iterated over
mfDRFileList = {};
if isempty( subDirs )
    searchdirs(baseDir);
else
    for sub = subDirs
        dir2search = cell2mat(fullfile(baseDir, sub));
        searchdirs(dir2search);
    end
end

mfDRFLSize = numel(mfDRFileList);

% Display brains.
% If displayBrain ever fails, incrementPoints to that the next call will
% try to look at the next brain.

% loop will continue to displayBrains until we are out of the range of
% brains to display, and the script will exit.
while ~mfDRDone
    try
        resultsFig = displayBrain();
    catch
        warning('displayResults:BrainNotFound','Failed to load brain -- File Index: %i ; Parameter Index: %i', ...
            mfDRFileIndex, mfDRParamIndex);
        incrementPointers();
    end
end

close(mfDRFig);
close(resultsFig);
close(mfDRListfig);

end

function [] = listboxCallback(varargin)
    global mfDRFig mfDRListCon mfDRSaveList;
    disp( mfDRListCon.Parent.SelectionType );
    disp( mfDRListCon.Value  );
    try
        if strcmp( mfDRListCon.Parent.SelectionType, 'open' )
            curBrain = mfDRSaveList{ mfDRListCon.Value };
            uiresume( mfDRFig );
            displayBrain( curBrain.matFile, curBrain.xSPM );
        end
    catch
        disp('LB Click error?');
        disp( mfDRListCon.Parent.SelectionType );
    end
    disp('doneclick');
end

function [] = listboxDropCallback(~, ~, permorder)
    global mfDRSaveList;
    mfDRSaveList = mfDRSaveList( permorder );
    disp( permorder );
    disp('donedrop');
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
function resultsFig = displayBrain(varargin)
    
    global mfDRFig mfDRxSPMarr mfDRFileList mfDRFileIndex mfDRParamIndex mfDRParamName;
    
    if nargin == 2
        matFile = varargin{1};
        xSPM = varargin{2};
    else
        
        matFile = mfDRFileList{mfDRFileIndex};
        
        % Try to display SPM with each parameter combination
        if isempty( mfDRxSPMarr ) % No parameter combinations were specified. The GUI should ask for parameters
            xSPM =  struct();
        else
            xSPM = mfDRxSPMarr{mfDRParamIndex};
        end
    end
    
        
    SPMpath = fullfile(matFile.folder, matFile.name);
    swd = matFile.folder;
    xSPM.swd = swd;
        
    % display glass brains
    [hReg, xSPM0, ~] = spm_results_ui('Setup',xSPM);

    mfDRFig = spm_figure('GetWin','Graphics');
    
    set(mfDRFig,'KeyPressFcn',@keydownCallback);
    
    fprintf('\n*****************************************************\n');
    fprintf('Here''s your brain! (Press ''q'' to quit)\n');
    fprintf('\nPath for brain index %i:\n', mfDRFileIndex);
    fprintf('%s\n', SPMpath );
    fprintf('\nContrast Name:\n');
    fprintf('%s\n', xSPM0.title);
    fprintf('\nStatistical Thresholds:\n');
    fprintf('Description: %s\n', xSPM0.thresDesc);
    fprintf('Height Threshold: %.2f\n', xSPM0.u);
    fprintf('Cluster Extent: %i\n', xSPM0.k);
    
    mfDRParamName{ mfDRParamIndex } = xSPM0.title;
    
    % display interactive results table
    TabDat = spm_list('List',xSPM0, hReg);
    
    % Focus on graphics figure
    % this not working?
     %figure(mfDRFig);
     %set(0,'CurrentFigure', mfDRFig);
     
     resultsFig = hReg.Parent.Parent;
     
     uiwait(mfDRFig);
end

function [] = incrementPointers()
    global mfDRFileIndex mfDRParamIndex mfDRParamSize mfDRFLSize;
    
    % increment param index. If param index is greater than total number
    % of input sets, reset to 1 and increment file index.
    mfDRParamIndex = mfDRParamIndex + 1;
    if mfDRParamIndex > mfDRParamSize
        mfDRParamIndex = 1;
        mfDRFileIndex = mfDRFileIndex + 1;
    end
    if mfDRFileIndex > mfDRFLSize
        mfDRFileIndex = mfDRFLSize;
        mfDRParamIndex = mfDRParamSize;
        msgbox( {'No more brains!' 'Press ''q'' when you''re ready to quit.'}, 'modal' );
    end
end

function [] = decrementPointers()
    global mfDRFileIndex mfDRParamIndex mfDRParamSize;
    
    % increment param index. If param index is greater than total number
    % of input sets, reset to 1 and increment file index.
    mfDRParamIndex = mfDRParamIndex - 1;
    if mfDRParamIndex < 1
        mfDRParamIndex = mfDRParamSize;
        mfDRFileIndex = mfDRFileIndex - 1;
    end
    % don't allow us to go back past first file
    if mfDRFileIndex < 1
        mfDRFileIndex = 1;
        mfDRParamIndex = 1;
    end
end

function [] = saveCurrentFigure()
    global mfDRListCon mfDRSaveList mfDRParamName mfDRFileBase;
    global mfDRFileIndex mfDRParamIndex mfDRFileList mfDRxSPMarr;
    
    curMat = mfDRFileList{mfDRFileIndex};
    curxSPM = mfDRxSPMarr{mfDRParamIndex};
    
    brainInfo = struct( 'matFile', curMat, 'xSPM', curxSPM );
    
    tempRow = mfDRParamName{mfDRParamIndex};
    
    fields = fieldnames( curxSPM );
    for i = 1:numel(fields)
        curVal = curxSPM.(fields{i});
        if ~isstring(curVal)
            curVal = num2str(curVal);
        end
        tempRow = [tempRow '/ ' { [fields{i} '=' curVal] }];
    end
    
    mfDRSaveList = [mfDRSaveList, {brainInfo}];
    
    curVal = get( mfDRListCon, 'string' );
    
    curPath = strsplit( curMat.folder, mfDRFileBase );
    curPath = curPath{2};
    
    tempRow = [tempRow ' / ' curPath];
    
%     disp( 'debug' );
%     disp( curVal );
%     disp('d2');
%     disp( tempRow );
    
    tempRow = cellstr(cell2mat(tempRow));

    curVal = [curVal; tempRow];
    
    set( mfDRListCon, 'string', curVal );
end

function [] = keydownCallback(~, event)
    global mfDRFig mfDRDone;

    currkey = event.Key;
    dir = 0;
    switch currkey
        case { 'return', 'rightarrow' }
            incrementPointers();
            uiresume(mfDRFig);
        case 'leftarrow'
            decrementPointers();
            uiresume(mfDRFig);
        case 's'
            saveCurrentFigure();
        case 'r' % resume after looking at saved brains
            displayBrain();
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