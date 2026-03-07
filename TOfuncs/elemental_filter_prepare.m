function [Hs, h] = elemental_filter_prepare(nelx, nely, rmin, passive)
% 生成基于单元的过滤器矩阵H及其行和Hs
% 输入参数：
%   nelx : 设计域在x方向的单元数量
%   nely : 设计域在y方向的单元数量
%   rmin : 过滤器半径
%   passive: 设计域标记 (可选，等于1为非设计域，默认值全0)
% 输出参数：
%   h  : 过滤器卷积核矩阵，大小为(2 * (ceil(rmin)-1) +1)^2，对应以某单元为中心rmin范围内的所有单元对应的权重
%   Hs : 过滤器权重和矩阵，大小为(nely x nelx)，以单元(ely,elx)为中心对应的rmin范围内权重总和
% 用法：
% alpha_i = conv2(alpha_i, h, ’same’) ./ Hs;

% 最后修改: 
% H Yingvar 2026-01-06

%% 初始化和参数处理
if nargin < 4
    passive = false(nely, nelx);
else
    passive = reshape(passive, nely, nelx);
    passive = logical(passive);
end

%% 计算过滤核，kernel_r的含义是（1/2 * 矩阵尺寸 -1）
kernel_r = ceil(rmin);
[dx, dy] = meshgrid(1-kernel_r:kernel_r-1);
h = max(0, rmin - hypot(dx, dy));  % 更高效的距离计算

%% 创建最终的权重和矩阵
Hs = conv2(~passive, h, "same");
Hs(logical(passive)) = 1e9; % 1. 防止除以0时异常，2. 使非设计域的灵敏度趋近于0

end

