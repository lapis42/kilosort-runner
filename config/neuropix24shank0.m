% Neuropixel 2.0 design
%
% Shank 0: Bank 0 (384) - Bank 1 (384) - Bank 2 (384) - Bank 3 (128)
% Shank 1: Bank 0 (384) - Bank 1 (384) - Bank 2 (384) - Bank 3 (128)
% Shank 2: Bank 0 (384) - Bank 1 (384) - Bank 2 (384) - Bank 3 (128)
% Shank 4: Bank 0 (384) - Bank 1 (384) - Bank 2 (384) - Bank 3 (128)
%
% Electrode per shank: 0-1279
% Reference electrode: 127, 511, 895, 1279 per shank
%
% Shank 0 Bank 0: Block 0 2 4 6 5 7 1 3
% Shank 1 Bank 0: Block 1 3 5 7 4 6 0 2
% Shank 2 Bank 0: Block 4 6 0 2 1 3 5 7
% Shank 3 Bank 0: Block 5 7 1 3 0 2 4 6
%
% Block 0: Channel 0-47 (360 um)
%  Channel (0)-15um-(2)    (4) ...  (46)
%           |
%           32 um
%           |
%          (1)      (3)    (5) ...  (47)
% Block 1: Channel 48-95
% Block 2: Channel 96-143
% Block 3: Channel 144-191
% Block 4: Channel 192-239
% Block 5: Channel 240-287
% Block 6: Channel 288-335
% Block 7: Channel 336-387

% Parameters
% patternType = 0, all sites on "shankChoice" starting from "botRow", 0-448
%               (1 shank, 8 blocks, 384 channels per shank, 2.88 mm)
% patternType = 1, horizontal stripe of 96-channel height across all four
%                   shanks starting from "botRow", valid values = 0-592
%               (4 shanks, 2 blocks, 96 channels per shank, 0.72 mm)
patternType = 0; 
shankChoice = 0;
botRow = 0;

fn = ['neuropix24shank', num2str(shankChoice), '.mat'];

if exist(fn, 'file') == 0

    if patternType == 0
        blockSelect = repmat(shankChoice+1, 1, 8);
    elseif patternType == 1
        blockSelect = [1, 2, 1, 2, 3, 4, 3, 4];
    end

    Nchannels = 384;
    connected = true(Nchannels, 1);
    chanMap   = 1:Nchannels;
    chanMap0ind = chanMap - 1;
    kcoords   = ones(Nchannels,1); % grouping of channels (i.e. tetrode groups)

    blockMap = zeros(4, 8);
    blockMap(1, :) = [0, 2, 4, 6, 5, 7, 1, 3];
    blockMap(2, :) = [1, 3, 5, 7, 4, 6, 0, 2];
    blockMap(3, :) = [4, 6, 0, 2, 1, 3, 5, 7];
    blockMap(4, :) = [5, 7, 1, 3, 0, 2, 4, 6];
    [xCoordinate, yCoordinate] = deal(cell(4, 8));
    for iShank = 1:4
        for iBlock = 1:8
            xCoordinate{iShank, iBlock} = repmat([0; 32], 24, 1) + 250*(iShank - 1);
            yCoordinate{iShank, iBlock} = reshape(repmat(0:15:345, 2, 1), [], 1) + 360*(iBlock-1);
        end
    end

    xcoords = []; ycoords = [];
    for iBlock = 1:8
        iShank = blockSelect(iBlock);
        jBlock = find(blockMap(iShank, :) == iBlock - 1);
        xcoords = [xcoords; xCoordinate{iShank, jBlock}]; 
        ycoords = [ycoords; yCoordinate{iShank, jBlock}]; 
    end

    fs = 30000; % sampling frequency
    save(fn, ...
        'chanMap','connected', 'xcoords', 'ycoords', 'kcoords', 'chanMap0ind', 'fs')
end

ops.chanMap             = fn;
ops.fs                  = 30000;        
