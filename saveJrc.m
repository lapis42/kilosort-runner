function saveJrc(jrcFileList)
%SAVEJRC Reads JRCLUST spike data and save to data mat file
%   SAVEJRC(JF) reads JF spike data and save. Units are saved in seconds.

% default data directory
DEFAULT_DATA_FOLDER = 'E:';

%% 1. Check whether there's file in default directory. If not, pop up the window to select manually
if nargin < 1 || isempty(jrcFileList)
    jrcList = dir(fullfile(DEFAULT_DATA_FOLDER, '*_jrc.mat'));
    
    if isempty(jrcList)
        dataPath = uigetdir(DEFAULT_DATA_FOLDER);
        if ~ischar(dataPath); return; end
        jrcList = dir(fullfile(dataPath, '*_jrc.mat'));
    else
        dataPath = DEFAULT_DATA_FOLDER;
    end
    
    nFile = length(jrcList);
    jrcFile = {};
    for iF = 1:nFile
        jrcFile = [jrcFile; {fullfile(dataPath, jrcList(iF).name)}];
    end
else
    if ischar(jrcFileList)
        jrcFileList = {jrcFileList};
    elseif ~iscell(jrcFileList)
        return;
    end
    
    nFile = length(jrcFileList);
    jrcFile = {};
    for iF = 1:nFile
        fileType = exist(jrcFileList{iF}, 'file');
        if fileType==2
            jrcFile = [jrcFile; jrcFileList{iF}];
        elseif fileType==7
            jrcList = dir(fullfile(jrcFileList{iF}, '*_jrc.mat'));
            nL = length(jrcList);
            for iL = 1:nL
                jrcFile = [jrcFile; {fullfile(jrcFileList{iF}, jrcList(iL).name)}];
            end
        end
    end
end

%% 2. Save JRC spike data into *_data.mat file
nFile = length(jrcFile);
for iF = 1:nFile
    clearvars S_clu viTime_spk Spike
    load(jrcFile{iF}, 'S_clu', 'viTime_spk');
    
    unitNo = find(strcmp(S_clu.csNote_clu, 'single')); % use units with 'single' annotation
    
    if isempty(unitNo)
        continue;
    end
    
    Spike = struct();
    Spike.nUnit = length(unitNo);
    Spike.time = cell(Spike.nUnit, 1);
    for iUnit = 1:Spike.nUnit
        Spike.time{iUnit} = double(viTime_spk(S_clu.cviSpk_clu{unitNo(iUnit)}))/30000; % in second
    end
    
    Spike.posX = S_clu.vrPosX_clu(unitNo);
    Spike.posY = S_clu.vrPosY_clu(unitNo);
    Spike.site = S_clu.viSite_clu(unitNo)'; % maximum amplitude channel number
    
    Spike.Vmin = S_clu.vrVmin_uv_clu(unitNo);
    Spike.Vpp = S_clu.vrVpp_uv_clu(unitNo);
    
    % waveform
    option = str2double(jrcFile{iF}(regexp(jrcFile{iF}, 'opt\d')+3));
    if option == 3
        referenceSite = [37 76 113 152 189 228 265 304 341 380];
        nChannel = 384;
    elseif option == 4
        referenceSite = [37 76 113 152 189 228 265];
        nChannel = 276;
    end
    probeMap = zeros(nChannel, 2);
    viHalf = 0:(nChannel / 2 - 1);
    probeMap(1:2:end, 2) = viHalf * 20;
    probeMap(2:2:end, 2) = probeMap(1:2:end, 2);
    probeMap(1:4:end, 1) = 16;
    probeMap(2:4:end, 1) = 48;
    probeMap(3:4:end, 1) = 0;
    probeMap(4:4:end, 1) = 32;
    probeMap(referenceSite, :) = [];
    
    Spike.waveformSite = cell(Spike.nUnit, 1);
    Spike.waveform = zeros(32, 14, Spike.nUnit);
    for iU = 1:Spike.nUnit
        [~, channelIndex] = sort((probeMap(:, 1) - probeMap(Spike.site(iU), 1)).^2 + ...
            (probeMap(:, 2) - probeMap(Spike.site(iU), 2)).^2);
        Spike.waveformSite{iU} = probeMap(channelIndex(1:14), :);
        Spike.waveform(:, :, iU) = S_clu.tmrWav_spk_clu(:, channelIndex(1:14), unitNo(iU));
    end
    
    Spike.snr = S_clu.vrSnr_clu(unitNo);
    Spike.isolationDistance = S_clu.vrIsoDist_clu(unitNo);
    Spike.LRatio = S_clu.vrLRatio_clu(unitNo);
    Spike.isiRatio = S_clu.vrIsiRatio_clu(unitNo);
    
    dataFile = replace(jrcFile{iF}, '_jrc.mat', '_data.mat');
    if exist(dataFile, 'file')==2
        save(dataFile, 'Spike', '-append');
    else
        save(dataFile, 'Spike');
    end
end