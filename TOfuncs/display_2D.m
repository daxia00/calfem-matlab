function display_2D(rho, varargin)
% DISPLAY_2D 显示2D拓扑标量场，接口仿照 display_3D（第一个参数为密度场 rho）
%
%   display_2D(rho)
%   display_2D(rho, 'Field', f, 'Mask', m, 'Range', [0 220], 'Title', s, ...
%               'Colormap', c, 'Colorbar', true, 'Smooth', false)
%
% 与 display_3D 一致的约定：
%   第一个参数 rho 为密度场，rho <= 0.5 的孔洞单元自动隐藏（不显示）；
%   Field 为着色用标量场（缺省为 rho）；Mask 仅用于额外隐藏实体单元
%   （例如非设计域 / 冻结实体），对 rho <= 0.5 的孔洞不起额外作用。
%
% 名称-值对参数:
%   Field    : 着色用标量场，缺省为 rho
%   Mask     : 逻辑数组，true 的单元被隐藏（仅额外隐藏实体单元）
%   Range    : 颜色范围 [cmin cmax]，缺省自动（忽略被隐藏单元）
%   Title    : 图标题字符串
%   Colormap : 色图矩阵 (N x 3)，缺省 turbo
%   Colorbar : 是否显示 colorbar（逻辑），缺省 true
%   Smooth   : true 仿 FPTO2D 的光滑边界表示（单元级锥形密度滤波 + 细化插值 +
%              二分阈值 + 等值线清晰轮廓）；false 逐单元硬边显示（缺省）

%  最后修改: 
% H Yingvar 2026-09-27

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

f     = p.Results.Field;   if isempty(f),    f = rho; end
mask  = p.Results.Mask;    if isempty(mask), mask = false(size(rho)); end
cr    = p.Results.Range;
cmap  = p.Results.Colormap; if isempty(cmap), cmap = turbo(256); end
tstr  = p.Results.Title;
showbar = p.Results.Colorbar;
smooth  = p.Results.Smooth;

% ssig：内部平滑强度常量（非接口参数），仅 smooth=true 时用于高斯平滑单元场。
%   含义：高斯平滑标准差，单位为“单元”，≈ 模糊半径尺度；1 表示按约 1 个单元模糊，
%        用于抹平 0/1 密度经插值后产生的锯齿/褶皱。
%   调法：常用 0.5~2。越大边界越光滑圆润，但过大将削薄细杆、圆化尖角并轻微
%        降低设计保真度；需要更光滑时直接改这个值即可。
ssig = 1;

% rho<=0.5 的孔洞 + mask 指定的单元 + 场值 NaN 一律隐藏
hide = rho <= 0.5 | mask | isnan(f);
A = double(f);                    % 统一为 double，兼容整型/逻辑型输入
A(hide) = NaN;

% 若未指定 Range，则基于可见单元自动计算颜色范围（忽略 NaN）
if isempty(cr)
    valid = A(~isnan(A));
    if isempty(valid)
        cr = [0 1];
    else
        cr = [min(valid(:)), max(valid(:))];
        if cr(2) == cr(1)
            cr = cr + [-0.5, 0.5];
        end
    end
end

