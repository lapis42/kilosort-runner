function runPhy()
%runPhy Starts Phy manual sorting
    % To use this code, phy2 should be installed using Anaconda
    % This activates 'Anaconda prompt' script and activates phy branch.
    if strcmp(computer, 'PCWIN64') % if windows
        startingDirectory = 'E:';
        anacondaDirectory = ['C:\Users\', getenv('USERNAME'), '\AppData\Local\Continuum\anaconda3\'];
    elseif strcmp(computer, 'GLNXA64') % if linux
        startingDirectory = '/mnt/data';
        anacondaDirectory = '~/anaconda3/bin';
    end

    disp('==== Choose only one folder ====');
    fileList = fileSelector(startingDirectory, 1, 'params.py');
    if ~isempty(fileList) 
        filepath = fileparts(fileList{1});
    else
        return
    end    
    
    if strcmp(computer, 'PCWIN64') % windows
        str = [fullfile(anacondaDirectory, 'Scripts', 'activate.bat'), ' phy2 && '];
    elseif strcmp(computer, 'GLNXA64') % linux
        str = 'source activate phy2 && ';
    end
    str = [str, 'cd ', filepath, ' && phy template-gui params.py'];

    system(str);
end
