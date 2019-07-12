function runKs(startingDirectory, probe_type)
    %RUNKS Batch sorting using Kilosort2
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%                       USER PRESET START                         %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Starting directory: directory to start finding files.
    if nargin < 1 || exist(startingDirectory, 'dir')~=7
        if strcmp(computer, 'PCWIN64') % windows
            startingDirectory = 'E:\';
        elseif strcmp(computer, 'GLNXA64') % linux
            startingDirectory = '/mnt/data/';
        end
    end
    
    if nargin < 2
        probe_type = 'imec';
    end
    
    % Working directory: directory for saving temporary data. Choose fast drive like SSD.
    workingDirectory = fullfile(startingDirectory, 'temp'); 
    
    % Kilosort location
    if strcmp(computer, 'PCWIN64') % windows
        DROPBOX = fullfile('C:\\Users\', getenv('USERNAME'), 'Dropbox');
    elseif strcmp(computer, 'GLNXA64') % linux
        DROPBOX = '/home/kimd/Dropbox';
    end
    kilosortDirectory = fullfile(DROPBOX, 'src', 'Kilosort2');
    
    % Redo policy: choose whether do clustering if output file alreay exists, {'yes', 'no', 'ask'}
    recluster = 'no';
    
    % Make phy format file
    makePhy = true;
    
    % npy plugin location
    npyDirectory = fullfile(DROPBOX, 'src', 'npy-matlab', 'npy-matlab');
    addpath(npyDirectory);
    
    % Check sub-directories to find files
    checkSubDir = true;
    
    % Config file name
    if strcmpi(probe_type, 'nidq')
        fileType = '*.nidq.bin';  
    else
        fileType = '*.imec.ap.bin';  
    end
    
    configFileNameImec = 'configFile384';
%     configFileNameNidq = 'configFilehh3x2'; % Janelia acute 64-channel HH-3 probe (2x64)
%     configFileNameNidq = 'configFilehh2'; % Janelia acute 64-channel HH-2 probe (2x32)
    configFileNameNidq = 'configFilehh3'; % Janelia acute 64-channel HH-3 probe (1x64)

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
            meta = readMeta(fileList{iFile});
            if strcmp(meta.typeThis, 'imec') && strcmp(meta.nSavedChans, '385')
                eval([configFileNameImec, ';']);
            elseif strcmp(meta.typeThis, 'nidq')
                eval([configFileNameNidq, ';']);
            end
            ops.trange = [0, Inf];
            ops.wd = workingDirectory;
            ops.fproc = fullfile(workingDirectory, 'temp_wh.dat');
            ops = setOps(ops, fileList{iFile}, excludedChannel{iFile});
      
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
    try
        slack('runKs done');
    end
end

function ops = setOps(ops, fileName, excludedChannel)
    load(ops.chanMap);
    connected(excludedChannel) = false;

    cm = struct();
    cm.chanMap = chanMap(connected);
    cm.xcoords = xcoords(connected);
    cm.ycoords = ycoords(connected);
    ops.chanMap = cm;
    
    nChannel = length(connected);
    if nChannel == 384
        ops.NchanTOT = 385;
    elseif nChannel == 64 || nChannel == 128
        ops.NchanTOT = nChannel + 32;
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
        error('No meta file exists.');
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