% 平滑模式：仿 FPTO2D 的“光滑边界表示”，得到平滑且轮廓清晰的结构：
%   1) 对单元场做高斯平滑（内部常量 ssig），消除单元级锯齿；
%   2) 将平滑后的密度场 rho 与着色场 f 双线性插值到细化网格（等价 FPTO2D 的 rhofine）；
%   3) 二分法求阈值 th，使细化后实体面积与逐单元实体面积一致（仿 FPTO2D 体积守恒）；
%   4) 用 imagesc + AlphaData 在细化网格上绘制平滑云图（比 contourf 快得多），
%      再叠加一条结构外光滑轮廓线。
%   false 时仍为逐单元硬边显示（imagesc）。
if smooth
    scale = 6;                              % 细化倍数（每单元插值点数）；越小越快
    [nely, nelx] = size(rho);
    [Xe, Ye] = meshgrid(1:nelx, 1:nely);
    Xq = linspace(1, nelx, nelx * scale);
    Yq = linspace(1, nely, nely * scale);
    [XQ, YQ] = meshgrid(Xq, Yq);

    % 先对单元场做高斯平滑：消除 0/1 密度经双线性插值后沿单元产生的锯齿与褶皱，
    % 得到更光滑的轮廓（面积由随后的阈值二分补偿，粗细基本保持）。
    % rhoS 决定边界形状，fS 决定颜色平滑度，二者平滑强度同为内部常量 ssig。
    rhoS = gaussian_blur2(double(rho), ssig);
    fS   = double(f);
    if any(isnan(fS(:))), fS = fillmissing2(fS, 'nearest'); end
    fS   = gaussian_blur2(fS, ssig);

    % interp2 要求采样值为双精度/单精度，统一转 double
    rhoI = interp2(Xe, Ye, rhoS, XQ, YQ, 'linear');         % 细化密度场
    fI   = interp2(Xe, Ye, fS,   XQ, YQ, 'linear');         % 细化着色场
    mI   = interp2(Xe, Ye, double(mask), XQ, YQ, 'nearest') > 0.5;

    % 二分法求阈值 th：使 rhoI>=th 的细化面积等于实体单元数目（体积守恒，仿 FPTO2D）
    target = sum(rho(:) > 0.5);
    lo = 0; hi = 1;
    for k = 1:40
        th = (lo + hi) / 2;
        if sum(rhoI(:) >= th) / scale^2 > target
            lo = th;
        else
            hi = th;
        end
    end
    th = (lo + hi) / 2;

    solid = rhoI >= th & ~mI;               % 光滑结构区域（含 mask 挖空）
    if target <= 0, solid = false(size(solid)); end

    % 渲染：用细化网格上的 imagesc + AlphaData 遮罩绘制平滑云图。
    % 相比 contourf（多层级 + 海量三角形，慢）这里只是位图绘制，速度大幅提升；
    % 结构外 solid=false 处透明不显示，边界形状由紧随其后的轮廓线保证清晰。
    him = imagesc(Xq, Yq, fI);
    set(him, 'AlphaData', double(solid));    % 结构外透明（不显示）
    hold on;
    % 仅补一条结构外光滑轮廓线，使边界锐利清晰
    contour(XQ, YQ, rhoI, [th th], '-', 'Color', [0.20 0.20 0.20], ...
            'LineWidth', 0.8);
    hold off;
    axis image; axis off;
    % 与 imagesc 的矩阵显示约定保持一致（行号向下增大），否则等值线会上下翻转
    set(gca, 'YDir', 'reverse');
    colormap(cmap);
    if cr(2) > cr(1), clim(cr); end   % 显式强制颜色范围（上下限）
else
    h = imagesc(A);
    set(h, 'AlphaData', ~isnan(A));   % NaN 区域透明
    axis image; axis off;
    colormap(cmap);
    if cr(2) > cr(1), clim(cr); end   % 显式强制颜色范围（上下限）
end
if ~isempty(tstr)
    title(tstr, 'FontSize', 16, 'FontName', 'Times New Roman', 'FontWeight', 'Bold');
end
if showbar
    cb = colorbar;
    % 强制刻度覆盖完整范围，两端精确显示上下限
    cb.Ticks = linspace(cr(1), cr(2), 5);
    cb.TickLabels = arrayfun(@(v) num2str(v, '%.4g'), cb.Ticks, ...
                             'UniformOutput', false);
    cb.FontSize = 16;
end

drawnow;
end

function B = gaussian_blur2(A, sigma)
% GAUSSIAN_BLUR2 可分离高斯平滑（replicate 边界），A 为 double 矩阵
%   sigma 以单元为单位；sigma<=0 时原样返回
if sigma <= 0
    B = A;
    return;
end
r = max(1, ceil(3 * sigma));
x = -r:r;
g = exp(-(x.^2) / (2 * sigma^2));
g = g / sum(g);
% replicate 边界填充，避免域外被当作 0 导致边缘变暗/收缩
ri = [ones(1, r), 1:size(A, 1), size(A, 1) * ones(1, r)];
ci = [ones(1, r), 1:size(A, 2), size(A, 2) * ones(1, r)];
Ap = A(ri, ci);
% 可分离卷积：分别沿竖向、横向各做一次一维卷积，复杂度 O(k) 而非 O(k^2)
B  = conv2(Ap, g(:),  'same');   % 竖向平滑
B  = conv2(B,  g(:)', 'same');   % 横向平滑
B  = B(r+1:end-r, r+1:end-r);
end
