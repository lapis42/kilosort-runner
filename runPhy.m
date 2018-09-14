function runPhy()
    startingDirectory = 'E:';
    anacondaDirectory = 'C:\Users\kimd11\AppData\Local\Continuum\anaconda3\';
    
    [file, path] = uigetfile(fullfile(startingDirectory, '*_rez.mat'));
    filepath = fullfile(path, file);
    
    load(filepath);
    rezToPhy(rez, path);
    
    NET.addAssembly('System.Windows.Forms');
    sendkey = @(strkey) System.Windows.Forms.SendKeys.SendWait(strkey);
    
    system([fullfile(anacondaDirectory, 'Scripts\activate.bat'), ' ', anacondaDirectory, ' &']);
    pause(1);
    sendkey('activate phy');
    sendkey('{ENTER}');
    pause(0.5);
    volume = strsplit(path, '\');
    sendkey(volume{1});
    sendkey('{ENTER}');
    pause(0.5);
    sendkey(['cd ', path]);
    sendkey('{ENTER}');
    pause(0.5);
    sendkey('phy template-gui params.py');
    sendkey('{ENTER}');
end