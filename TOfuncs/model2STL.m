function model2STL(fout, varargin)
% MODEL2STL  为 Model 生成 STL 文件（立方体 / 平滑 isosurface 双模式）
%   参考：Liu (Apr 2015)，Top3D 程序扩展（原名 Top3dSTL_v3.m），用于 3D 打印或后处理。
%
%   model2STL(fout)
%       当工作区存在设计变量 x 时，用 x 生成 STL 文件（默认平滑模式）。
%
%   model2STL(fout, x)
%       直接传入单元密度矩阵 x（nely x nelx x nelz），生成 STL 文件。
%
%   model2STL(___, Name, Value)
%       通过名称-值对设置可选参数（可搭配任意输入组合）：
%       FORMAT     - 文件格式，'binary'(默认) 或 'ascii'
%       MODE       - 面片生成模式，'iso'(默认，平滑) 或 'cube'(体素方块)
%       CUTOFF     - 密度阈值，低于该值的单元视为空腔。默认: 0.5
%       TITLE      - 写入 STL 的标题文本（二进制模式最大 80 字符）
%       FACECOLOR  - 显示时的面颜色。默认: 'cyan'
%       ALPHA      - 显示时的面透明度。默认: 1
%       UNITLENGTH - 单元边长向量 [lx ly lz]。默认: [1 1 1]
%       PLOT       - 是否同时可视化。默认: true
%
%   示例 1：
%       model2STL('MyModel.stl')          % 使用工作区变量 x
%   示例 2：
%       model2STL('MyModel.stl', x, ...
%           'Format', 'ascii', 'Mode', 'cube', 'FaceColor', 'm', 'Plot', false)

%   最后修改: 
% H Yingvar 2026-09-01

% ---- 确定密度数据来源 ------------------------------------------------
% 若第一个可选参数为数值/逻辑数组，则视为密度矩阵直接使用；
% 否则回退读取工作区变量 x（Top3D 的标准设计变量名）。
if ~isempty(varargin) && (isnumeric(varargin{1}) || islogical(varargin{1}))
    xPhys = varargin{1};                       % 直接传入的密度矩阵
    options = parseInputs(varargin{2:end});
else
    try
        xPhys = evalin('base', 'x');           % 默认数据：工作区变量 x
    catch ME
        % 变量不存在时报错，并给出友好提示
        if ismember(ME.identifier, ...
                {'MATLAB:UndefinedFunction', 'MATLAB:UndefinedVariable'})
            error('model2STL:NoData', ...
                '未提供密度参数，且工作区中不存在变量 x');
        else
            rethrow(ME)
        end
    end
    options = parseInputs(varargin{:});
end

% ---- 按模式生成面片与顶点 --------------------------------------------
% 'cube' ：立方体体素模式（只保留外表面）
% 'iso'  ：isosurface 平滑模式（默认）
if strcmp(options.mode, 'cube')
    [faces, verts] = getCube(xPhys, options);
else
    [faces, verts] = getISO(xPhys, options);
end

