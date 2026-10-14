%% ====== show_model: 模型可视化与验证 ======
% 设计域函数需遵循统一输出格式:
%   [x, nonDesign, freezeSolid, ind_stress_TO, F, BC] = 函数名(nelx, nely, subD_size)
%
% 直接修改下行调用你的函数即可:

nelx = 270; nely = 400; subD_size = 1;
% [x, nonDesign, freezeSolid, ind_stress_TO, F, BC] = case_Tpier(nelx, nely, subD_size);
[x, nonDesign, freezeSolid, ind_stress_TO, F, BC] = case_Lbracket(nelx, nely, subD_size);

% --- 节点坐标 ---
nodeMat = reshape(1:(1+nelx)*(1+nely), nely + 1, nelx + 1);
[gridX, gridY] = meshgrid(0:nelx, 0:nely);
node_x_img = gridX + 0.5;  % 映射到图像坐标系
node_y_img = gridY + 0.5;
ndof = 2 * (nelx + 1) * (nely + 1);

% --- 提取载荷信息 ---
[load_dofs_idx, ~, F_vals] = find(F);
load_node_nums = floor((load_dofs_idx + 1) / 2);
load_dir = mod(load_dofs_idx, 2);  % 1 = x方向, 0 = y方向
load_node_y = mod(load_node_nums - 1, nely + 1) + 1;
load_node_x = floor((load_node_nums - 1) / (nely + 1)) + 1;
total_force = sum(F_vals);

% --- 提取边界条件信息 ---
fixed_dofs_list = BC(:, 1);
fixed_node_nums = floor((fixed_dofs_list + 1) / 2);
fixed_node_y = mod(fixed_node_nums - 1, nely + 1) + 1;
fixed_node_x = floor((fixed_node_nums - 1) / (nely + 1)) + 1;

% 统计各边界固定节点（去重）
unique_fixed_nodes = unique(fixed_node_nums);
uny = mod(unique_fixed_nodes - 1, nely + 1) + 1;
unx = floor((unique_fixed_nodes - 1) / (nely + 1)) + 1;
n_top    = sum(uny == 1);
n_bottom = sum(uny == nely + 1);
n_left   = sum(unx == 1);
n_right  = sum(unx == nelx + 1);

% 判断载荷主方向
is_y_load = (sum(load_dir == 0) >= sum(load_dir == 1));
is_x_load = ~is_y_load;

% 载荷方向描述与缩放
load_scale = 1.2;
if is_y_load
    dirLabel = 'y方向';
    % YDir='reverse': FE负y(向下) → 图像正y(向下)
    u_comp = zeros(sum(load_dir == 0), 1);
    v_comp = -F_vals(load_dir == 0) * load_scale;
else
    dirLabel = 'x方向';
    u_comp = F_vals(load_dir == 1) * load_scale;
    v_comp = zeros(sum(load_dir == 1), 1);
end

%% ====== 设计域分区标签 (nonDesign / freezeSolid / ind_stress_TO) ======
% 构建分区标签矩阵: 1=非设计区域, 2=冻结实体, 3=应力优化子域, 4=可设计实体, 5=可设计挖空
regionMap = ones(nely, nelx) * 4;            % 默认: 可设计实体
regionMap(x == 0 & ~nonDesign) = 5;          % 可设计挖空 (当前为0但可被优化)
regionMap(ind_stress_TO) = 3;                % 应力优化子域
regionMap(freezeSolid) = 2;                  % 冻结实体
regionMap(nonDesign) = 1;                    % 非设计区域 (最后赋值, 优先级最高)

regionColors = [1.00 0.85 0.85; ...   % 1 非设计区域 (浅红)
                0.80 0.90 1.00; ...   % 2 冻结实体 (浅蓝)
                1.00 0.90 0.60; ...   % 3 应力优化子域 (浅黄)
                0.35 0.35 0.35; ...   % 4 可设计实体 (深灰)
                0.92 0.92 0.92];      % 5 可设计挖空 (浅灰)

