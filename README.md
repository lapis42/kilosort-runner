# Kilosort Batch Runner

This repository contains a set of MATLAB scripts for automated and manual spike sorting using Kilosort and Phy.

## Scripts

| Script | Description |
|--------|-------------|
| `runKs2.m` | Automated spike-sorting using Kilosort2 |
| `runKs3.m` | Automated spike-sorting using Kilosort3 |
| `runPhy.m` | Manual spike-sorting using Phy (Windows only) |
| `saveKs.m` | Save Phy format as a MATLAB struct |
| `viewRaw.m` | Raw binary data viewer for SpikeGLX bin files |

## Usage

1. Ensure Kilosort2/3 and npy-matlab are in your MATLAB path.
2. Run the desired script (e.g., `runKs2`) with the data directory as an argument.
3. Follow the prompts to select files and start the sorting process.

- [New] You don't need to have a separate channel map file, as these scripts read the SpikeGLX meta file to parse the channel map information. 🗺️


```matlab
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