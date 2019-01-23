function [fileList, excludedChannel] = fileSelector(startingDirectory, checkSubDir, fileType)
    if nargin < 1 || exist(startingDirectory, 'dir') ~= 7
        startingDirectory = pwd;
    end
    if nargin < 2
        checkSubDir = true;
    end    
    if nargin < 3
        fileType = '*.*.bin';
    end
    
    % first search starting directory
    fileList = {};
    excludedChannel = {};
    if checkSubDir
        subpath = strsplit(genpath(startingDirectory), ';');
        isOutDir = cellfun(@(x) contains(x, {'.'}), subpath); % I remove folder with dots.
        subpath(isOutDir) = [];
        nSub = length(subpath) - 1; % the last data is empty
        files = [];
        for iS = 1:nSub
            files = [files; dir(fullfile(subpath{iS}, fileType))];
        end
    else                         
        files = dir(fullfile(startingDirectory, fileType));
    end
    
    % exclude '*.lf.bin'
    isLFP = contains({files.name}, '.lf.bin');
    files(isLFP) = [];

    nFile = length(files);
    if nFile > 0
        filepath = cellfun(@fullfile, {files.folder}, {files.name}, 'UniformOutput', false);

        excludedChannel = [excludedChannel, cell(1, nFile)];
        [fileList, iA] = unique([fileList, filepath]);
        excludedChannel = excludedChannel(iA);
    end
              
    exit = 0;
    while ~exit
        if ~isempty(fileList)
            fprintf('\n');
            nFile = length(fileList);
            for iF = 1:nFile
                nS = length(fileList{iF});
                if nS <= 60
                    fprintf('%d: %60s   ', iF, fileList{iF});
                else
                    fprintf('%d: ...%57s   ', iF, fileList{iF}(end-56:end));
                end
                fprintf('%5d', excludedChannel{iF});
                fprintf('\n');
            end
        end
        
        disp([newline, '[1] Add folder']);
        disp('[2] Add file');
        disp('[3] Delete file selection');
        disp('[4] Set channel to exclude');
        disp('[5] View raw data');
        disp('[s] Start sorting');
        disp(['[q] Quit', newline]);
        
        cmd = input('Select menu: ', 's');

        switch lower(cmd)
            case '1'
                path = uigetdir(startingDirectory, 'Select folder');
                if ischar(path)
                    if checkSubDir
                        subpath = strsplit(genpath(path), ';');
                        isOutDir = cellfun(@(x) contains(x, '.'), subpath); % I remove folder with dots.
                        subpath(isOutDir) = [];
                        nSub = length(subpath) - 1; % the last data is empty
                        files = [];
                        for iS = 1:nSub
                            files = [files; dir(fullfile(subpath{iS}, fileType))];
                        end
                    else                         
                        files = dir(fullfile(path, fileType));
                    end
                    
                    nFile = length(files);

                    if nFile==0; continue; end
                    filepath = cellfun(@fullfile, {files.folder}, {files.name}, 'UniformOutput', false);

                    excludedChannel = [excludedChannel, cell(1, nFile)];
                    [fileList, iA] = unique([fileList, filepath]);
                    excludedChannel = excludedChannel(iA);
                end
            case '2'
                [file, path] = uigetfile(fullfile(startingDirectory, fileType), ...
                    'Select one or more files', ...
                    'MultiSelect', 'on');
                if ischar(file)
                    filepath = {fullfile(path, file)};
                elseif iscell(file)
                    filepath = cellfun(@(x) fullfile(path, x), file, 'UniformOutput', false);
                else
                    continue;
                end
                
                excludedChannel = [excludedChannel, cell(1)];
                [fileList, iA] = unique([fileList, filepath]);
                excludedChannel = excludedChannel(iA);
            case '3'
                id = input('Choose file index to delete (ex. 1 or [1, 2, 3]. 0 to choose all. Enter to cancel): ');
                if isempty(id)
                    continue;
                elseif id(1) == 0
                    fileList = [];
                    excludedChannel = [];
                else
                    inIndex = ismember(id, 1:length(fileList));
                    id = id(inIndex);
                    fileList(id) = [];
                    excludedChannel(id) = [];
                end
            case '4'
                id = input('Choose file index to edit channel to exclude (0 to choose all. Enter to cancel): ');
                if isempty(id)
                    continue;
                elseif id(1) == 0
                    ch = input('Type channel to exclude (ex. [200, 375]. Enter to cancel): ');
                    if isempty(ch); continue; end
                    inChannel = ismember(ch, 1:384);
                    nFile = length(fileList);
                    excludedChannel = repmat({sort(ch(inChannel))}, nFile, 1);
                else
                    inIndex = ismember(id, 1:length(fileList));
                    if sum(inIndex) > 0
                        ch = input('Type channel to exclude (ex. [200, 375]. Enter to cancel): ');
                        if isempty(ch); continue; end
                        inChannel = ismember(ch, 1:384);
                       
                        for iCh = id(inIndex)
                            excludedChannel{iCh} = sort(ch(inChannel));
                        end
                    end
                end
            case '5'
                id = input('Choose file index to view raw data (Enter to cancel): ');
                if isempty(id); continue; end
                inIndex = ismember(id(1), 1:length(fileList));
                if inIndex
                    viewRaw(fileList{id(1)});
                end
            case {'s', 'y'}
                exit = 1;
            case {'q', 'c'}
                fileList = {};
                excludedChannel = {};
                exit = 1;
        end
    end
end