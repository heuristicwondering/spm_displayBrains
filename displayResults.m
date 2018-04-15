function [ ] = displayResultsV8(varargin)
%   DISPLAYRESULTS - Utility to display and manage lists of fMRI contrasts with SPM.
%     displayResults is a utility for viewing the results of fMRI contrasts
%     in SPM. It's primary useage is to pass a directory which is
%     transversed in order to find SPM.mat files to display. Sets of
%     parameter values can also be specified. (Any parameters required by
%     SPM that aren't specified in this fashion are then configured via the
%     GUI.) Once a set of brain images along with the SPM parameters are
%     loaded, the utility presents the first contrast. The contrasts can
%     then be cycled through, and saved to a list for later review. These
%     lists can be saved and loaded again later.
% 
%     Usage:
% 
%     To move to the next contrast, you can press Enter or the right arrow
%     key. To go back, press the left arrow. To save a particular contrast
%     for later review, press the 's' key. An entry for that contrast will
%     be added to the Saved Brains figure. To display a saved contrast,
%     double-click on its entry in the listbox. The contrasts can also be
%     reordered by dragging them (thanks to reorderableListbox, see
%     requirements). These lists of contrasts can be saved and loaded
%     later. Note: Loading a list will overwrite any currently saved
%     contrasts. If you are reviewing a saved contrast and you want to
%     return to cycling through brains, press 'r'. Pressing 'q' will
%     quit.
% 
%     FORMAT displayResults( baseDir )
%     FORMAT displayResults( baseDir, subDirs )
%     FORMAT displayResults( baseDir, subDirs, paramSegment1, [paramSegment2,...] )
%     FORMAT displayResults()
%         The last form is useful if you only want to review preiously
%         saved lists of brains.
% 
%     Inputs:
%         baseDir - A directory that will be traversed to find SPM.mat
%           files.
%         subDirs - An optional cell-array of directory names
%           directly inside of baseDir directory. If this parameter is
%           present, the serch for SPM.mat files will begin with these
%           directories rather than baseDir. If you are specifying SPM
%           parameter segments but not the subDirs variabble, pass an
%           empty matrix.
%         paramSegments - Cell-arrays whos structure is described below.
% 
%     Paramter Segments:
% 
%     Example - Specifing a single value per parameter:
% 
%         { 'basepname', 0.05, 'baseParam2', 'strval' }
% 
%     This would give us a single paramter set:
%         { basepname: 0.05, baseParam2, strval }
% 
%     Consider adding a second parameter segment, which has two values per
%     parameter:
% 
%         { 'pname', ...
%             {42, ...
%              53}, ...
%           'foo', ...
%             {'bar', ...
%              'paz'} ...
%         }
% 
%     Together, these will result in two sets of parameters that will be
%     passed to SPM to display a particular contrast:
%         { basepname: 0.05, baseParam2: strval, pname: 42, foo: bar }
%         { basepname: 0.05, baseParam2: strval, pname: 53, foo: paz }
% 
%     If a third parameter segment is added, ex:
%         { goo, [1:3] }
% 
%     you'll have a total of six sets of parameters:
%         { basepname: 0.05, baseParam2: strval, pname: 42, foo: bar, goo: 1 }
%         { basepname: 0.05, baseParam2: strval, pname: 53, foo: paz, goo: 1 }
%         { basepname: 0.05, baseParam2: strval, pname: 42, foo: bar, goo: 2 }
%         { basepname: 0.05, baseParam2: strval, pname: 53, foo: paz, goo: 2 }
%         { basepname: 0.05, baseParam2: strval, pname: 42, foo: bar, goo: 3 }
%         { basepname: 0.05, baseParam2: strval, pname: 53, foo: paz, goo: 3 }
% 
%     displayResults expects the values passed to be 1-by-N numberic
%     matricies (including 1-by-1, i.e. scalar value), string constants
%     (character vectors), or cell-arrays (presumably containing strings or
%     numbers). In a given parameter segment, if a matrix or cell array
%     value is specified for one parameter, the values of the other
%     parameters should be matricies or cell-arrays of the same size.
% 
%     Requirements:
%       displayResults relies on reorderableListbox by Erik Koopmans.
%       https://www.mathworks.com/matlabcentral/fileexchange/37642-reorderable-listbox
%
%   For a helpful resource on the required parameters of the xSPM struct,
%   see: http://andysbrainblog.blogspot.com/2013/02/using-spmmat-to-stay-on-track-ii.html
%
%   **** The parameter u here specifies the alpha value. It will be
%   converted to the height threshold by SPM (See note below) ****
%
%  Note: the swd parameter is set dynamically each time a contrast is
%  display');

% reorderableListbox by Erik Koopmans. See:
% https://www.mathworks.com/matlabcentral/fileexchange/37642-reorderable-listbox
[ scriptpath, ~ ] = fileparts( mfilename('fullpath' ));
addpath( fullfile( scriptpath, '/reorderableListbox' ) );

