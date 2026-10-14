% === DISPLAY 3D TOPOLOGY: 体素彩色 / 平滑(蓝色主体) 双模式 ===
function display_3D(rho, varargin)
% DISPLAY_3D 显示3D拓扑，两种显示模式由 Smooth 开关切换：
%   Smooth=false（默认）：体素方块显示，按标量场（如应力）逐单元着色
%   Smooth=true：isosurface 平滑显示（top3D125 配色：蓝色主体）
%
%   display_3D(rho)
%   display_3D(rho, 'Field', f, 'Mask', m, 'Range', [0 220], 'Title', s, ...
%              'Colormap', c, 'Colorbar', true, 'Smooth', false)
%
% 名称-值对参数:
%   Field    : 着色用标量场（仅体素模式生效），缺省为 rho
%   Mask     : 逻辑数组，true 的单元被隐藏
%   Range    : 颜色范围 [cmin cmax]，缺省自动
%   Title    : 图标题字符串
%   Colormap : 色图矩阵 (N x 3)，缺省 turbo
%   Colorbar : 是否显示 colorbar（逻辑），缺省 true
%   Smooth   : true 平滑显示（top3D125 配色）；false 体素彩色显示（缺省）

%  最后修改: 
% H Yingvar 2026-09-01

p = inputParser;
addRequired(p, 'rho');
addParameter(p, 'Field', [], @(v) isempty(v) || isequal(size(v), size(rho)));
addParameter(p, 'Mask', [], @(v) isempty(v) || isequal(size(v), size(rho)));
addParameter(p, 'Range', [], @(v) isempty(v) || (numel(v) == 2 && v(2) > v(1)));
addParameter(p, 'Title', '');
addParameter(p, 'Colormap', [], @(v) isempty(v) || size(v, 2) == 3);
addParameter(p, 'Colorbar', true, @islogical);
addParameter(p, 'Smooth', false, @islogical);
parse(p, rho, varargin{:});
f     = p.Results.Field;    if isempty(f),    f    = rho; end
mask  = p.Results.Mask;     if isempty(mask), mask = false(size(rho)); end
cr    = p.Results.Range;    if isempty(cr),   cr   = double([min(f(:)), max(f(:))]); end
cmap  = p.Results.Colormap; if isempty(cmap), cmap = turbo(256); end
tstr  = p.Results.Title;
showbar = p.Results.Colorbar;
smooth  = p.Results.Smooth;

[nely, nelx, nelz] = size(rho);
rho(mask | isnan(f)) = 0;                    % 隐藏掩蔽单元与场值无效单元

set(gcf, 'Name', 'ISO display', 'NumberTitle', 'off');
clf; hold on;
EDGE_COLOR   = [0, 0, 0]; % 描边颜色

if smooth
    % ---------- 平滑模式：参照 model2STL.m 的 isosurface 显示（青色 + 光照） ----------
    scolor = [0, 1, 1];                  % 面颜色：model2STL 默认 FaceColor 'c'（青色）
    % 内部接口：调节平滑程度（只改这里，不新增输入参数）
    SK = 5;    % 高斯平滑核大小（须为奇数 >= 3）：越大边界越圆，但可能侵蚀细杆/薄壁
    SS = 1.3;  % 高斯平滑标准差（> 0）：越大越圆滑
    % 高斯平滑：核 SK x SK x SK、std=SS，圆滑边界（注意 smooth3 的 size 须为奇数，
    % 原 'box',1 为 1x1x1 核 = 无平滑，导致边界呈阶梯状）
    rho_s = smooth3(rho, 'gaussian', SK, SS);
    % 零扩边封闭（与 model2STL 的 getISO 一致）：若用 isocaps 封口，
    % 模型触边截断处会得到 90° 直角平面；改用零环扩边后，等值面沿平滑场
    % 自然圆滑封闭，无直角，与导出的 STL 几何一致。
    aux = zeros(nely+2, nelx+2, nelz+2);
    aux(2:end-1, 2:end-1, 2:end-1) = rho_s;
    fv = isosurface(aux, 0.5);
    if ~isempty(fv.faces)
        fv.vertices = isoVPad(fv.vertices, nely);   % 扩边坐标 -> 显示坐标
        patch(fv, 'FaceColor', scolor, 'EdgeColor', 'none');                % 主体颜色
    end
    % 光影效果：相机灯 + 两盏定向光提亮 + 金属质感
    camlight('headlight');                             % 相机方向主光（随视角）
    light('Position', [-1 -1 1], 'Style', 'infinite'); % 左上前方定向光
    light('Position', [1 1 -1], 'Style', 'infinite');  % 右后下方补光（消除过暗面）
    lighting gouraud;                                  % 平滑高光
    material([0.2 0.4 1 40]);                          % 金属：环境光/漫反射调暗保留细节 + 高镜面/高指数
    % material = [环境光 漫反射 镜面 镜面指数] —— 调整方法：
    %   环境光：整体亮度。越大越亮，过大会盖住明暗细节（0.15~0.25 偏暗、0.3+ 偏亮）
    %   漫反射：受光面亮度。越大受光面越亮
    %   镜面：高光强度。1 为最强金属高光，调小则高光变弱、金属感下降
    %   镜面指数：高光锐利度。越大高光越小越锐利（30 较柔和、40+ 更锐利）
    %   光源：camlight 随视角转；下方两盏 light 的 Position 决定定向光方向，
    %   可增删 light 行或改 Position/数目来调整明暗与高光位置
