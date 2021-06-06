function Spike = saveKs(foldername)

    if nargin < 1 || isempty(foldername)
        foldername = fileparts(pwd);
    end        

    folderList = util.fileSelector(foldername, true, 'cluster_group.tsv');

    if isempty(folderList)
        return
    end

    nFolder = length(folderList);
    for iF = 1:nFolder
        cPath = fileparts(folderList{iF});
        if exist(cPath, 'dir') == 0
            continue
        end

        %% spike time
        spikeTime = readNPY(fullfile(cPath, 'spike_times.npy'));
        spikeCluster = readNPY(fullfile(cPath, 'spike_clusters.npy'));
        validCluster = clusterGroup(fullfile(cPath, 'cluster_group.tsv'));
        
        Spike = struct();
        Spike.P = util.loadParams(cPath);
        Spike.nUnit = length(validCluster);
        Spike.time = cell(Spike.nUnit, 1);
        for iU = 1:Spike.nUnit
            Spike.time{iU} = double(spikeTime(spikeCluster == validCluster(iU))) / Spike.P.sample_rate;
        end
        
        
        %% spike amplitude
        % please make sure that the 'npy-matlab' package is installed.
        template = readNPY(fullfile(cPath, 'templates.npy')); % 564x82x373 single
        winv = readNPY(fullfile(cPath, 'whitening_mat_inv.npy')); % 373x373 double
        amplitude = readNPY(fullfile(cPath, 'amplitudes.npy')); % 5256134x1 double
        coordinate = readNPY(fullfile(cPath, 'channel_positions.npy')); % 373x2 double
        channelMap = readNPY(fullfile(cPath, 'channel_map.npy')); % 373x1 int32
        spikeTemplate = readNPY(fullfile(cPath, 'spike_templates.npy')); % 5256134x1 uint32
        
        % unwhiten amplitude
        nT = size(template, 1);
        tempUnW = zeros(size(template)); % 564x82x373 double
        for iT = 1:nT
            tempUnW(iT, :, :) = squeeze(template(iT, :, :)) * winv;
        end
        
        tempChanVpp = squeeze(max(tempUnW, [], 2)) - squeeze(min(tempUnW, [], 2)); % 564x373 double
        tempChanVmin = squeeze(min(tempUnW, [], 2)); % 564x373 double
        [tempVppUnscaled, maxChannel] = max(tempChanVpp, [], 2); % 564x1 double, 564x1 double
        
        tempVminUnscaled = zeros(nT, 1); % 564x1 double
        for iT = 1:nT
            tempVminUnscaled(iT) = tempChanVmin(iT, maxChannel(iT));
        end
        
        waveTemp = channelMap(maxChannel) + 1; % 564x1 int32
        
        Spike.waveform = zeros(Spike.nUnit, size(template, 2), size(template, 3)); % 240x82x373 double
        [Spike.Vmin, Spike.Vpp, Spike.posX, Spike.posY, Spike.waveformSite, Spike.maxChannel] = deal(zeros(Spike.nUnit, 1)); % 240x1 double
        for iU = 1:Spike.nUnit
            mainTemplate = mode(spikeTemplate(spikeCluster == validCluster(iU))); % scalar, zeroindexing
            meanAmplitude = mean(amplitude(spikeCluster == validCluster(iU))); % scalar 
            
            Spike.waveform(iU, :, :) = tempUnW(mainTemplate + 1, :, :) * meanAmplitude;
            Spike.waveformSite(iU) = maxChannel(mainTemplate + 1);
            Spike.maxChannel(iU) = waveTemp(mainTemplate + 1);
            Spike.posX(iU) = coordinate(maxChannel(mainTemplate + 1), 1);
            Spike.posY(iU) = coordinate(maxChannel(mainTemplate + 1), 2);
            Spike.Vmin(iU) = tempVminUnscaled(mainTemplate + 1) * meanAmplitude;
            Spike.Vpp(iU) = tempVppUnscaled(mainTemplate + 1) * meanAmplitude;
        end
        
        % save file
        cPath_split = strsplit(cPath, filesep);
        filename = fullfile(cPath, [cPath_split{end}, '_data.mat']);
        save(filename, 'Spike');
    end
end


function validCluster = clusterGroup(filename)
    C = tdfread(filename);
    inCluster = strcmp(cellstr(C.group), 'good');
    validCluster = C.cluster_id(inCluster);
end
    
    
