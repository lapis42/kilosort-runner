if exist('neuropix24strip.mat', 'file') == 0
    Nchannels = 384;
    connected = true(Nchannels, 1);
    chanMap   = 1:Nchannels;
    chanMap0ind = chanMap - 1;
    xtemp   = repmat([0; 16], 24, 1);
    xcoords = [xtemp; xtemp+250; xtemp; xtemp+250; xtemp+500; xtemp+750; xtemp+500; xtemp+750];
    ytemp = reshape(repmat((0:15:345), 2, 1), [], 1);
    ycoords = [ytemp; ytemp; ytemp+360; ytemp+360; ytemp; ytemp; ytemp+360; ytemp+360];
    kcoords   = ones(Nchannels,1); % grouping of channels (i.e. tetrode groups)
    fs = 30000; % sampling frequency
    save('neuropix24strip.mat', ...
        'chanMap','connected', 'xcoords', 'ycoords', 'kcoords', 'chanMap0ind', 'fs')
end

ops.chanMap             = 'neuropix24strip.mat';
ops.fs                  = 30000;        