else
    % ---------- 体素模式：方块显示，按场值逐单元着色 ----------
    solid = rho > 0.5;
    pady = false(nely+2, nelx, nelz); pady(2:end-1,:,:) = solid;
    padx = false(nely, nelx+2, nelz); padx(:,2:end-1,:) = solid;
    padz = false(nely, nelx, nelz+2); padz(:,:,2:end-1) = solid;
    m_jm = solid & ~pady(1:end-2,:,:);   % 朝向 j-1（y 增大侧） -> 面4
    m_jp = solid & ~pady(3:end,:,:);     % 朝向 j+1（y 减小侧） -> 面2
    m_im = solid & ~padx(:,1:end-2,:);   % 朝向 i-1（x 减小侧） -> 面5
    m_ip = solid & ~padx(:,3:end,:);     % 朝向 i+1（x 增大侧） -> 面3
    m_km = solid & ~padz(:,:,1:end-2);   % 朝向 k-1（z 减小侧） -> 面1
    m_kp = solid & ~padz(:,:,3:end);     % 朝向 k+1（z 增大侧） -> 面6
    offs = { ...
        [0 1 0; 0 0 0; 1 0 0; 1 1 0], ... % 面1 (z=0)     顶点 1,2,3,4
        [0 0 0; 0 0 1; 1 0 1; 1 0 0], ... % 面2 (y=0)     顶点 2,6,7,3
        [1 1 0; 1 0 0; 1 0 1; 1 1 1], ... % 面3 (x=1)     顶点 4,3,7,8
        [0 1 0; 0 1 1; 1 1 1; 1 1 0], ... % 面4 (y=1)     顶点 1,5,8,4
        [0 1 0; 0 0 0; 0 0 1; 0 1 1], ... % 面5 (x=0)     顶点 1,2,6,5
        [0 1 1; 0 0 1; 1 0 1; 1 1 1] };   % 面6 (z=1)     顶点 5,6,7,8
    [V1,F1,id1] = buildFaces(m_jm, offs{4}, nely);
    [V2,F2,id2] = buildFaces(m_jp, offs{2}, nely);
    [V3,F3,id3] = buildFaces(m_ip, offs{3}, nely);
    [V4,F4,id4] = buildFaces(m_im, offs{5}, nely);
    [V5,F5,id5] = buildFaces(m_km, offs{1}, nely);
    [V6,F6,id6] = buildFaces(m_kp, offs{6}, nely);
    V = [V1; V2; V3; V4; V5; V6];
    offV = cumsum([0, size(V1,1), size(V2,1), size(V3,1), size(V4,1), size(V5,1)]);
    F = [F1 + offV(1); F2 + offV(2); F3 + offV(3); F4 + offV(4); F5 + offV(5); F6 + offV(6)];
    cid = [id1; id2; id3; id4; id5; id6];
    if ~isempty(V)
        V = [V(:,1), -V(:,3), V(:,2)];   % 显示坐标变换
        fcol = cmap(scaleIndex(f, cr, cmap), :);
        patch('Faces', F, 'Vertices', V, 'FaceVertexCData', fcol(cid, :), ...
              'FaceColor', 'flat', 'EdgeColor', EDGE_COLOR, 'LineWidth', 0.01);
        colormap(cmap);
        if cr(2) > cr(1), clim(cr); end
        if showbar
            cb = colorbar;
            % 强制刻度覆盖完整范围，两端精确显示上下限
            cb.Ticks = linspace(cr(1), cr(2), 5);
            cb.TickLabels = arrayfun(@(v) num2str(v, '%.4g'), cb.Ticks, ...
                                     'UniformOutput', false);
            cb.FontSize = 18;
        end
    end
end

axis equal tight off; box on; view([30, 30]);
if ~isempty(tstr), title(tstr, 'FontSize', 14, 'FontWeight', 'Bold', 'Interpreter', 'none'); end
drawnow;
end

function V = isoVPad(vg, nely)
% 零扩边后体数据坐标 (1-based) -> 显示坐标 (x,-z,y)：
% 扩边比原始网格各方向多 1 圈，故 x=i-2, y=nely-j+1, z=-(k-2)
V = [vg(:,1)-2, -(vg(:,3)-2), nely - vg(:,2) + 1];
end

function idx = scaleIndex(f, cr, cmap)
% 将标量场 f 归一化到 [0,1] 并映射为色图索引（NaN 取最低色，不会被绘制）
ncol = size(cmap, 1);
c = f;
c(isnan(c)) = 0;
if cr(2) > cr(1)
    c = max(0, min(1, (c - cr(1)) / (cr(2) - cr(1))));
else
    c = zeros(size(c));
end
idx = max(1, min(ncol, round(c * (ncol - 1)) + 1));
end

function [V, F, cid] = buildFaces(mask, offs, nely)
% 由暴露面掩码构建所有面：V 顶点、F 连接、cid 每个面对应的单元线性索引。
% V 布局：前 n 行为所有面的第 1 个顶点，随后 n 行为第 2 个顶点，依此类推。
cid = find(mask(:));
n = numel(cid);
V = zeros(0, 3); F = zeros(0, 4);
if n == 0
    return;
end
[j, i, k] = ind2sub(size(mask), cid);
base = [i - 1, nely - j, k - 1];             % 单元基准角 (x,y,z)
V = [base + offs(1, :); base + offs(2, :); base + offs(3, :); base + offs(4, :)];
F = repmat((1:n)', 1, 4) + (0:3) * n;        % 面连接（跨组索引）
end