function viewRaw(binFile)
    %VIEWRAW Opens raw datafile
    
    S.timeRange = [0, 0.5]; % seconds
    S.scale = 8; % 8 y-axis tick / 1 mV = 0.125 mV / tick
    
    if nargin == 0
        disp('Choose file.');
        return;
    end
    if exist(binFile, 'file') ~= 2
        fprintf('.bin file does not exist: %s\n', binFile);
        return;
    end

    % get file infomation
    meta = readOption(binFile);
    dataInfo = dir(binFile);
    nByte = dataInfo.bytes;
    
    if nByte == meta.fileSizeBytes
        disp('Correct file size');
    else
        disp('Corrupted file');
        return
    end
    
    if strcmp(meta.typeThis, 'imec')
        S.gain = 500;
        S.millivoltPerBit = single(((meta.imAiRangeMax-meta.imAiRangeMin) / S.gain * 1000) / 2^10);
        S.nChannel = meta.nSavedChans;
        S.nSample = meta.fileSizeBytes / (2 * S.nChannel);
        S.nLoadSample = min(diff(S.timeRange) * meta.imSampRate, S.nSample);
    else
        S.gain = meta.niMNGain;
        S.millivoltPerBit = single(((meta.niAiRangeMax-meta.niAiRangeMin) / S.gain * 1000) / 2^10);
        S.nChannel = meta.nSavedChans;
        S.nSample = meta.fileSizeBytes / (2 * S.nChannel);
        S.nLoadSample = min(diff(S.timeRange) * meta.niSampRate, S.nSample);
    end
    S.nLoadByte = 2 * S.nChannel * S.nLoadSample;
    S.nBin = floor(S.nSample / S.nLoadSample);
    S.iBin = 1;
    S.pBin = 0;
     
    
    % open file
    fprintf('Opening %s\n', binFile);
    S.fid = fopen(binFile, 'r');
    
    
    % make figure
    hF = figure('Units', 'normalized', 'Position', [0.02, 0.05, 0.5, 0.85], ...
        'NumberTitle', 'off');
    S.hA = axes(hF, 'Position', [0.05, 0.05, 0.9, 0.9], 'XLimMode', 'manual', 'YLimMode', 'manual', ...
        'XLim', S.timeRange, 'XTick', S.timeRange(1):diff(S.timeRange)/10:S.timeRange(2), 'YLim', [0 S.nChannel], 'YTick', 1:S.nChannel-1);
    hold(S.hA, 'on');
    S.hP = line(S.hA, repmat(diff(S.timeRange)*(0:S.nLoadSample-1)'/S.nLoadSample, S.nChannel-1, 1), NaN((S.nChannel-1) * S.nLoadSample, 1), 'Color', [0.5, 0.5, 0.5], 'LineWidth', 0.5);
    S.help = { ...
    'Left/Right: change time', ...
    '[J]ump T', ...
    '[Home/End]: go to beginning/end of file', ...
    '---------', ...
    'Up/Down: change scale', ...
    'Zoom: Mouse wheel', ...
    'Pan: hold down the wheel and drag', ...
    };
       
    set(hF, 'UserData', S, ...
        'KeyPressFcn', @keyPressFcn, ...
        'CloseRequestFcn', @closeRequestFcn);   
    mouse_figure(hF);
    drawData(hF);
end


function meta = readOption(binFile)
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
            meta.(tag) = C{2}{i};
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


function hF = drawData(hF)
    S = hF.UserData;
    
    if S.pBin ~= S.iBin
        fseek(S.fid, (S.iBin-1)*S.nLoadByte, 'bof');
        S.rawData = fread(S.fid, [S.nChannel, S.nLoadSample], 'int16');
        S.rawData = S.rawData - mean(S.rawData, 2);
        S.pBin = S.iBin;
        set(S.hA, 'XTickLabel', (S.timeRange(1):diff(S.timeRange)/10:S.timeRange(2)) + (S.iBin-1) * diff(S.timeRange));
    end
    
    hF.Name = sprintf('[H]elp; [Up/Down]:Scale(%0.1f uV); [Left/Right]:Time; [J]ump Time; [R]eset', 1000/S.scale);
    yTemp = (S.rawData(1:end-1, :) * S.millivoltPerBit * S.scale + ...
        (1:S.nChannel-1)' * ones(1, S.nLoadSample))';
    yTemp(end, :) = NaN;
    
    S.hP.YData = yTemp(:);
    
    hF.UserData = S;
end


function keyPressFcn(hF, event)
    S = hF.UserData;
    switch lower(event.Key)
        case 'h'
            uiwait(msgbox(S.help, 'modal'));
        case 'uparrow'
            S.scale = S.scale * 2;
        case 'downarrow'
            S.scale = S.scale / 2;
        case 'leftarrow'
            if S.iBin > 1
                S.iBin = S.iBin - 1;
            end
        case 'rightarrow'
            if S.iBin < S.nBin
                S.iBin = S.iBin + 1;
            end
        case 'home'
            S.iBin = 1;
        case 'end'
            S.iBin = S.nBin;
        case 'j'
            cmd = inputdlg('Go to time (s)', 'Jump to time', 1, {'0'});
            iTime = floor(str2double(cmd{1}) / diff(S.timeRange)) + 1;
            if iTime < 1
                S.iBin = 1;
            elseif iTime > S.nBin
                S.iBin = S.nBin;
            end
        case 'r' % reset view
            set(S.hA, 'XLim', S.timeRange);
            set(S.hA, 'YLim', [0, S.nChannel]);
    end
    hF.UserData = S;
    drawData(hF);
end


function closeRequestFcn(hF, ~)
    try
        if ~ishandle(hF); return; end
        if ~isvalid(hF); return; end
        S = hF.UserData;
        fclose(S.fid);
        try
            delete(hF)
        end
    catch ex
        disp(ex.message);
    end
end