% global variables are mainly necessary due to use of callbacks.
% to do: replace with getter/setter functions that use 'persistent'?
global mfDRFig mfDRListfig mfDRListCon mfDRSaveList mfDRxSPMarr mfDRFileList mfDRFileBase;
global mfDRFileIndex mfDRParamIndex mfDRParamSize mfDRFLSize mfDRParamName mfDRDone;

global mfDRHelpString;

mfDRHelpString = [...
    'To move to the next analysis, you can press Enter or the right arrow key.\n'...
    'To go back, press the left arrow. To save a particular analysis for later review,\n'...
    'press the ''s'' key. An entry for that analysis will be added to the Saved Brains figure.\n'...
    'To display a saved analysis, double-click on its entry in the listbox.\n'...
    'The analyses can also be reordered by dragging them. These lists of analyses\n'...
    'can be saved and loaded later. Note: Loading a list will overwrite any currently\n'...
    'saved analyses. If you are reviewing a saved analysis and you want to return to cycling\n'...
    'through brains, press ''r''. Pressing ''q'' will quit.'];


if nargin >= 1
    baseDir = varargin{1};
else
    baseDir = [];
end

if nargin >= 2
    subDirs = varargin{2};
else
    subDirs = [];
end

mfDRFileBase = baseDir;

% This creates the figure that will contain the listbox of saved brains
mfDRListfig = figure( 'Name', 'Saved Brains', 'Position', [50 200 1500 700], 'ToolBar', 'none', 'MenuBar', 'none' );
% create the reorderableListbox
mfDRListCon = reorderableListbox( mfDRListfig, ...
                    'Units', 'normalized', ...
                    'Position', [0 0.2 1 0.8], ...
                    'Callback', @listboxCallback, ...
                    'DragOverCallback', @listboxDropCallback );
saveButton = uicontrol( mfDRListfig, 'String', 'save', ...
                    'Units', 'normalized', ...
                    'Position', [0.2 0 0.2 0.2], ...
                    'Callback', @saveBrainsCallback );
openButton = uicontrol( mfDRListfig, 'String', 'open', ...
                    'Units', 'normalized', ...
                    'Position', [0.4 0 0.2 0.2], ...
                    'Callback', @openBrainsCallback );

% set keydown callback for saved brains figure so that it doesn't matter
% which is in focus.
set(mfDRListfig,'KeyPressFcn',@keydownCallback);
set(mfDRListCon,'KeyPressFcn',@keydownCallback);

% make listbox font bigger than default
set( mfDRListCon, 'FontSize', 20 );

% start at the first brain in the list, and the first set of parameters
mfDRFileIndex = 1;
mfDRParamIndex = 1;

% initialize our variables to appropriate, usually empty, values
mfDRFig = [];
resultsFig = []; % init to [] in case no brains get displayed
mfDRDone = false;
mfDRSaveList = {};
mfDRParamName = {};

paramSegments = {};

% turn the third parameter onward into our global paramSegments list.
% outer loop iterates through each "parameter set" 
nvarg = numel( varargin );
for i = 3:nvarg
    
    % create an empty "field/value pair set" array
    paramFVSets = {};
    
    % get the current parameter set
    cFieldSet = varargin{i};
    
    % odd indices will be field names, even indices are values.
    % check the length of the first value. If it's an empty value, its
    % length will return as 0, but really it is a single empty value.
    % if it's an array (cell or numeric), store its length. All arrays in
    % a set should have the same length.
    % character vectors have to be caught so that they aren't interpretted
    % as multiple characters but as a single string.
    if ischar( cFieldSet{2} )
        fss = 1;
    else
        fss = numel(cFieldSet{2});
        if fss == 0
            fss = 1;
        end
    end
    
    % whatever size was found (1 for a scalar, or the size of the array),
    % we have that many sets of fieldname/value pairs.
    for j = 1:fss
        
        % create a new map to hold the fieldname/value pairs
        paramFVPairs = containers.Map;
        
        % now we loop over the field names passed, and create a
        % fieldname/value pair using the field name and the current value
        % from the enclosing loop.
        for k = 1:2:numel(cFieldSet)
            
            % get the current field name and value
            cFieldName = cFieldSet{k};
            cValueArr = cFieldSet{k+1};
            
            % convert numeric matrices to cell arrays
            if isnumeric( cValueArr ) && numel( cValueArr ) > 1
                cValueArr = num2cell( cValueArr );
            end
            
            % how we retrieve the value depends on the type of data
            if numel(cValueArr) == 0 % no elements means a value of []
                cValue = [];
            elseif ischar(cValueArr)
                % character arrays should be taken in their entirety
                cValue = cValueArr;
            elseif iscell( cValueArr )
                % cell arrays gone through one at a time
                cValue = cValueArr{j};
            else
                % probably a scalar number?
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
if ~isempty( baseDir )
    if isempty( subDirs )
        searchdirs(baseDir);
    else
        for sub = subDirs
            dir2search = cell2mat(fullfile(baseDir, sub));
            searchdirs(dir2search);
        end
    end