regionLabels = {'非设计区域 (nonDesign)', '冻结实体 (freezeSolid)', ...
                '应力优化子域 (ind_stress_TO)', '可设计实体', '可设计挖空'};

%% ====== 绘图 ======
figure('Name', '模型 — 载荷、边界条件与设计域分区', 'NumberTitle', 'off', ...
       'Position', [100, 100, 550, 900]);
clf;

imagesc(1:nelx, 1:nely, regionMap);
colormap(gca, regionColors);
set(gca, 'CLim', [0.5, 5.5]);
hold on;
set(gca, 'YDir', 'reverse');
axis equal;
set(gca, 'XLim', [0, nelx + 1]);
set(gca, 'YLim', [0, nely + 1]);
xlabel('x (节点)');
ylabel('y (节点)');

% --- 边界条件 ---
if n_top > 0
    top_fixed = (fixed_node_y == 1);
    top_idx = sub2ind(size(node_x_img), fixed_node_y(top_fixed), fixed_node_x(top_fixed));
    plot(node_x_img(top_idx), node_y_img(top_idx), ...
         's', 'Color', [0.8 0.1 0.1], 'MarkerSize', 5, 'MarkerFaceColor', [0.8 0.1 0.1], ...
         'DisplayName', '上边界固定');
end
if n_bottom > 0
    bottom_fixed = (fixed_node_y == nely + 1);
    bot_idx = sub2ind(size(node_x_img), fixed_node_y(bottom_fixed), fixed_node_x(bottom_fixed));
    plot(node_x_img(bot_idx), node_y_img(bot_idx), ...
         'd', 'Color', [0.1 0.3 0.8], 'MarkerSize', 5, 'MarkerFaceColor', [0.1 0.3 0.8], ...
         'DisplayName', '下边界固定');
end
if n_left > 0
    left_fixed = (fixed_node_x == 1);
    lft_idx = sub2ind(size(node_x_img), fixed_node_y(left_fixed), fixed_node_x(left_fixed));
    plot(node_x_img(lft_idx), node_y_img(lft_idx), ...
         '^', 'Color', [0.1 0.7 0.1], 'MarkerSize', 5, 'MarkerFaceColor', [0.1 0.7 0.1], ...
         'DisplayName', '左边界固定');
end
if n_right > 0
    right_fixed = (fixed_node_x == nelx + 1);
    rgt_idx = sub2ind(size(node_x_img), fixed_node_y(right_fixed), fixed_node_x(right_fixed));
    plot(node_x_img(rgt_idx), node_y_img(rgt_idx), ...
         'v', 'Color', [0.7 0.5 0.1], 'MarkerSize', 5, 'MarkerFaceColor', [0.7 0.5 0.1], ...
         'DisplayName', '右边界固定');
end

