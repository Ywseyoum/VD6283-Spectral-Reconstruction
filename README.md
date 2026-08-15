# VD6283 Spectral Reconstruction

**MATLAB-based fluorescence spectral reconstruction using the STMicroelectronics VD6283 multispectral sensor, signal processing, and machine learning.**

## Overview

This repository documents a research internship project focused on reconstructing full fluorescence emission spectra from the limited outputs of a compact multispectral sensor. The work used the **VD6283**, which provides six wavelength-dependent detector channels, and explored whether those six measurements could be transformed into a much higher-dimensional fluorescence spectrum.

The project combined experimental fluorescence measurements, sensor characterization, MATLAB data processing, physics-based response simulation, and machine-learning regression.

## Project Goal

A conventional fluorescence spectrum contains intensity values across many wavelengths, while the VD6283 produces only six detector responses. The central question was:

> **Can a six-channel optical sensor be used to estimate a full fluorescence emission spectrum?**

The reconstruction target covered approximately **400–700 nm at 1 nm spacing**, corresponding to 301 spectral output values.

## VD6283 Sensor Channels

The reconstruction framework used all six VD6283 channels:

- Blue
- Green
- Red
- Infrared (IR)
- Visible
- Clear

The Clear channel was used as a normalization reference in the modeling workflow. Because of this, most sample-dependent information after normalization came from the remaining varying channel ratios.

## Research Workflow

The MATLAB pipeline followed the general sequence:

`CSV / spectral data → Import → Clean → Interpolate → Normalize → Integrate → Model → Visualize`

Major steps included:

1. Importing detector characterization data and fluorescence reference spectra.
2. Cleaning missing or invalid values and aligning wavelength ranges.
3. Building wavelength-dependent sensitivity curves for the VD6283 channels.
4. Matching fluorescence spectra with corresponding sensor-response data.
5. Normalizing detector responses using the Clear channel as the reference.
6. Generating simulated VD6283 responses from known fluorescence spectra through sensitivity-weighted numerical integration.
7. Training and comparing regression / machine-learning reconstruction models.
8. Evaluating predicted spectra against reference spectra using quantitative metrics and visual plots.

## Two Data Paths

### Synthetic / Training Path

A larger fluorescence dataset from **PhotochemCAD** was used to support machine-learning development. Known fluorescence spectra were combined with the characterized VD6283 channel sensitivities to simulate the response each sensor channel would produce.

This produced paired examples of:

- six-channel sensor responses as model inputs, and
- full fluorescence spectra as reconstruction targets.

Approximately **130 fluorophore spectra** were represented in this modeling dataset.

### Experimental / Real Path

Separately, fluorescent samples were measured experimentally using the VD6283 and a fluorescence excitation-emission measurement system. MATLAB scripts were used to process the measured data and obtain reference fluorescence information for comparison and reconstruction work.

**Important distinction:** the small set of lab-prepared fluorescent samples was not the dataset used to train the main machine-learning model. The larger PhotochemCAD-based dataset supported model training, while the experimental measurements formed a separate real-data pathway for characterization, testing, and comparison.

## Machine-Learning Reconstruction

Several regression approaches were investigated. Two important neural-network pipelines compared dimensionality-reduction approaches before spectral prediction:

| Model | RMSE | R² |
|---|---:|---:|
| PLS + Neural Network | 0.1287 | 0.8202 |
| **PCA + Neural Network** | **0.0977** | **0.8965** |

The **PCA + Neural Network** approach produced the strongest overall result in the reported comparison. PCA reduced the dimensionality of the 301-point spectral target before neural-network prediction, after which the spectrum could be reconstructed back into wavelength space.

Performance was evaluated using metrics such as **RMSE** and **R²**, along with predicted-versus-reference spectral plots. Many fluorophores showed strong reconstruction agreement, while some spectra remained more difficult to reproduce accurately.

## Repository Structure

```text
VD6283-Spectral-Reconstruction/
├── README.md
├── .gitignore
├── matlab/
│   └── README.md
├── data/
│   └── README.md
├── results/
│   └── README.md
└── docs/
    └── methodology.md
```

The repository is currently organized as a **public technical portfolio and project record**. Research code, datasets, and additional figures will only be added when they are confirmed to be appropriate for public release.

## Tools & Skills Demonstrated

- MATLAB
- Data cleaning and preprocessing
- Numerical integration
- Spectral data analysis
- Multispectral sensor characterization
- Fluorescence spectroscopy
- Principal Component Analysis (PCA)
- Partial Least Squares (PLS)
- Neural-network regression
- Model evaluation with RMSE and R²
- Scientific visualization
- Experimental and synthetic-data workflow design

## Project Significance

This work explored whether compact multispectral sensing combined with computational reconstruction could recover richer spectral information than the raw detector outputs provide. The broader concept is to use a small optical sensor together with data processing and machine learning to approximate measurements that would normally require more specialized spectroscopic hardware.

## Repository Status

**Documentation phase.** Public-safe project documentation is included first. Code, sample data, and result figures can be added after confirming that the relevant research materials are permitted for public release.
