# CALFEM for MATLAB
CALFEM, a finite element toolbox for MATLAB.

### Manual
The full CALFEM manual can be accessed here: [calfem-3.6-manual-full.pdf](https://github.com/CALFEM/calfem-matlab/blob/master/calfem-3.6-manual-full.pdf)

A subset for frame and truss analysis can be accessed here: [calfem-3.6-manual-bar-beam.pdf](https://github.com/CALFEM/calfem-matlab/blob/master/calfem-3.6-manual-bar-beam.pdf)

### Installation instructions

1. Click "Download as zip" to download the package and unpack it. 

2. Add the these directories to the MATLAB path by clicking "Set path" in MATLAB, then "Add with Subfolders...", chose the unpackaged directory and then "Save"."


### Testing the installation

enter the following commands at the MATLAB prompt:

help beam2e

The help text for the beam2e command should appear if CALFEM is correctly 
installed.

### Update Log
#### assem函数

- **assem()**：提高了组装大型刚度矩阵的速度。实测：使用Q4单元，单元数量为200× 200时速度提高了1900倍。
- **extract_ed()**: 提高了从全局位移向量里提取单元位移的速度。实测：使用Q4单元，单元数量为200×200时速度提高了330倍。


