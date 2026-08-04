# CALFEM for MATLAB
CALFEM, a finite element toolbox for MATLAB.

在原版基础上对部分函数进行了性能优化，并添加拓扑优化的相关函数。

### Update Log

- **assem()**：提高了组装大型刚度矩阵的速度。实测：使用Q4单元，单元数量为200× 200时速度提高了1900倍。
- **extract_ed()**: 提高了从全局位移向量里提取单元位移的速度。实测：使用Q4单元，单元数量为200×200时速度提高了330倍。
- 增加**TOfuncs**文件夹，整合拓扑优化相关函数。


