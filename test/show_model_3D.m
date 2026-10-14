%% ====== show_model_3D: 三维模型可视化与验证 ======
% 设计域函数需遵循统一输出格式:
%   [x, nonDesign, freezeSolid, ind_stress_TO, F, BC] = 函数名(nelx, nely, nelz, subD_size)
%
% 直接修改下行调用你的函数即可:

nelx = 90; nely = 90; nelz = 30; subD_size = 0.9;
[x, nonDesign, freezeSolid, ind_stress_TO, F, BC] = case_Lbracket_3D(nelx, nely, nelz, subD_size);

% --- 三维节点坐标网格（列优先: y 最快, 其次 x, 其次 z） ---
nN_y = nely + 1; nN_x = nelx + 1; nN_z = nelz + 1;
ndof = 3 * nN_x * nN_y * nN_z;
[nodeY, nodeX, nodeZ] = ndgrid(0:nely, 0:nelx, 0:nelz); % 与 nodeMat 同形状 (nN_y, nN_x, nN_z)

% --- 提取载荷信息 ---
% 节点 n 的三个自由度: 3n-2 = x, 3n-1 = y, 3n = z
[load_dofs_idx, ~, F_vals] = find(F);
load_node = floor((load_dofs_idx + 2) / 3);       % 自由度 -> 节点编号
load_dir  = mod(load_dofs_idx - 1, 3) + 1;        % 1 = x, 2 = y, 3 = z
total_force = sum(F_vals);

% --- 提取边界条件信息 ---
fixed_dofs_list = BC(:, 1);
fixed_node = floor((fixed_dofs_list + 2) / 3);    % 自由度 -> 节点编号

% 固定节点去重，并按六个面统计
u_fixed = unique(fixed_node);
fy = nodeY(u_fixed); fx = nodeX(u_fixed); fz = nodeZ(u_fixed);
n_top    = sum(fy == 0);      % 顶面 y=1
n_bottom = sum(fy == nely);   % 底面 y=nely+1
n_left   = sum(fx == 0);      % 左面 x=1
n_right  = sum(fx == nelx);   % 右面 x=nelx+1
n_front  = sum(fz == 0);      % 前面 z=1
n_back   = sum(fz == nelz);   % 后面 z=nelz+1

%% ====== 绘图 ======
figure('Name', '三维模型 — 载荷与边界条件', 'NumberTitle', 'off');
clf; hold on;

% --- 1) 体素模式：实体区域按方块显示，各子域分别着色（参考 display_3D.m） ---
solid = x > 0.5;   % 实体单元 (nely, nelx, nelz)，第1维=y，第2维=x，第3维=z
% 各区域互斥（应力子域 > 冻结区 > 其余实体），逐块绘制以便图例区分
patch_list = { ...
    solid & ind_stress_TO,                    [1.00 0.55 0.10], 1.0, '应力子域 (ind_stress_TO)'; ...
    solid & freezeSolid & ~ind_stress_TO,     [0.20 0.80 0.20], 1.0, '冻结区 (freezeSolid)'; ...
    solid & ~freezeSolid & ~ind_stress_TO,    [0.62 0.62 0.62], 1.0, '实体区域'};
for ri = 1:size(patch_list, 1)
    if nnz(patch_list{ri, 1}) == 0
        continue; % 空区域不绘制
    end
    [Vp, Fp, ~] = buildVoxelFaces(patch_list{ri, 1});
    if ~isempty(Vp)
        patch('Faces', Fp, 'Vertices', Vp, ...
              'FaceColor', patch_list{ri, 2}, 'FaceAlpha', patch_list{ri, 3}, ...
              'EdgeColor', [0 0 0], 'LineWidth', 0.05, ...
              'DisplayName', patch_list{ri, 4});
    end
end

% --- 1b) 非设计区（空腔）以半透明蓝色体素壳显示 ---
if nnz(nonDesign) > 0
    [Vn, Fn, ~] = buildVoxelFaces(nonDesign);
    if ~isempty(Vn)
        patch('Faces', Fn, 'Vertices', Vn, ...
              'FaceColor', [0.00 0.45 1.00], 'FaceAlpha', 0.25, ...
              'EdgeColor', 'none', 'DisplayName', '非设计区 (nonDesign)');
    end
end

