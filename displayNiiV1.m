function [ ] = displayNiiV1(baseDir, subDirs, exp)


% reorderableListbox by Erik Koopmans. See:
% https://www.mathworks.com/matlabcentral/fileexchange/37642-reorderable-listbox
addpath( './reorderableListbox_1.1.1' );

% global variables are mainly necessary due to use of callbacks.
% to do: replace with getter/setter functions that use 'persistent'?
global mfDNFig mfDNListfig mfDNListCon mfDNSaveList mfDNFileList mfDNFileBase;
global mfDNFileIndex mfDNFLSize mfDNDone;

mfDNFileBase = baseDir;

% This creates the figure that will contain the listbox of saved brains
mfDNListfig = figure( 'Name', 'Saved Brains', 'Position', [50 300 1500 700], 'ToolBar', 'none', 'MenuBar', 'none' );
% create the reorderableListbox
mfDNListCon = reorderableListbox( mfDNListfig, ...
                    'Units', 'normalized', ...
                    'Position', [0 0.2 1 0.8], ...
                    'Callback', @listboxCallback, ...
                    'DragOverCallback', @listboxDropCallback );
saveButton = uicontrol( mfDNListfig, 'String', 'save', ...
                    'Units', 'normalized', ...
                    'Position', [0.2 0 0.2 0.2], ...
                    'Callback', @saveBrainsCallback );
openButton = uicontrol( mfDNListfig, 'String', 'open', ...
                    'Units', 'normalized', ...
                    'Position', [0.4 0 0.2 0.2], ...
                    'Callback', @openBrainsCallback );

% set keydown callback for saved brains figure so that it doesn't matter
% which is in focus.
set(mfDNListfig,'KeyPressFcn',@keydownCallback);
set(mfDNListCon,'KeyPressFcn',@keydownCallback);

% make listbox font bigger than default
set( mfDNListCon, 'FontSize', 20 );

% start at the first brain in the list, and the first set of parameters
mfDNFileIndex = 1;

% initialize our variables to appropriate, usually empty, values
mfDNFig = [];
resultsFig = []; % init to [] in case no brains get displayed
mfDNDone = false;
mfDNSaveList = {};

% Recursively searching through each analysis type directory for SPM.mat files to try to display
% If no subDirs are provided, search recursively through baseDir
% Creates a list that will be iterated over
mfDNFileList = {};
if ~isempty( baseDir )
    if isempty( subDirs )
        searchdirs(baseDir, exp);
    else
        for sub = subDirs
            dir2search = cell2mat(fullfile(baseDir, sub));
            searchdirs(dir2search, exp);
        end
    end
end

mfDNFLSize = numel(mfDNFileList);

% Display brains.
% If displayBrain ever fails, incrementPoints to that the next call will
% try to look at the next brain.

% loop will continue to displayBrains until we are out of the range of
% brains to display, and the script will exit.
if isempty( mfDNFileList )
    % if there are no files to display, just wait for ui callbacks
    while ~mfDNDone
        uiwait( mfDNListfig );
    end
else
    while ~mfDNDone
        try
            displayBrain();
        catch
            warning('displayResults:BrainNotFound',...
                'Failed to load brain -- File Index: %i', mfDNFileIndex);
            incrementPointers();
        end
    end
end

% close nii fig?
close(mfDNFig);
close(mfDNListfig);

end

function [] = saveBrainsCallback(~, ~)
    global mfDNListCon mfDNSaveList;
    fileName = uiputfile;
    if fileName
        lbstrings = get( mfDNListCon, 'String' );
        save( fileName, 'mfDNSaveList', 'lbstrings' );
    end
end

function [] = openBrainsCallback(~, ~)
    global mfDNListCon mfDNSaveList;
    fileName = uigetfile;
    if fileName
        load( fileName, 'mfDNSaveList', 'lbstrings' );
        set( mfDNListCon, 'String', lbstrings );
    end
end

function [] = listboxCallback(varargin)
    global mfDNListfig mfDNListCon mfDNSaveList;
    disp( mfDNListCon.Parent.SelectionType );
    disp( mfDNListCon.Value  );
    try
        if strcmp( mfDNListCon.Parent.SelectionType, 'open' )
            curBrain = mfDNSaveList{ mfDNListCon.Value };
            % always resume ui before calling displayBrain
            uiresume( mfDNListfig );
            displayBrain( curBrain.niiFile );
        end
    catch
        disp('LB Click error?');
        disp( mfDNListCon.Parent.SelectionType );
    end
    disp('doneclick');
end

