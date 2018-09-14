NET.addAssembly('System.Windows.Forms');
sendkey = @(strkey) System.Windows.Forms.SendKeys.SendWait(strkey) ;

system('cmd &');
sendkey('dir')
sendkey('{ENTER}');
sendkey('exit')
sendkey('{ENTER}');