% --- 2) 固定节点（统一蓝色，与红色载荷点区分即可） ---
scatter3(fx, fy, fz, 18, [0.10 0.30 0.85], 'filled', 'DisplayName', '固定边界 (Fixed BC)');

% --- 3) 载荷节点：红色圆点 + 数值标注 + 数值上方悬浮方向箭头 ---
if ~isempty(load_node)
    scatter3(nodeX(load_node), nodeY(load_node), nodeZ(load_node), 40, ...
             [1 0 0], 'filled', 'DisplayName', ...
             sprintf('分布载荷 F = %.0f N', abs(total_force)));
    % 每个载荷节点旁标注力值；数值上方再悬浮一个短箭头标示力的方向（长度固定、不随力值缩放）
    dir_len = 1.5;   % 方向箭头长度（仅标示方向）
    for k = 1:numel(load_node)
        text(nodeX(load_node(k)) + 1.5, nodeY(load_node(k)), ...
             nodeZ(load_node(k)), sprintf('%.0f', F_vals(k)), ...
             'FontSize', 8, 'Color', [0.85 0 0], 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'left', 'HandleVisibility', 'off');
        % 方向由自由度方向 + 力的正负决定（本例为 y 方向）
        dv = zeros(1, 3);
        dv(load_dir(k)) = sign(F_vals(k)) * dir_len;
        quiver3(nodeX(load_node(k)) + 1.5, nodeY(load_node(k)) + 1.2, ...
                nodeZ(load_node(k)), dv(1), dv(2), dv(3), 0, ...
                'Color', [0.85 0 0], 'LineWidth', 1.4, 'MaxHeadSize', 1.2, 'HandleVisibility', 'off');
    end
end

% --- 图例与视图 ---
legend('Location', 'northeastoutside');
axis equal; grid on;

% --- 自适应观察视角：相机参数按模型尺寸缩放，任意网格大小均适用 ---
model_diag = norm([nelx, nely, nelz]);        % 模型对角线长度
cam_dir    = [0.39489, -0.30713, -0.86587];   % 观察方向（单位向量，由原视角导出）
cam_dist   = 6.9125 * model_diag;             % 相机距离 = 6.91 × 模型对角线
cam_tgt    = [0.28245, 0.53221, 0.93814] .* [nelx, nely, nelz]; % 目标点（保持原取景相对位置）
hAxes = gca;
hAxes.CameraTarget    = cam_tgt;
hAxes.CameraPosition  = hAxes.CameraTarget + cam_dist * cam_dir;
hAxes.CameraUpVector  = [0, -1, 0];                        % 相机"上"方向
hAxes.CameraViewAngle = 6.9587;                            % 视场角（缩放）
hAxes.Projection      = 'orthographic';                    % 正交投影

xlabel('x (节点)'); ylabel('y (节点)'); zlabel('z (节点)');
hold off;

%% ====== 输出信息到控制台 ======
fprintf('========== 三维模型验证 ==========\n');
fprintf('网格: %d x %d x %d\n', nelx, nely, nelz);
fprintf('单元总数: %d\n', nelx * nely * nelz);
fprintf('总自由度数: %d\n', ndof);

fprintf('\n--- 区域统计 ---\n');
tot_elems = nelx * nely * nelz;
region_stats = {'非设计区 (nonDesign)',     nonDesign; ...
                '冻结区   (freezeSolid)',   freezeSolid; ...
                '应力子域 (ind_stress_TO)', ind_stress_TO};
for ri = 1:size(region_stats, 1)
    cnt = nnz(region_stats{ri, 2});
    fprintf('%-26s: %6d 单元 (%.2f%%)\n', region_stats{ri, 1}, cnt, 100 * cnt / tot_elems);
end

fprintf('\n--- 载荷 ---\n');
dir_names = {'x', 'y', 'z'};
for d = 1:3
    if any(load_dir == d)
        fprintf('方向 %s: %d 节点\n', dir_names{d}, sum(load_dir == d));
    end
end
fprintf('总合力: %.1f N\n', total_force);
fprintf('各节点力值: ');
fprintf('%.1f ', F_vals);
fprintf('\n\n--- 边界条件 ---\n');
if n_top > 0,    fprintf('顶面固定(y=1):      %d 节点\n', n_top); end
if n_bottom > 0, fprintf('底面固定(y=nely+1): %d 节点\n', n_bottom); end
if n_left > 0,   fprintf('左面固定(x=1):      %d 节点\n', n_left); end
if n_right > 0,  fprintf('右面固定(x=nelx+1): %d 节点\n', n_right); end
if n_front > 0,  fprintf('前面固定(z=1):      %d 节点\n', n_front); end
if n_back > 0,   fprintf('后面固定(z=nelz+1): %d 节点\n', n_back); end
fprintf('总固定自由度: %d\n', length(fixed_dofs_list));
fprintf('=====================================\n');

