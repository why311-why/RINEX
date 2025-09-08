function plot_reconstructed_signals(obs_data, nav_data, target_satellite_id, epoch_range)
% PLOT_RECONSTRUCTED_SIGNALS
% 重建并绘制指定卫星的伪距与载波相位（支持 'gpsense' 方法）。
%
% 输入参数:
%   obs_data             - parse_rinex_obs_advanced 得到的观测数据结构体
%   nav_data             - parse_rinex_nav 得到的导航数据结构体
%   target_satellite_id  - 目标卫星 (例如 'G10')
%   epoch_range          - 要处理的历元索引范围（例如 1:1000），可选
%
% 调用依赖: calculate_receiver_position, reconstruct_gps_signals

% ---------- 1. 参数检查与默认处理 ----------
if nargin < 4 || isempty(epoch_range)
    epoch_range = 1:length(obs_data);
end

% ---------- 2. 初始化变量 ----------
c = 299792458.0;                     % 光速 (m/s)
lambda_L1 = c / 1575.42e6;           % L1载波波长 (m)
reconstruction_method = 'gpsense';  % 使用 gpsense 模型

num_epochs_to_process = length(epoch_range);
time_vector = NaT(1, num_epochs_to_process);
reconstructed_pr_vector = NaN(1, num_epochs_to_process);
reconstructed_ph_rad_vector = NaN(1, num_epochs_to_process);
valid_results_count = 0;

fprintf('--> 开始处理 %d 个历元，目标卫星: %s\n', num_epochs_to_process, target_satellite_id);

% ---------- 3. 遍历历元处理 ----------
for i = 1:num_epochs_to_process
    epoch_idx = epoch_range(i);

    try
        % --- 接收机定位 ---
        [receiver_pos, receiver_clk_err, sat_states] = ...
            calculate_receiver_position(obs_data, nav_data, epoch_idx);

        % --- 检查该历元中是否包含目标卫星 ---
        if ~isfield(sat_states, target_satellite_id), continue; end

        % --- 信号重建 ---
        [recon_pr, recon_ph] = reconstruct_gps_signals(reconstruction_method, ...
            obs_data(epoch_idx), target_satellite_id, sat_states, receiver_pos, receiver_clk_err);

        if isnan(recon_pr) || isnan(recon_ph), continue; end

        % --- 存储结果（注：gpsense 模式下 recon_ph 已是弧度） ---
        valid_results_count = valid_results_count + 1;
        time_vector(valid_results_count) = obs_data(epoch_idx).time;
        reconstructed_pr_vector(valid_results_count) = recon_pr;
        reconstructed_ph_rad_vector(valid_results_count) = recon_ph;

        if mod(i, 50) == 0
            fprintf('    已处理 %d / %d 个历元...\n', i, num_epochs_to_process);
        end

    catch ME
        fprintf('    历元 %d 处理失败: %s，跳过。\n', epoch_idx, ME.message);
        continue;
    end
end

fprintf('--> 历元处理完成，共 %d 个有效数据点。\n', valid_results_count);

% ---------- 4. 数据修剪与绘图 ----------
if valid_results_count == 0
    error('未获得任何有效数据点，无法绘图。');
end

time_vector = time_vector(1:valid_results_count);
reconstructed_pr_vector = reconstructed_pr_vector(1:valid_results_count);
reconstructed_ph_rad_vector = reconstructed_ph_rad_vector(1:valid_results_count);

figure('Name', sprintf('卫星 %s 的重建信号 (gpsense 方法)', target_satellite_id));

subplot(2, 1, 1);
plot(time_vector, reconstructed_pr_vector, 'b-');
title(sprintf('卫星 %s 重建后的伪距', target_satellite_id));
xlabel('时间'); ylabel('重建伪距 (米)'); grid on;
datetick('x', 'HH:MM:SS', 'keepticks');

subplot(2, 1, 2);
plot(time_vector, unwrap(reconstructed_ph_rad_vector), 'r-');
title(sprintf('卫星 %s 重建后的载波相位 (已展开)', target_satellite_id));
xlabel('时间'); ylabel('重建相位 (弧度)'); grid on;
datetick('x', 'HH:MM:SS', 'keepticks');

fprintf('✅ 图形绘制完成。\n');
end
