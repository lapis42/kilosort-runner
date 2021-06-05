function runKs2(startingDirectory, configFileName, fileType)
    %RUNKS Batch sorting using Kilosort2
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%                       USER PRESET START                         %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    

    % 1. Set starting directory to search
    if nargin < 1 || isempty(startingDirectory) || exist(startingDirectory, 'dir')~=7
        startingDirectory = pwd; % select current directory if no input
    end


    % 2. Select configuration file
    if nargin < 2 || isempty(configFileName)
        configFileName = ''; % configuration file should be in the 'sort-runner/config' folder
    end


    % 3. Select file type to search
    if nargin < 3 || isempty(fileType)
        fileType = '*.bin';
    end
    

    % Working directory: directory for saving temporary data.
    workingDirectory = fullfile(startingDirectory, 'temp'); 
    
    % Kilosort location
    kilosortDirectory = '/home/kimd/Dropbox/src/Kilosort2';
    
    % npy plugin location
    npyDirectory = '/home/kimd/Dropbox/src/npy-matlab/npy-matlab';

    % Redo policy: choose whether do clustering if output file alreay exists, {'yes', 'no', 'ask'}
    recluster = 'ask'; 

    % Check sub-directories to find files
    checkSubDir = true;
    

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%                        USER PRESET END                          %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    

    disp('*****************************************');
    disp('******** Batch Kilosort2 sorting ********');
    disp('*****************************************');

    %% Choose files to sort
    [fileList, excludedChannel] = util.fileSelector(startingDirectory, checkSubDir, fileType);
    if isempty(fileList); return; end

    %% Preparation
    % add path kilosort directory (excluding git directory with '.')
    ksSubDir = strsplit(genpath(kilosortDirectory), pathsep);
    isGitDir = cellfun(@(x) ismember('.', x), ksSubDir);
    addpath(strjoin(ksSubDir(~isGitDir), pathsep));

    % add path npy-matlab directory
    npySubDir = strsplit(genpath(npyDirectory), pathsep);
    isGitDir = cellfun(@(x) ismember('.', x), npySubDir);
    addpath(strjoin(npySubDir(~isGitDir), pathsep));
    
    % make working directory
    if exist(workingDirectory, 'dir')~=7
        mkdir(workingDirectory);
    end

    % current file location
    sortrunnerDirectory = fileparts(mfilename('fullfilepath'));
    
    %% run
    nFile = length(fileList);
    for iFile = 1:nFile
        clear rez ops
        if exist(fileList{iFile}, 'file') == 2
            [~, fileName] = fileparts(fileList{iFile});
            disp([newline, '================    ', fileName, '    ================', newline]);
            
            % load preset
            run(fullfile(kilosortDirectory, 'configFiles', 'configFile384.m')); % load default configuration
            if ~isempty(configFileName) % overwrite default configuration
                configPath = fullfile(sortrunnerDirectory, [configFileName, '.m']);
                if exist(configPath, 'file') == 2
                    run(configPath);
                else
                    error('Config file does not exist');
                end
            end

            % search channel map
            if exist(ops.chanMap, 'file') == 0
                chanMapTemp = strsplit(ops.chanMap, '\');
                chanMapFn = chanMapTemp{end};
                chanMapKs = fullfile(kilosortDirectory, 'configFiles', chanMapFn);
                chanMapSr = fullfile(sortrunnerDirectory, 'configFiles', chanMapFn);
                if exist(chanMapKs, 'file') == 2
                    ops.chanMap = chanMapKs;
                elseif exist(chanMapSr, 'file') == 2
                    ops.chanMap = chanMapSr;
                else
                    error('Cannot find channel map mat file');
                end
            end
            ops.trange = [0, Inf];
            ops.wd = workingDirectory;
            ops.fproc = fullfile(workingDirectory, 'temp_wh.dat');

            meta = readMeta(fileList{iFile});
            ops = setOps(ops, fileList{iFile}, excludedChannel{iFile}, meta, kilosortDirectory);
      
            % recluster policy check
            doSort = true;
            fname = fullfile(ops.saveDir, 'params.py');
            if exist(fname, 'file')==2
                disp([fname, ' already exists.']);
                if strcmp(recluster, 'ask')
                    cmd = input('Re-cluster this file? [y/N]: ', 's');
                    if isempty(cmd) || lower(cmd(1)) ~= 'y'
                        doSort = false;
                    end
                elseif strcmp(recluster, 'no')
                    doSort = false;
                end
            end
            
            % main run
            if doSort
                disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', preprocessing']);
                rez = preprocessDataSub(ops);

                disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', preclustering']);
                rez = clusterSingleBatches(rez);

                disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', optimization']);
                rez = learnAndSolve8b(rez);
                
                disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', merge']);
                rez = find_merges(rez, 1);

                disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', spilt by svd']);
                rez = splitAllClusters(rez, 1);
                
                disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', spilt by amplitudes']);
                rez = splitAllClusters(rez, 0);
                
                disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', setting cutoff']);
                rez = set_cutoff(rez);

                disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', saving data to phy format']);
                rezToPhy(rez, ops.saveDir);
            end

            disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', done']);
            close all;
        end
    end
end


function ops = setOps(ops, fileName, excludedChannel, meta, kilosortDirectory)
    load(ops.chanMap);
    connected(excludedChannel) = false;

    cm = struct();
    cm.chanMap = chanMap(connected);
    cm.xcoords = xcoords(connected);
    cm.ycoords = ycoords(connected);
    ops.chanMap = cm;
    
    if isfield(meta, 'nSavedChans')
        ops.NchanTOT = str2double(meta.nSavedChans);
    elseif ~isfield(ops, 'NchanTOT')
        ops.NchanTOT = length(chanMap);
    end

    ops.fbinary = fileName;
    fileDir = fileparts(fileName);
    ops.rootZ = fileDir;
    ops.saveDir = fileDir;
end


function meta = readMeta(binFile)
    % Parse ini file into cell entries C{1}{i} = C{2}{i}
    metaFile = replace(binFile, '.bin', '.meta');
    if exist(metaFile, 'file')~=2
        meta = [];
        return
    end
    fid = fopen(metaFile, 'r');
    C = textscan(fid, '%[^=] = %[^\r\n]');
    fclose(fid);

    % New empty struct
    meta = struct();

    % Convert each cell entry into a struct entry
    for i = 1:length(C{1})
        tag = C{1}{i};
        if tag(1) == '~'
            % remake tag excluding first character
            tag = sprintf('%s', tag(2:end));
        end
        meta.(tag) = C{2}{i};
    end
end
