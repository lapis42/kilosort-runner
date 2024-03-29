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
        configFileName = ''; % configuration file should be in the 'kilosort-runner/config' folder
    end


    % 3. Select file type to search
    if nargin < 3 || isempty(fileType)
        fileType = '*.bin';
    end
    

    % Working directory: directory for saving temporary data.
    workingDirectory = fullfile(startingDirectory, 'temp'); 
    
    % Kilosort location
    kilosortDirectory = '/home/kimd/Dropbox/src/matlab-code/Kilosort2';
    
    % npy plugin location
    npyDirectory = '/home/kimd/Dropbox/src/matlab-code/npy-matlab/npy-matlab';

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
    % addpath kilosort directory (excluding git directory with '.')
    ksSubDir = strsplit(genpath(kilosortDirectory), pathsep);
    isGitDir = cellfun(@(x) ismember('.', x), ksSubDir);
    addpath(strjoin(ksSubDir(~isGitDir), pathsep));

    % addpath npy-matlab directory
    npySubDir = strsplit(genpath(npyDirectory), pathsep);
    isGitDir = cellfun(@(x) ismember('.', x), npySubDir);
    addpath(strjoin(npySubDir(~isGitDir), pathsep));

    % current file location (and addpath)
    sortrunnerDirectory = fileparts(mfilename('fullfilepath'));

    srSubDir = strsplit(genpath(sortrunnerDirectory), pathsep);
    isGitDir = cellfun(@(x) ismember('.', x), srSubDir);
    addpath(strjoin(srSubDir(~isGitDir), pathsep));
    
    % make working directory
    if exist(workingDirectory, 'dir')~=7
        mkdir(workingDirectory);
    end

    
    %% run
    nFile = length(fileList);
    for iFile = 1:nFile
        clear rez ops
        if exist(fileList{iFile}, 'file') == 2
            [~, fileName] = fileparts(fileList{iFile});
            disp([newline, '================    ', fileName, '    ================', newline]);

            % load meta data
            meta = readMeta(fileList{iFile});
            
            % load preset
            run(fullfile(kilosortDirectory, 'configFiles', 'configFile384.m')); % load default configuration
            if ~isempty(configFileName) % overwrite default configuration
                configPath = fullfile(sortrunnerDirectory, 'config', [configFileName, '.m']);
                if exist(configPath, 'file') == 2
                    run(configPath);
                else
                    error('Config file does not exist');
                end
            else
                % if config file is not specified try to check meta data
                ops = makeChanMap(ops, fileList{iFile}, meta);
            end

            % search channel map
            if exist(ops.chanMap, 'file') == 0
                chanMapTemp = strsplit(ops.chanMap, '\');
                chanMapFn = chanMapTemp{end};
                chanMapKs = fullfile(kilosortDirectory, 'configFiles', chanMapFn);
                chanMapSr = fullfile(sortrunnerDirectory, 'config', chanMapFn);
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

                disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', saving data as a mat file']);
                rez.cProj = [];
                rez.cProjPC = [];
                fname = fullfile(ops.saveDir, 'rez2.mat');
                save(fname, 'rez', '-v7.3');

            end

            disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', done']);
            close all;
        end
    end
end


function ops = makeChanMap(ops, binFile, meta)

    chanMapFile = fullfile(fileparts(binFile), 'chanMap.mat');

    Nchannels = meta.snsApLfSy(1);
    connected = true(Nchannels, 1);
    chanMap = 1:Nchannels;
    chanMap0ind = chanMap - 1;
    kcoords = ones(Nchannels, 1);

    % check imec
    if strcmp(meta.typeThis, 'imec')

        if meta.imDatPrb_type == 0

            % NP1
            xPos = {repmat([43, 11; 27, 59], 240, 1)};
            yPos = {repmat((0:20:9580)', 1, 2)};

        else

            % NP2
            xPos = cell(1, 4);
            yPos = cell(1, 4);
            for iShank = 1:4
                xPos{iShank} = repmat([0, 32] + 250*(iShank-1), 640, 1);
                yPos{iShank} = repmat((0:15:9585)', 1, 2);
            end

        end
    else

        xPos = {zeros(Nchannels, 1)};
        yPos = {(1:Nchannels)' * 15};
        
    end

    xcoords = zeros(Nchannels, 1);
    ycoords = zeros(Nchannels, 1);
    for iC = 1:Nchannels
        map = str2double(split(meta.snsShankMap{iC}, ':'))+1;
        xcoords(iC) = xPos{map(1)}(map(3), map(2));
        ycoords(iC) = yPos{map(1)}(map(3), map(2));
    end

    fs = meta.imSampRate;


    save(chanMapFile, ...
        'chanMap', 'connected', 'xcoords', 'ycoords', 'kcoords', 'chanMap0ind', 'fs');

    ops.chanMap = chanMapFile;

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
        ops.NchanTOT = meta.nSavedChans;
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
            if strcmp(tag, 'imroTbl')
                meta.(tag) = regexp(C{2}{i}, '\d+ \d+ \d+ \d+ \d+ \d+', 'match');
            elseif strcmp(tag, 'snsChanMap')
                meta.(tag) = regexp(C{2}{i}, 'AP\d+;\d+:\d+', 'match');
            elseif strcmp(tag, 'snsShankMap')
                meta.(tag) = regexp(C{2}{i}, '\d+:\d+:\d+:\d+', 'match');
            end
        else
            valueTemp = str2double(strsplit(C{2}{i}, ','));
            if isnan(valueTemp)
                meta.(tag) = C{2}{i};
            else
                meta.(tag) = valueTemp;
            end
        end
    end
end
