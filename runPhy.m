function runPhy()
%runPhy Starts Phy manual sorting
    % To use this code, phy2 should be installed using Anaconda
    % This activates 'Anaconda prompt' script and activates phy branch.
    startingDirectory = 'E:';
    anacondaDirectory = ['C:\Users\', getenv('USERNAME'), '\AppData\Local\Continuum\anaconda3\'];

    fileList = fileSelector(startingDirectory, 1, 'params.py');
    if ~isempty(fileList) 
        filepath = fileparts(fileList{1});
    else
        return
    end    
    
    str = [fullfile(anacondaDirectory, 'Scripts', 'activate.bat'), ' phy2 && '];
    str = [str, 'cd ', filepath, ' && phy template-gui params.py'];

    system(str);
end