% ---- 由 面+顶点 组装三角形面片(facets) --------------------------------
% facets(:,:,k) 为第 k 个面片；其中 1:3 行为法向量，
% 4:6 / 7:9 / 10:12 行分别为三个顶点坐标。
facets = single(verts);                        % 顶点坐标转单精度
facets = reshape(facets(faces',:)', 3, 3, []); % 按面索引取 3 个顶点 → 3x3xN

% ---- 计算并归一化法向量 ------------------------------------------------
V1 = squeeze(facets(:,2,:) - facets(:,1,:));   % 边1 = 顶点2 - 顶点1
V2 = squeeze(facets(:,3,:) - facets(:,1,:));   % 边2 = 顶点3 - 顶点1
normals = cross(V1, V2);                       % 叉积得到法向量
clear V1 V2
normals = bsxfun(@times, normals, 1 ./ sqrt(sum(normals .* normals, 1))); % 归一化

% 法向量与顶点拼成 (12 x N) 的面片数组，供写入函数使用
facets = cat(2, reshape(normals, 3, 1, []), facets);
clear normals

% ---- 写出 STL 文件 ----------------------------------------------------
if strcmp(options.format, 'ascii')
    writeAscii(facets, fout, options.title);
else
    writeBinary(facets, fout, options.title);
end

end

function options = parseInputs(varargin)
% PARSEINPUTS 解析名称-值对可选参数，返回结构体 options。
OP = inputParser;
defaultFormat    = 'binary';                 % 默认二进制格式
expectedFormat   = {'ascii', 'binary'};
defaultMode      = 'iso';                    % 默认平滑(isosurface)模式
expectedMode     = {'cube', 'iso'};
defaultTitle     = sprintf('Created by model2STL.m %s', char(datetime('now')));
defaultCutoff    = 0.5;                      % 密度阈值
defaultFcolor    = 'c';                      % 显示面颜色
defaultAlpha     = 1;                        % 显示面透明度
defaultUnitLegth = [1, 1, 1];                % 单元边长 [lx ly lz]
defaultPlot      = true;                     % 是否可视化

% addParameter（旧版 addParamValue 已废弃）：参数名不区分大小写
OP.addParameter('format', defaultFormat, ...
    @(x) any(validatestring(x, expectedFormat)));
OP.addParameter('mode', defaultMode, ...
    @(x) any(validatestring(x, expectedMode)));
OP.addParameter('title', defaultTitle, @ischar);
OP.addParameter('cutoff', defaultCutoff, @isnumeric);
OP.addParameter('facecolor', defaultFcolor, @ischar);
OP.addParameter('alpha', defaultAlpha, @isnumeric);
OP.addParameter('unitlength', defaultUnitLegth, ...
    @(x) validateattributes(x, {'numeric'}, {'vector'}));
OP.addParameter('plot', defaultPlot, @islogical);

OP.parse(varargin{:});
options = OP.Results;
end

function [faces, verts] = getCube(xPhys, options)
% GETCUBE  立方体(体素)模式：把每个固体单元表示为立方体外表面。
%   相邻固体单元之间的共享面会被删除，只保留暴露在外的外表面，
%   因此得到的是轻量"外壳"网格（而非实心体）。
nx = options.unitlength(1);          % x 方向单元边长
ny = options.unitlength(2);          % y 方向单元边长
nz = options.unitlength(3);          % z 方向单元边长
[nely, nelx, nelz] = size(xPhys);    % 单元数：y(行) x(列) z(层)
nele = nelx * nely * nelz;           % 单元总数

% ---- 生成单元节点编号（按 Top3D 列优先约定） ---------------------------
% 每个方向节点数比单元数多 1，z 方向按层整体偏移。
nodegrd = reshape(1:(nely+1)*(nelx+1), nely+1, nelx+1);           % xy 平面节点
nodeids = reshape(nodegrd(1:end-1, 1:end-1), nely*nelx, 1);       % 单元左下角节点
nodeidz = 0:(nely+1)*(nelx+1):(nelz-1)*(nely+1)*(nelx+1);         % 各层节点偏移
nodeids = repmat(nodeids, size(nodeidz)) + repmat(nodeidz, size(nodeids));
enodVec = nodeids(:) + 1;                                         % 转 1 基索引
% 立方体 8 个节点相对左下角节点的偏移
enodMat = repmat(enodVec, 1, 8) + ...
    repmat([0 nely+[1 0] -1 ...
    (nely+1)*(nelx+1)+[0 nely+[1 0] -1]], nele, 1);

% ---- 12 个三角面的顶点索引（指向 enodMat 的 8 个节点） -----------------
% 每两个三角面组成一个立方体面：back(1,2) front(3,4) left(5,6)
% right(7,8) up(9,10) down(11,12)
enodidx = [1 3 2; 1 4 3; ...   % back  (-z 方向)
           5 6 7; 5 7 8; ...   % front (+z 方向)
           1 5 8; 1 8 4; ...   % left  (-x 方向)
           6 2 3; 6 3 7; ...   % right (+x 方向)
           8 7 3; 8 3 4; ...   % up    (-y 方向)
           1 2 6; 1 6 5];      % down  (+y 方向)

% ---- 密度二值化：低于 cutoff 视为空腔，否则视为固体 ---------------------
solid = double(xPhys >= options.cutoff);

% ---- 向量化判断 6 个方向是否有相邻固体（有则隐藏共享面） ----------------
% 通过平移切片得到各方向邻居指示矩阵（位置 k 保存该方向邻居的 solid 值）；
% 边界处补 0 = 无邻居 = 该方向的面暴露。
NB_k1 = zeros(nely, nelx, nelz); NB_k1(:,:,2:end)   = solid(:,:,1:end-1); % -z 邻居
NB_kp = zeros(nely, nelx, nelz); NB_kp(:,:,1:end-1) = solid(:,:,2:end);   % +z 邻居
NB_i1 = zeros(nely, nelx, nelz); NB_i1(:,2:end,:)   = solid(:,1:end-1,:); % -x 邻居
NB_ip = zeros(nely, nelx, nelz); NB_ip(:,1:end-1,:) = solid(:,2:end,:);   % +x 邻居
NB_j1 = zeros(nely, nelx, nelz); NB_j1(2:end,:,:)   = solid(1:end-1,:,:); % -y 邻居
NB_jp = zeros(nely, nelx, nelz); NB_jp(1:end-1,:,:) = solid(2:end,:,:);   % +y 邻居

% 每个单元 12 个面的保留标志（1=暴露保留，0=隐藏）
% 先把 6 个方向矩阵展平为列向量，再水平拼接成 nele x 12 的矩阵
solidVec = solid(:) == 1;                        % 实体单元标记 (nele x 1)
keep = ~[NB_k1(:) NB_k1(:) NB_kp(:) NB_kp(:) ... % back / front
         NB_i1(:) NB_i1(:) NB_ip(:) NB_ip(:) ... % left / right
         NB_j1(:) NB_j1(:) NB_jp(:) NB_jp(:)];   % up   / down
keep = keep & repmat(solidVec, 1, 12);           % 空单元不生成任何面

% ---- 汇总所有暴露面（每个面 = 一个三角形） ------------------------------
% 预分配，并按单元优先、面顺序优先的顺序写入（与原循环版输出顺序一致）。
cnt  = sum(keep, 2);                 % 每个单元保留的面数
offs = cumsum([0; cnt(1:end-1)]);    % 每个单元面的起始写入行
posInUnit = cumsum(keep, 2);         % 每个面在所属单元内的序号
row = offs + posInUnit;              % 每个面的全局写入行
faces = zeros(sum(cnt), 3);
for f = 1:12                         % 逐面写入三角形
    sel = keep(:, f);                % 该面需保留的单元
    faces(row(sel, f), :) = enodMat(sel, enodidx(f, :));
end

% ---- 顶点坐标 -----------------------------------------------------------
[xx, yy, zz] = meshgrid(0:nx:nelx*nx, 0:ny:nely*ny, 0:nz:nelz*nz);
% 注意：y 方向做了翻转（nely-yy），与 Top3D 可视化取向保持一致。
verts = [xx(:) nely-yy(:) zz(:)];

% ---- 可视化 -------------------------------------------------------------
if options.plot
    dverts = [xx(:) zz(:) yy(:)];
    cla, hold on, view(30,30), rotate3d on, axis equal
    axis([0 nelx*nx 0 nelz*nz 0 nely*ny]), box
    set(gca, 'YDir', 'reverse', 'ZDir', 'reverse', ...
        'ZtickLabel', flipud(get(gca, 'Ztick')'));
    patch('faces', faces, 'vertices', dverts, ...
        'FaceColor', options.facecolor, 'FaceAlpha', options.alpha)
    xlabel('x'), ylabel('z'), zlabel('y')
end
end

function [faces, verts] = getISO(xPhys, options)
% GETISO  平滑(isosurface)模式：在密度场中提取 cutoff 等值面。
%   先按 display_3D.m 平滑模式的平滑程度对密度场做高斯平滑（圆滑边界），
%   再用 0 在四周扩边，保证等值面把模型完整地包起来。
nx = options.unitlength(1);          % x 方向单元边长
ny = options.unitlength(2);          % y 方向单元边长
nz = options.unitlength(3);          % z 方向单元边长
[nely, nelx, nelz] = size(xPhys);    % 单元数

% 内部接口：平滑程度与 display_3D.m 平滑模式保持一致（gaussian, 核5, std1.5）
SK = 5;    % 高斯平滑核大小（须为奇数 >= 3）：越大边界越圆
SS = 1.3;  % 高斯平滑标准差：越大越圆滑
xS = smooth3(xPhys, 'gaussian', SK, SS);

% 扩边：外围补一圈 0
aux = zeros(nely+2, nelx+2, nelz+2);
aux(2:end-1, 2:end-1, 2:end-1) = xS;

% 网格坐标（顶点位于单元中心，故坐标各偏移 -0.5）
[X, Y, Z] = meshgrid(0:nx:nx*(nelx+1), ...
    0:ny:ny*(nely+1), ...
    0:nz:nz*(nelz+1));

% 提取等值面；坐标交换为 (x,z,y) 以匹配 Top3D 显示取向
[faces, verts] = isosurface(X-0.5, Z-0.5, Y-0.5, aux, options.cutoff);

% ---- 可视化 -------------------------------------------------------------
if options.plot
    cla, hold on, view(30,30), rotate3d on, axis equal
    axis([0 nx*nelx 0 nz*nelz 0 ny*nely]), box
    set(gca, 'YDir', 'reverse', 'ZDir', 'reverse', ...
        'ZtickLabel', flipud(get(gca, 'Ztick')'));
    patch('Faces', faces, 'Vertices', verts, ...
        'FaceColor', options.facecolor, 'EdgeColor', 'none', ...
        'FaceAlpha', options.alpha);
    camlight, lighting gouraud;
    xlabel('x'), ylabel('z'), zlabel('y')
    drawnow
end
end

function writeAscii(facets, fout, title)
% WRITEASCII 以 ASCII 文本格式写出 STL 文件。
%{
FORMAT:

solid name
    facet normal ni nj nk
        outer loop
            vertex v1x v1y v1z
            vertex v2x v2y v2z
            vertex v3x v3y v3z
        endloop
    endfacet
end solid name

%}
fid = fopen(fout, 'wb+');
fprintf(fid, [title, '\r\n']);
fprintf(fid,[...
    'facet normal %.7E %.7E %.7E\r\n' ...
    'outer loop\r\n' ...
    'vertex %.7E %.7E %.7E\r\n' ...
    'vertex %.7E %.7E %.7E\r\n' ...
    'vertex %.7E %.7E %.7E\r\n' ...
    'endloop\r\n' ...
    'endfacet\r\n'], facets);
fprintf(fid, ['end ', title, '\r\n']);
fclose(fid);
fprintf('Wrote %d facets to %s\n',size(facets, 3), fout);
end

function writeBinary(facets, fout, title)
% WRITEBINARY 以二进制格式写出 STL 文件。
%{
FORMAT:

UINT8[80] ? Header
UINT32 ? Number of triangles

foreach triangle
    REAL32[3] ? Normal vector
    REAL32[3] ? Vertex 1
    REAL32[3] ? Vertex 2
    REAL32[3] ? Vertex 3
    UINT16 ? Attribute byte count
end

%}
fid = fopen(fout, 'wb+');
fprintf(fid, '%-80s', title);                  % Title
fwrite(fid, size(facets, 3), 'uint32');        % Number of facets
facets = typecast(facets(:), 'uint16');        % Convert to unit16
facets = reshape(facets, 12*2, []);
facets(end+1, :) = 0;                          % Add color(0) to the end of each facet
fwrite(fid, facets, 'uint16');
fclose(fid);
fprintf('Wrote %d facets to %s\n',size(facets, 2), fout);
end