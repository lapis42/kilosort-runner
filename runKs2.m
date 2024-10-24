function runKs2(startingDirectory)
    %RUNKS2 Batch sorting using Kilosort2
    %
    % This function performs batch sorting of neural data using Kilosort2.
    % 
    % Prerequisites:
    %   - Kilosort2 directory should be added to the MATLAB path
    %   - npy-matlab directory should be added to the MATLAB path
    %
    % Usage:
    %   runKs2(startingDirectory)
    %
    % Input:
    %   startingDirectory - (optional) The directory to start searching for files.
    %                       If not provided, the current directory is used.
    %
    % Note: Ensure that Kilosort2 and npy-matlab are properly installed and
    % their directories are added to the MATLAB path before running this function.
    
    % Set default values and validate input
    if nargin < 1 || isempty(startingDirectory) || ~isfolder(startingDirectory)
        startingDirectory = pwd;
    end

    % Constants
    WORKING_DIR = fullfile(startingDirectory, 'temp');
    RECLUSTER_POLICY = 'ask';
    CHECK_SUBDIRS = true;

    % Validate dependencies
    if ~exist('kilosort.m', 'file')
        error('Kilosort.m file not found in the MATLAB path. Please add Kilosort2 including subfolders to the MATLAB path.');
    end
    if ~exist('preprocessDataSub.m', 'file')
        error('preprocessDataSub.m file not found in the MATLAB path. Please add Kilosort2 including subfolders to the MATLAB path.');
    end
    if ~exist('writeNPY.m', 'file')
        error('npy-matlab directory not found in the MATLAB path. Please add npy-matlab to the MATLAB path.');
    end

    % Display start message
    disp('*****************************************');
    disp('******** Batch Kilosort2 sorting ********');
    disp('*****************************************');

    % Choose files to sort
    [fileList, excludedChannel] = util.fileSelector(startingDirectory, CHECK_SUBDIRS, '*.ap.bin');
    if isempty(fileList)
        disp('No files selected. Exiting...');
        return;
    end

    % Ensure working directory exists
    if ~isfolder(WORKING_DIR)
        mkdir(WORKING_DIR);
    end

    % Process each file
    for iFile = 1:numel(fileList)
        filePath = fileList{iFile};
        if ~isfile(filePath)
            warning('File not found: %s', filePath);
            continue;
        end

        [~, fileName] = fileparts(filePath);
        disp([newline, '================    ', fileName, '    ================', newline]);

        ops = setOps(WORKING_DIR, filePath, excludedChannel{iFile});

        paramsFile = fullfile(ops.saveDir, 'params.py');
        if ~isfile(paramsFile)
            doRecluster = true;
        else
            disp([paramsFile, ' already exists.']);
            switch RECLUSTER_POLICY
                case 'yes'
                    doRecluster = true;
                case 'no'
                    doRecluster = false;
                case 'ask'
                    cmd = input('Re-cluster this file? [y/N]: ', 's');
                    doRecluster = ~isempty(cmd) && lower(cmd(1)) == 'y';
                otherwise
                    error('Invalid recluster policy: %s', RECLUSTER_POLICY);
            end
        end

        if doRecluster
            runKilosort(ops);
        else
            disp('Skipping clustering for this file.');
        end

        disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', done']);
        close all;
    end
end

function runKilosort(ops)
    stages = {
        'preprocessing', @preprocessDataSub,
        'preclustering', @clusterSingleBatches,
        'optimization', @learnAndSolve8b,
        'merge', @(rez) find_merges(rez, 1),
        'split by svd', @(rez) splitAllClusters(rez, 1),
        'split by amplitudes', @(rez) splitAllClusters(rez, 0),
        'setting cutoff', @set_cutoff,
        'saving data to phy format', @(rez) rezToPhy(rez, ops.saveDir),
        'saving data as a mat file', @(rez) saveRezMat(rez, ops.saveDir)
    };

    rez = ops;
    for i = 1:size(stages, 1)
        [stageName, stageFunc] = stages{i, :};
        disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', ', stageName]);
        if i < 8
            rez = stageFunc(rez);
        else
            stageFunc(rez);
        end
    end
end

function rez = saveRezMat(rez, saveDir)
    rez.cProj = [];
    rez.cProjPC = [];
    save(fullfile(saveDir, 'rez2.mat'), 'rez', '-v7.3');
end

function ops = setOps(workingDirectory, fileName, excludedChannel)
    ops = getDefaultOps(workingDirectory);

    meta = readMeta(fileName);
    [ops.chanMap, ops.fs] = getChannelMap(meta, excludedChannel);
    
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

function ops = getDefaultOps(workingDirectory)
    ops = struct();
    
    % Channel map and sampling rate
    ops.fs = 30000;
    
    % Filtering and channel quality
    ops.fshigh = 150;
    ops.minfr_goodchannels = 0.1;
    
    % Spike detection and clustering thresholds
    ops.Th = [10 4];
    ops.lam = 10;
    ops.AUCsplit = 0.9;
    ops.minFR = 1/50;
    ops.ThPre = 8;
    ops.spkTh = -6;
    
    % Temporal parameters
    ops.momentum = [20 400];
    ops.sigmaMask = 30;
    ops.nskip = 25;
    
    % GPU and memory settings (do not change)
    ops.GPU = 1;
    ops.nfilt_factor = 4;
    ops.ntbuff = 64;
    ops.NT = 64*1024 + ops.ntbuff;
    ops.whiteningRange = 32;
    ops.nSkipCov = 25;
    ops.scaleproc = 200;
    ops.nPCs = 3;
    ops.useRAM = 0;
    
    % Batch reordering
    ops.reorder = 1;

    % Other parameters
    ops.trange = [0, Inf];
    ops.wd = workingDirectory;
    ops.fproc = fullfile(workingDirectory, 'temp_wh.dat');
end

function [cm, fs] = getChannelMap(meta, excludedChannel)
    electrodes = meta.snsGeomMap;
    shank_spacing = str2double(meta.snsGeomMap_header{3});
    
    shank = electrodes(:, 1);
    xcoords = electrodes(:, 2) + shank * shank_spacing;
    ycoords = electrodes(:, 3);
    connected = electrodes(:, 4) == 1;
    connected(excludedChannel) = false;
    
    channel_map = meta.snsChanMap(:, 2);
    chanMap0ind = channel_map(connected);
    chanMap = chanMap0ind + 1;
    kcoords = shank(connected) + 1;

    cm = struct('chanMap', chanMap, ...
                'chanMap0ind', chanMap0ind, ...
                'xcoords', xcoords(connected), ...
                'ycoords', ycoords(connected), ...
                'kcoords', kcoords);
    
    fs = meta.imSampRate;
end