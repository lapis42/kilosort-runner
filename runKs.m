function runKs()
    %RUNKS Batch sorting using Kilosort2
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%                       USER PRESET START                         %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Starting directory: directory to start finding files.
    startingDirectory = 'E:'; 
    
    % Working directory: directory for saving temporary data. Choose fast drive like SSD.
    workingDirectory = 'E:\temp'; 
    
    % Kilosort location
    kilosortDirectory = 'C:\Users\kimd11\OneDrive - Howard Hughes Medical Institute\src\Kilosort2';
    
    % Redo policy: choose whether do clustering if output file alreay exists, {'yes', 'no', 'ask'}
    recluster = 'no';
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%                        USER PRESET END                          %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    

    %% Choose files to sort
    [fileList, excludedChannel] = fileSelector(startingDirectory);
    if isempty(fileList); return; end

    
    %% Preparation
    % add path kilosort directory (excluding git directory with '.')
    ksSubDir = strsplit(genpath(kilosortDirectory), ';');
    isGitDir = cellfun(@(x) ismember('.', x), ksSubDir);
    addpath(strjoin(ksSubDir(~isGitDir), ';'));
    
    % make working directory
    if exist(workingDirectory, 'dir')~=7
        mkdir(workingDirectory);
    end
    
    % load preset
    configFile384;
    ops.trange = [0, Inf];
    ops.wd = workingDirectory;
    ops.fproc = fullfile(workingDirectory, 'temp_wh.dat');
    
    
    %% run
    nFile = length(fileList);
    for iFile = 1:nFile
        if exist(fileList{iFile}, 'file') == 2
            [~, fileName] = fileparts(fileList{iFile});
            disp([newline, '================    ', fileName, '    ================', newline]);
            ops = setOps(ops, fileList{iFile}, excludedChannel{iFile});
      
            % recluster policy check
            fname = fullfile(ops.saveDir, [fileName, '_rez.mat']);
            if exist(fname, 'file')==2
                disp([fname, ' already exists.']);
                if strcmp(recluster, 'ask')
                    cmd = input('Re-cluster this file? [y/N]: ', 's');
                    if isempty(cmd) || lower(cmd(1)) ~= 'y'
                        continue;
                    end
                elseif strcmp(recluster, 'no')
                    continue;
                end
            end

            % main run
            disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', preprocessing']);
            rez = preprocessDataSub(ops);

            disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', preclustering']);
            rez = clusterSingleBatches(rez);

            disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', optimization']);
            rez = learnAndSolve8b(rez);

            disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', spilt']);
            rez = splitAllClusters(rez);

            disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', saving data to ', fname]);
            fname = fullfile(ops.saveDir, [fileName, '_rez.mat']);
            save(fname, 'rez', '-v7.3');
            
%             disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', saving data to phy format']);
%             filenamesplit = strsplit(filename, '.');
%             phySaveDir = fullfile(ops.saveDir, filenamesplit{1});
%             if exist(phySaveDir, 'dir')~=7
%                 mkdir(phySaveDir);
%             end
%             rezToPhy(rez, phySaveDir);

            disp(['==== ', datestr(datetime, 'yyyy/mm/dd HH:MM:ss'), ', done']);
            close all;
        end
    end
end

function ops = setOps(ops, fileName, excludedChannel);
    load('neuropixPhase3A_kilosortChanMap.mat');
    connected(excludedChannel) = false;

    cm = struct();
    cm.chanMap = chanMap(connected);
    cm.xcoords = xcoords(connected);
    cm.ycoords = ycoords(connected);
    ops.chanMap = cm;
    ops.NchanTOT = 385;
    
    ops.fbinary = fileName;
    fileDir = fileparts(fileName);
    ops.rootZ = fileDir;
    ops.saveDir = fileDir;
end