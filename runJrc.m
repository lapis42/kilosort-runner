function runJrc()
    %RUNJRC Executes JRCLUST program

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%                       USER PRESET START                         %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % default data directory
    startingDirectory = 'E:';
    
    % JRClust location
    jrcDirectory = 'C:\Users\kimd11\OneDrive - Howard Hughes Medical Institute\src\JRClust';
    
    % Redo policy: choose whether do clustering if output file alreay exists, {'yes', 'no', 'ask'}
    recluster = 'no';
    
    % Check sub-directories to find files
    checkSubDir = true;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%                        USER PRESET END                          %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    disp('***************************************');
    disp('******** Batch JRClust sorting ********');
    disp('***************************************');

    %% 1. Choose files to sort
    [fileList, excludedChannel] = fileSelector(startingDirectory, checkSubDir);
    if isempty(fileList); return; end
    addpath(jrcDirectory);
    

    %% 2. Run JRC to make prm file and do spike sorting
    nFile = length(fileList);
    [prmFile, matFile] = deal(cell(nFile, 1));
    sortYes = false;
    for iFile = 1:nFile
        cd(fileparts(fileList{iFile}));
        
        option = readOption(fileList{iFile});
        prmFile{iFile} = replace(fileList{iFile}, '.bin', ['_imec3_opt', num2str(option,1),'.prm']);
        matFile{iFile} = replace(prmFile{iFile}, '.prm', '_jrc.mat');

        % make prm
        if exist(prmFile{iFile}, 'file') ~= 2
            jrc('makeprm', fileList{iFile});
        end
        
        % exclude channel
        P = loadParams(prmFile{iFile});
        if isempty(P); continue; end
        P.viSiteZero = excludedChannel{iFile};
        exportParams(prmFile{iFile}, prmFile{iFile}, 0);

        % detect and sort
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
        
        jrc clear; % clear used memory
        jrc('spikesort', prmFile{iFile});
        sortYes = true;
    end

    if sortYes
        slack('runJrc done'); % DK's notification function...
    end

    %% 3. After automated spike sorting, do manual spike sorting
    if length(prmFile) > 1
        iFile = listdlg('PromptString', 'Select a file for manual clustering', ...
            'SelectionMode', 'single', ...
            'ListSize', [400, 200], ...
            'ListString', prmFile);
    else
        iFile = 1;
    end

    if ~isempty(iFile)
        jrc clear;
        jrc('manual', prmFile{iFile});
    end
end


function option = readOption(binFile)
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
    option = meta.imProbeOpt(1);
end