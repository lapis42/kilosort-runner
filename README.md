# Kilosort batch runner

* **runKs2.m**: automated spike-sorting using Kilosort2
* **runKs3.m**: automated spike-sorting using Kilosort3
* **runPhy.m**: manual spike-sorting using Phy (for windows only)
* **saveKs.m**: save phy format as a matlab struct
* **viewRaw.m**: raw binary data viewer (for SpikeGLX bin files)


```
>> runKs2('/mnt/data')
*****************************************
******** Batch Kilosort2 sorting ********
*****************************************

1: ...imec0/ANM480363_20210524_pfc301_hpc200_g0_t0.imec0.ap.bin
2: ...imec1/ANM480363_20210524_pfc301_hpc200_g0_t0.imec1.ap.bin

[1] Add folder
[2] Add file
[3] Delete file selection
[4] Set channel to exclude
[5] View raw data
[s] Start
[q] Quit
>> s
```