% --- 载荷 ---
if is_y_load
    lx = node_x_img(sub2ind(size(node_x_img), load_node_y(load_dir == 0), load_node_x(load_dir == 0)));
    ly = node_y_img(sub2ind(size(node_x_img), load_node_y(load_dir == 0), load_node_x(load_dir == 0)));
    quiver(lx, ly, u_comp, v_comp, 0, ...
           'r-', 'LineWidth', 2.0, 'MaxHeadSize', 0.6, ...
           'DisplayName', sprintf('分布载荷 F = %.0fN', abs(total_force)));
    % 总合力标注在箭头末端
    text(mean(lx), max(ly + v_comp) + 10, ...
         sprintf('%.0fN', abs(total_force)), ...
         'FontSize', 12, 'Color', 'r', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
else
    lx = node_x_img(sub2ind(size(node_x_img), load_node_y(load_dir == 1), load_node_x(load_dir == 1)));
    ly = node_y_img(sub2ind(size(node_x_img), load_node_y(load_dir == 1), load_node_x(load_dir == 1)));
    quiver(lx, ly, u_comp, v_comp, 0, ...
           'r-', 'LineWidth', 2.0, 'MaxHeadSize', 0.6, ...
           'DisplayName', sprintf('分布载荷 F = %.0fN', abs(total_force)));
    text(mean(lx + u_comp) + 10, mean(ly), ...
         sprintf('%.0fN', abs(total_force)), ...
         'FontSize', 12, 'Color', 'r', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
end

% --- 图例 ---
for k = 1:5
    plot(nan, nan, 's', 'Color', regionColors(k, :), ...
         'MarkerFaceColor', regionColors(k, :), 'MarkerSize', 8, ...
         'DisplayName', regionLabels{k});
end
legend('Location', 'northeast');
hold off;

%% ====== 输出信息到控制台 ======
fprintf('========== 模型验证 ==========\n');
fprintf('网格: %d x %d\n', nelx, nely);
fprintf('总自由度数: %d\n', ndof);
fprintf('\n--- 载荷 ---\n');
fprintf('方向: %s, 总合力: %.1f N\n', dirLabel, total_force);
fprintf('施加节点数: %d\n', sum(load_dir == (is_y_load * 0 + is_x_load * 1)));
fprintf('各节点力值: ');
fprintf('%.1f ', F_vals);
fprintf('\n\n--- 边界条件 ---\n');
if n_top > 0,    fprintf('上边界固定: %d 节点\n', n_top); end
if n_bottom > 0, fprintf('下边界固定: %d 节点\n', n_bottom); end
if n_left > 0,   fprintf('左边界固定: %d 节点\n', n_left); end
if n_right > 0,  fprintf('右边界固定: %d 节点\n', n_right); end
fprintf('总固定自由度: %d\n', length(fixed_dofs_list));
fprintf('\n--- 设计域分区验证 ---\n');
n_tot = nelx * nely;
n_nd = nnz(nonDesign); n_fz = nnz(freezeSolid); n_st = nnz(ind_stress_TO);
fprintf('非设计区域   nonDesign    : %6d 单元 (%.2f%%)\n', n_nd, n_nd / n_tot * 100);
fprintf('冻结实体     freezeSolid  : %6d 单元 (%.2f%%)\n', n_fz, n_fz / n_tot * 100);
fprintf('应力优化子域 ind_stress_TO: %6d 单元 (%.2f%%)\n', n_st, n_st / n_tot * 100);

% 尺寸一致性
if isequal(size(nonDesign), [nely, nelx]) && ...
   isequal(size(freezeSolid), [nely, nelx]) && ...
   isequal(size(ind_stress_TO), [nely, nelx])
    fprintf('尺寸: 三者均与网格 [%d x %d] 一致 ✓\n', nely, nelx);
else
    fprintf('尺寸: 存在不一致 ✗ (nonDesign:%s freezeSolid:%s ind_stress_TO:%s)\n', ...
        mat2str(size(nonDesign)), mat2str(size(freezeSolid)), mat2str(size(ind_stress_TO)));
end

% 设计变量一致性 (用例中由 x 的赋值保证)
if all(x(nonDesign) == 0),  fprintf('非设计区域 x=0: ✓\n');
else, fprintf('非设计区域 x=0: ✗ (存在 %d 个非零单元)\n', nnz(x(nonDesign))); end
if all(x(freezeSolid) == 1), fprintf('冻结区域 x=1: ✓\n');
else, fprintf('冻结区域 x=1: ✗ (存在 %d 个非1单元)\n', nnz(x(freezeSolid) ~= 1)); end

% 区域互斥性
ov_ndfz = nnz(nonDesign & freezeSolid);
ov_stnd = nnz(ind_stress_TO & nonDesign);
ov_stfz = nnz(ind_stress_TO & freezeSolid);
if ov_ndfz == 0 && ov_stnd == 0 && ov_stfz == 0
    fprintf('区域互斥: nonDesign / freezeSolid / ind_stress_TO 互不重叠 ✓\n');
else
    fprintf('区域互斥: ✗ (非设计∩冻结=%d, 应力子域∩非设计=%d, 应力子域∩冻结=%d)\n', ...
        ov_ndfz, ov_stnd, ov_stfz);
end

% 应力优化子域非空警告
if n_st == 0
    fprintf('警告: ind_stress_TO 为空, 应力优化将不会生效!\n');
end
fprintf('=====================================\n');