function [] = displaySelectedSavedBrain()
    global mfDNSaveList mfDNListCon mfDNListfig;
    
    curBrain = mfDNSaveList{ mfDNListCon.Value };
    % always resume ui before calling displayBrain
    uiresume( mfDNListfig );
    displayBrain( curBrain.niiFile );
end

function [] = selNextSavedBrain()
    global mfDNListCon;
    
    cont = get( mfDNListCon, 'String' );
    
    if mfDNListCon.Value < numel(cont)
        mfDNListCon.Value = mfDNListCon.Value + 1;
        displaySelectedSavedBrain();
    end
end

function [] = selPrevSavedBrain()
    global mfDNListCon;
    
    cont = get( mfDNListCon, 'String' );
    
    if mfDNListCon.Value > 1
        mfDNListCon.Value = mfDNListCon.Value - 1;
        displaySelectedSavedBrain();
    end
end

function [] = listboxDropCallback(~, ~, permorder)
    global mfDNSaveList;
    mfDNSaveList = mfDNSaveList( permorder );
    disp( permorder );
    disp('donedrop');
end

% Recursively search directory for files files whose names match exp.
function [] = searchdirs(dir2search, exp)

    global mfDNFileList;

    directories = dir(dir2search);
    
    for i = 3:numel(directories)
        if directories(i).isdir
           searchdirs(fullfile(directories(i).folder, directories(i).name), exp);
        elseif ~isempty( regexpi( directories(i).name, exp ) )
            % If file name matches regexp
            mfDNFileList = [mfDNFileList, {directories(i)}];          
        end
    end
end

% Display the brain 
function [] = displayBrain(varargin)
    
    global mfDNFig mfDNListfig mfDNFileList mfDNFileIndex;
    
    if nargin == 1
        niiFile = varargin{1};
    else
        
        niiFile = mfDNFileList{mfDNFileIndex};
    end
    
        
    niipath = fullfile(niiFile.folder, niiFile.name);
        
    % display nii
    spm_image('Display',niipath);

    mfDNFig = spm_figure('GetWin','Graphics');
    
    set(mfDNFig,'KeyPressFcn',@keydownCallback);
    
    fprintf('\n*****************************************************\n');
    fprintf('Here''s your brain! (Press ''h'' for help)\n');
    fprintf('\nPath for brain index %i:\n', mfDNFileIndex);    
        
    % Focus on graphics figure
    % this not working?
     %figure(mfDNFig);
     %set(0,'CurrentFigure', mfDNFig);
     
     uiwait(mfDNListfig);
end

function [] = incrementPointers()
    global mfDNFileIndex mfDNFLSize;
    
    mfDNFileIndex = mfDNFileIndex + 1;
    if mfDNFileIndex > mfDNFLSize
        mfDNFileIndex = mfDNFLSize;
        msgbox( {'No more brains!' 'Press ''h'' for usage help.'}, 'modal' );
    end
end

function [] = decrementPointers()
    global mfDNFileIndex 
    
    mfDNFileIndex = mfDNFileIndex - 1;
    % don't allow us to go back past first file
    if mfDNFileIndex < 1
        mfDNFileIndex = 1;
    end
end

function [] = saveCurrentFigure()
    global mfDNListCon mfDNSaveList mfDNFileBase;
    global mfDNFileIndex mfDNFileList;
    
    curNii = mfDNFileList{mfDNFileIndex};
    
    brainInfo = struct( 'niiFile', curNii );
    
    mfDNSaveList = [mfDNSaveList, {brainInfo}];
    
    curVal = get( mfDNListCon, 'string' );
    
    curPath = strsplit( curNii.folder, mfDNFileBase );
    curPath = curPath{2};
    
    tempRow = curPath;
    
%     disp( 'debug' );
%     disp( curVal );
%     disp('d2');
%     disp( tempRow );

    curVal = [curVal; tempRow];
    
    set( mfDNListCon, 'string', curVal );
end

function [] = keydownCallback(~, event)
    global mfDNListfig mfDNDone mfDNHelpString;

    currkey = event.Key;
    dir = 0;
    switch currkey
        case { 'return', 'rightarrow' }
            incrementPointers();
            uiresume(mfDNListfig);
        case 'leftarrow'
            decrementPointers();
            uiresume(mfDNListfig);
        case 'uparrow'
            selPrevSavedBrain();
        case 'downarrow'
            selNextSavedBrain();
        case 's'
            saveCurrentFigure();
        case 'r' % resume after looking at saved brains
            uiresume(mfDNListfig);
        case 'h'
            fprintf('\n*****************************************************\n');
            fprintf('%s', mfDNHelpString);
            fprintf('\n*****************************************************\n');
        case 'q'
            mfDNDone = true;
            uiresume(mfDNListfig);
            disp('Bye!');
    end
end