%% ====== 局部函数：体素网格构建（坐标与节点网格一致：x=列, y=行, z=层） ======
function [V, F, cid] = buildVoxelFaces(mask)
% BUILDVOXELFACES 体素模式：仅构建所有暴露面的顶点与连接。
%   mask : 逻辑数组 (nely, nelx, nelz)，第1维=y，第2维=x，第3维=z
%   V    : 顶点坐标 (x, y, z)，第 k 层单元左上角位于 (i-1, j-1, k-1)
%   F    : 面连接（四边形）
%   cid  : 每个面对应的单元线性索引（供逐面着色）
% 参考 display_3D.m 的 buildFaces，但使用与节点网格一致的显示坐标（不翻转轴）。

pady = false(size(mask) + [2 0 0]); pady(2:end-1,:,:) = mask;
padx = false(size(mask) + [0 2 0]); padx(:,2:end-1,:) = mask;
padz = false(size(mask) + [0 0 2]); padz(:,:,2:end-1) = mask;
m_jm = mask & ~pady(1:end-2,:,:);   % 面 y=0 (j-1 侧)
m_jp = mask & ~pady(3:end,:,:);     % 面 y=1 (j+1 侧)
m_im = mask & ~padx(:,1:end-2,:);   % 面 x=0 (i-1 侧)
m_ip = mask & ~padx(:,3:end,:);     % 面 x=1 (i+1 侧)
m_km = mask & ~padz(:,:,1:end-2);   % 面 z=0 (k-1 侧)
m_kp = mask & ~padz(:,:,3:end);     % 面 z=1 (k+1 侧)
offs = { ...
    [0 0 0; 0 1 0; 1 1 0; 1 0 0], ... % 面 z=0
    [0 0 0; 0 0 1; 1 0 1; 1 0 0], ... % 面 y=0
    [1 0 0; 1 0 1; 1 1 1; 1 1 0], ... % 面 x=1
    [0 1 0; 0 1 1; 1 1 1; 1 1 0], ... % 面 y=1
    [0 0 0; 0 0 1; 0 1 1; 0 1 0], ... % 面 x=0
    [0 0 1; 0 1 1; 1 1 1; 1 0 1] };   % 面 z=1
[V1,F1,id1] = buildVoxelFacesLocal(m_jm, offs{2});
[V2,F2,id2] = buildVoxelFacesLocal(m_jp, offs{4});
[V3,F3,id3] = buildVoxelFacesLocal(m_ip, offs{3});
[V4,F4,id4] = buildVoxelFacesLocal(m_im, offs{5});
[V5,F5,id5] = buildVoxelFacesLocal(m_km, offs{1});
[V6,F6,id6] = buildVoxelFacesLocal(m_kp, offs{6});
V = [V1; V2; V3; V4; V5; V6];
offV = cumsum([0, size(V1,1), size(V2,1), size(V3,1), size(V4,1), size(V5,1)]);
F = [F1 + offV(1); F2 + offV(2); F3 + offV(3); F4 + offV(4); F5 + offV(5); F6 + offV(6)];
cid = [id1; id2; id3; id4; id5; id6];
end

function [V, F, cid] = buildVoxelFacesLocal(mask, offs)
% 由暴露面掩码构建所有面：V 顶点、F 连接、cid 每面对应的单元线性索引。
% V 布局：前 n 行为所有面的第 1 个顶点，随后 n 行为第 2 个顶点，依此类推。
cid = find(mask(:));
n = numel(cid);
V = zeros(0, 3); F = zeros(0, 4);
if n == 0
    return;
end
[j, i, k] = ind2sub(size(mask), cid);
base = [i - 1, j - 1, k - 1];            % 单元基准角 (x, y, z)，与节点坐标一致
V = [base + offs(1, :); base + offs(2, :); base + offs(3, :); base + offs(4, :)];
F = repmat((1:n)', 1, 4) + (0:3) * n;    % 面连接（跨组索引）
end
