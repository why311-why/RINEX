% ============== 主脚本 (最终版：调用覆盖后的函数) ==============
clear; clc; close all;

% --- 1. 用户配置 ---
obs_filepath = '250622_063322_1434_1437_30walkarounds3.obs';
nav_filepath = '250622_063322_1434_1437_30walkarounds3.nav';
target_satellite_id = 'G20';
epoch_range = 1:1000;

% --- 2. 文件解析 ---
fprintf('--> 解析 RINEX 观测文件: %s\n', obs_filepath);
obs_data = parse_rinex_obs_advanced(obs_filepath);
fprintf('--> 解析 RINEX 导航文件: %s\n', nav_filepath);
nav_data = parse_rinex_nav(nav_filepath);
fprintf('✅ 文件解析完成。\n\n');

% --- 3. 初始化变量 ---
num_epochs_to_process = length(epoch_range);
time_vector = NaT(1, num_epochs_to_process);
recon_phase_vector = NaN(1, num_epochs_to_process);
valid_count = 0;
if isempty(epoch_range) || epoch_range(1) > length(obs_data), error('历元范围无效或观测数据为空。'); end
t0 = obs_data(epoch_range(1)).time;

% 为手动微分初始化“记忆”变量
last_L1C = NaN;
last_t_obs = NaT;

% --- 4. 循环处理每个历元 ---
fprintf('--> 开始处理历元 (dΦ/dt 通过对L1C手动微分计算)...\n');
for i = 1:num_epochs_to_process
    epoch_idx = epoch_range(i);

    try
        current_epoch = obs_data(epoch_idx);
        t_obs = current_epoch.time;
        t_elapsed = seconds(t_obs - t0);

        % 步骤 A: 定位 & 获取卫星状态
        [receiver_pos, receiver_clk_err, sat_states] = ...
            calculate_receiver_position(obs_data, nav_data, epoch_idx);

        % 步骤 B: 检查数据
        if ~isfield(current_epoch.data, target_satellite_id) || ~isfield(sat_states, target_satellite_id)
            continue;
        end
        current_L1C = current_epoch.data.(target_satellite_id).carrier_phase.L1C;
        P_raw = current_epoch.data.(target_satellite_id).pseudorange.C1C;
        if isnan(current_L1C) || isnan(P_raw), continue; end

        % 步骤 C: 手动计算 dΦ/dt
        dPhi_dt = NaN;
        if ~isnat(last_t_obs) && ~isnan(last_L1C)
            dt = seconds(t_obs - last_t_obs);
            if dt > 1e-6
                dPhi_dt = (current_L1C - last_L1C) / dt;
            end
        end
        last_L1C = current_L1C;
        last_t_obs = t_obs;
        if isnan(dPhi_dt), continue; end

        % 步骤 D: 调用被覆盖的重建函数
        recon_phase_rad = reconstruct_gpsense_phase_literal(dPhi_dt, ...
            P_raw, sat_states.(target_satellite_id), receiver_pos, receiver_clk_err, t_elapsed);
        
        if isnan(recon_phase_rad), continue; end

        % 步骤 E: 存储结果
        valid_count = valid_count + 1;
        time_vector(valid_count) = t_obs;
        recon_phase_vector(valid_count) = recon_phase_rad;

        if mod(i, 50) == 0
            fprintf('    已处理 %d / %d 个历元...\n', i, num_epochs_to_process);
        end

    catch ME
        fprintf('    处理历元 %d 时发生严重错误: %s，跳过。\n', epoch_idx, ME.message);
        last_L1C = NaN;
        last_t_obs = NaT;
        continue;
    end
end
fprintf('--> 处理完成，共获得 %d 个有效数据点。\n\n', valid_count);

% --- 5. 绘图 ---
if valid_count == 0, error('未能计算出任何有效数据点，无法绘图。'); end
time_vector = time_vector(1:valid_count);
recon_phase_vector = recon_phase_vector(1:valid_count);
figure('Name', sprintf('GPSense 重建 | 卫星 %s | dΦ/dt by L1C diff', target_satellite_id), 'NumberTitle', 'off');
plot(time_vector, unwrap(recon_phase_vector), 'r-');
title(sprintf('严格字面公式重建 (dΦ/dt 通过对 L1C 手动微分)\n卫星: %s', target_satellite_id));
xlabel('时间'); ylabel('重建相位 (弧度)'); grid on;
datetick('x','HH:MM:SS','keepticks');
fprintf('✅ 绘图完成。\n');