end

mfDRFLSize = numel(mfDRFileList);

% Display brains.
% If displayBrain ever fails, incrementPoints to that the next call will
% try to look at the next brain.

% loop will continue to displayBrains until we are out of the range of
% brains to display, and the script will exit.
if isempty( mfDRFileList )
    % if there are no files to display, just wait for ui callbacks
    while ~mfDRDone
        uiwait( mfDRListfig );
    end
else
    while ~mfDRDone
        try
            resultsFig = displayBrain();
        catch
            warning('displayResults:BrainNotFound','Failed to load brain -- File Index: %i ; Parameter Index: %i', ...
                mfDRFileIndex, mfDRParamIndex);
            incrementPointers();
        end
    end
end

close(mfDRFig);
close(resultsFig);
close(mfDRListfig);

end

function [] = saveBrainsCallback(~, ~)
    global mfDRListCon mfDRSaveList;
    [fileName, pathName] = uiputfile;
    if fileName
        lbstrings = get( mfDRListCon, 'String' );
        save( fullfile( pathName, fileName ), 'mfDRSaveList', 'lbstrings' );
    end
end

function [] = openBrainsCallback(~, ~)
    global mfDRListCon mfDRSaveList;
    [fileName, pathName] = uigetfile;
    if fileName
        load( fullfile( pathName, fileName ), 'mfDRSaveList', 'lbstrings' );
        set( mfDRListCon, 'String', lbstrings );
    end
end

function [] = listboxCallback(varargin)
    global mfDRListfig mfDRListCon mfDRSaveList;
    disp( mfDRListCon.Parent.SelectionType );
    disp( mfDRListCon.Value  );
    try
        if strcmp( mfDRListCon.Parent.SelectionType, 'open' )
            curBrain = mfDRSaveList{ mfDRListCon.Value };
            % always resume ui before calling displayBrain
            uiresume( mfDRListfig );
            displayBrain( curBrain.matFile, curBrain.xSPM );
        end
    catch
        disp('LB Click error?');
        disp( mfDRListCon.Parent.SelectionType );
    end
    disp('doneclick');
end

function [] = displaySelectedSavedBrain()
    global mfDRSaveList mfDRListCon mfDRListfig;
    
    curBrain = mfDRSaveList{ mfDRListCon.Value };
    % always resume ui before calling displayBrain
    uiresume( mfDRListfig );
    displayBrain( curBrain.matFile, curBrain.xSPM );
end

function [] = selNextSavedBrain()
    global mfDRListCon;
    
    cont = get( mfDRListCon, 'String' );
    
    if mfDRListCon.Value < numel(cont)
        mfDRListCon.Value = mfDRListCon.Value + 1;
        displaySelectedSavedBrain();
    end
end

function [] = selPrevSavedBrain()
    global mfDRListCon;
    
    cont = get( mfDRListCon, 'String' );
    
    if mfDRListCon.Value > 1
        mfDRListCon.Value = mfDRListCon.Value - 1;
        displaySelectedSavedBrain();
    end
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
    
    global mfDRFig mfDRListfig mfDRxSPMarr mfDRFileList mfDRFileIndex mfDRParamIndex mfDRParamName;
    
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
    fprintf('Here''s your brain! (Press ''h'' for help)\n');
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
     
     uiwait(mfDRListfig);
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
        msgbox( {'No more brains!' 'Press ''h'' for usage help.'}, 'modal' );
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
    global mfDRListfig mfDRDone mfDRHelpString;

    currkey = event.Key;
    dir = 0;
    switch currkey
        case { 'return', 'rightarrow' }
            incrementPointers();
            uiresume(mfDRListfig);
        case 'leftarrow'
            decrementPointers();
            uiresume(mfDRListfig);
        case 'uparrow'
            selPrevSavedBrain();
        case 'downarrow'
            selNextSavedBrain();
        case 's'
            saveCurrentFigure();
        case 'r' % resume after looking at saved brains
            uiresume(mfDRListfig);
        case 'h'
            fprintf('\n*****************************************************\n');
            fprintf(mfDRHelpString);
            fprintf('\n*****************************************************\n');
        case 'q'
            mfDRDone = true;
            uiresume(mfDRListfig);
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
    paramSetInd = combvecPrivate(paramSetLengths);
    
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

function result = combvecPrivate(elements)
    % Solution taken from stewpend0us in 
    % https://www.mathworks.com/matlabcentral/answers/98191-how-can-i-obtain-all-possible-combinations-of-given-vectors-in-matlab#answer_252633
    combinations = cell(1, numel(elements)); %set up the varargout result
    [combinations{:}] = ndgrid(elements{:});
    combinations = cellfun(@(x) x(:), combinations,'uniformoutput',false); %there may be a better way to do this
    result = [combinations{:}]; % NumberOfCombinations by N matrix. Each row is unique.

end