function runPhy()
%runPhy Starts Phy manual sorting
    % To use this code, phy should be installed using Anaconda
    % This activates 'Anaconda prompt' script and activates phy branch.
    startingDirectory = 'E:';
    anacondaDirectory = ['C:\Users\', getenv('USERNAME'), '\AppData\Local\Continuum\anaconda3\'];
    
    
    [file, path] = uigetfile(fullfile(startingDirectory, 'params.py'));
    if ischar(file)
        filepath = {fullfile(path, file)};
    else
        return
    end    
    
    %% Windows command parts: do not touch until phy is started.
    NET.addAssembly('System.Windows.Forms');
    sendkey = @(strkey) System.Windows.Forms.SendKeys.SendWait(strkey);
    
    % run Anaconda prompt. If your python is in the 'Path' and runs at cmd,
    % omit this.
    system([fullfile(anacondaDirectory, 'Scripts\activate.bat'), ' ', anacondaDirectory, ' &']);
    pause(0.5);
    
    % active phy environment (conda environment). if your environment is at
    % the main base, you don't need to run this.
    sendkey('activate phy');
    sendkey('{ENTER}');
    pause(0.25);
    
    % change volume and directory
    volume = strsplit(path, '\');
    sendkey(volume{1});
    sendkey('{ENTER}');
    pause(0.25);
    sendkey(['cd ', path]);
    sendkey('{ENTER}');
    pause(0.25);
    
    % run phy template-gui
    sendkey('phy template-gui params.py');
    sendkey('{ENTER}');
end