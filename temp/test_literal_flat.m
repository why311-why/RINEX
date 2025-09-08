% ============== 主脚本 (字面法 + 最终去趋势处理) ==============
clear; clc; close all;

% --- 1. 用户配置 ---
obs_filepath = '250622_063322_1434_1437_30walkarounds3.obs';
nav_filepath = '250622_063322_1434_1437_30walkarounds3.nav';
target_satellite_id = 'G20';
epoch_range = 1:1000;

% --- 2. 文件解析 ---
fprintf('--> 解析 RINEX 文件...\n');
obs_data = parse_rinex_obs_advanced(obs_filepath);
nav_data = parse_rinex_nav(nav_filepath);
fprintf('✅ 文件解析完成。\n\n');

% --- 3. 初始化变量 ---
num_epochs_to_process = length(epoch_range);
time_vector = NaT(1, num_epochs_to_process);
phase_vector_rad = NaN(1, num_epochs_to_process); % 用于存储带趋势的结果
valid_count = 0;
if isempty(epoch_range) || epoch_range(1) > length(obs_data), error('历元范围无效或观测数据为空。'); end
t0 = obs_data(epoch_range(1)).time;

% 为手动微分初始化“记忆”变量
last_L1C = NaN;
last_t_obs = NaT;

% --- 4. 循环处理每个历元 ---
fprintf('--> 开始处理历元 (dΦ/dt 通过手动微分计算)...\n');
for i = 1:num_epochs_to_process
    epoch_idx = epoch_range(i);
    try
        current_epoch = obs_data(epoch_idx);
        t_obs = current_epoch.time;
        t_elapsed = seconds(t_obs - t0);

        % 定位 & 获取卫星状态
        [receiver_pos, receiver_clk_err, sat_states] = ...
            calculate_receiver_position(obs_data, nav_data, epoch_idx);

        % 检查数据
        if ~isfield(current_epoch.data, target_satellite_id) || ~isfield(sat_states, target_satellite_id), continue; end
        current_L1C = current_epoch.data.(target_satellite_id).carrier_phase.L1C;
        P_raw = current_epoch.data.(target_satellite_id).pseudorange.C1C;
        if isnan(current_L1C) || isnan(P_raw), continue; end

        % 手动计算 dΦ/dt
        dPhi_dt = NaN;
        if ~isnat(last_t_obs) && ~isnan(last_L1C)
            dt = seconds(t_obs - last_t_obs);
            if dt > 1e-6, dPhi_dt = (current_L1C - last_L1C) / dt; end
        end
        last_L1C = current_L1C;
        last_t_obs = t_obs;
        if isnan(dPhi_dt), continue; end

        % 调用函数计算瞬时相位（带趋势）
        recon_phase_rad = reconstruct_gpsense_phase_literal(dPhi_dt, ...
            P_raw, sat_states.(target_satellite_id), receiver_pos, receiver_clk_err, t_elapsed);
        
        if isnan(recon_phase_rad), continue; end

        % 存储结果
        valid_count = valid_count + 1;
        time_vector(valid_count) = t_obs;
        phase_vector_rad(valid_count) = recon_phase_rad; % 存储带趋势的结果

    catch ME
        fprintf('    处理历元 %d 时发生错误: %s\n', epoch_idx, ME.message);
        last_L1C = NaN; last_t_obs = NaT;
        continue;
    end
end
fprintf('--> 处理完成，共获得 %d 个有效数据点。\n\n', valid_count);

% --- 5. 数据修剪、去趋势与最终绘图 ---
time_vector = time_vector(1:valid_count);
phase_vector_rad = phase_vector_rad(1:valid_count);
if isempty(time_vector), error('未能计算出任何有效数据点，无法绘图。'); end

% 【核心去趋势步骤】
unwrapped_phase = unwrap(phase_vector_rad);
window_size = 25; % 1秒平滑窗口 (假设25Hz采样率)
trend = movmean(unwrapped_phase, window_size);
detrended_phase_rad = unwrapped_phase - trend;

% --- 最终绘图 ---
figure('Name', sprintf('字面法去趋势结果 | 卫星 %s', target_satellite_id), 'NumberTitle', 'off');
plot(time_vector, detrended_phase_rad, 'r-');
title(sprintf('字面公式法 + 去趋势处理\n卫星: %s', target_satellite_id));
xlabel('时间'); 
ylabel('去趋势相位 (弧度)');
grid on;
datetick('x', 'HH:MM:SS', 'keepticks', 'keeplimits');

fprintf('✅ 图形绘制完成。\n');