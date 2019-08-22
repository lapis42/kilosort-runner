function runKs(startingDirectory, configFileName, fileType)
    %RUNKS Batch sorting using Kilosort2
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%                       USER PRESET START                         %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Starting directory: directory to start finding files.
    if nargin < 1 || exist(startingDirectory, 'dir')~=7
        startingDirectory = '/mnt/data/';
    end

    % The default configuration file is located at 'Kilosort2/configFiles' folder.
    % To generate your own configuration .mat file, check 'Kilosort2/configFiles/createChannelMapFile.m'
    % To make configuration file, copy 'Kilosort2/configFiles/configFile384.m' and modify.
    if nargin < 2
        configFileName = 'configFile384'; % Neuropixel 3A, or 3B (1.0)
%       configFileName = 'configFilehh3x2'; % Janelia acute 64-channel HH-3 probe (2x64)
%       configFileName = 'configFilehh2'; % Janelia acute 64-channel HH-2 probe (2x32)
%       configFileName = 'configFilehh3'; % Janelia acute 64-channel HH-3 probe (1x64) 
    end

    % ops.NchanTOT = 385; % Please uncomment this to specify channel number or it will count from the config .mat file

    if nargin < 3
        fileType = '*.bin'; % file format to search
    end
    
    % Working directory: directory for saving temporary data. Choose fast drive like SSD.
    workingDirectory = fullfile(startingDirectory, 'temp'); 
    
    % Kilosort location (just to make sure that your Kilosort2 folder is in your setpaths)
    kilosortDirectory = '/home/kimd/Dropbox/src/Kilosort2';
    
    % npy plugin location (just to make sure that your npy plugin folder is in your setpaths)
    npyDirectory = '/home/kimd/Dropbox/src/npy-matlab/npy-matlab';

    % Redo policy: choose whether do clustering if output file alreay exists, {'yes', 'no', 'ask'}
    recluster = 'ask'; 

    % Make phy format file
    makePhy = true;
    
    % Check sub-directories to find files
    checkSubDir = true;

    

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%                        USER PRESET END                          %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    disp('*****************************************');
    disp('******** Batch Kilosort2 sorting ********');
    disp('*****************************************');

    %% Choose files to sort
    [fileList, excludedChannel] = fileSelector(startingDirectory, checkSubDir, fileType);
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
    
    %% run
    nFile = length(fileList);
    for iFile = 1:nFile
        clear rez ops
        if exist(fileList{iFile}, 'file') == 2
            [~, fileName] = fileparts(fileList{iFile});
            disp([newline, '================    ', fileName, '    ================', newline]);
            
            % load preset
            eval(configFileName, ';');
            filesplits = strsplit(ops.chanMap, '\');
            ops.chanMap = fullfile(kilosortDirectory, 'configFiles', filesplits{end});
            ops.trange = [0, Inf];
            ops.wd = workingDirectory;
            ops.fproc = fullfile(workingDirectory, 'temp_wh.dat');

            meta = readMeta(fileList{iFile});
            ops = setOps(ops, fileList{iFile}, excludedChannel{iFile}, meta, kilosortDirectory);
      
            % recluster policy check
            doSort = true;
            fname = fullfile(ops.saveDir, [fileName, '_rez.mat']);
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

                disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', saving data to ', fname]);
                save(fname, 'rez', '-v7.3');
            end
            
            if makePhy
                phyName = fullfile(ops.saveDir, 'params.py');
                if exist(phyName, 'file') == 2
                    disp([phyName, ' already exists.']);
                    if strcmp(recluster, 'ask')
                        cmd = input('Remake phy file? [y/N]: ', 's');
                        if isempty(cmd) || lower(cmd(1)) ~= 'y'
                            continue;
                        end
                    elseif strcmp(recluster, 'no')
                        continue;
                    end
                end
                    
                disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', saving data to phy format']);
                if exist(fname, 'var') ~= 1
                    load(fname, 'rez');
                end
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
