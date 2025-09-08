% ============== test.m (最终版 - 实现积分重建) ==============
clear; clc; close all;

% --- 1. 用户配置 ---
obs_filepath = '250622_062518_walkaround.obs'; 
nav_filepath = '250622_062518_walkaround.nav'; 
target_satellite_id = 'G20';

% ----------------------------------------------------

% --- 2. 解析文件 ---
fprintf('--> 正在解析观测文件: %s\n', obs_filepath);
obs_data = parse_rinex_obs_advanced(obs_filepath);
fprintf('--> 正在解析导航文件: %s\n', nav_filepath);
nav_data = parse_rinex_nav(nav_filepath);
fprintf('\n✅ 文件解析全部完成。\n\n');
epoch_range = 1:length(obs_data); 

% --- 3. 初始化变量 ---
num_epochs_to_process = length(epoch_range);
time_vector = NaT(1, num_epochs_to_process);
reconstructed_phase_vector = NaN(1, num_epochs_to_process);
valid_results_count = 0;
% 初始化用于积分的变量
accumulated_residual_phase = 0; % 累积的残余相位 (周)
last_epoch_time = NaT;          % 上一个历元的时间

% --- 4. 循环处理与积分 ---
fprintf('--> 开始循环处理 %d 个历元，目标卫星 %s ...\n', num_epochs_to_process, target_satellite_id);
for loop_idx = 1:num_epochs_to_process
    epoch_idx = epoch_range(loop_idx);
    current_time = obs_data(epoch_idx).time;

    try
        [receiver_pos, receiver_clk_err, sat_states] = calculate_receiver_position(obs_data, nav_data, epoch_idx);
        if ~isfield(sat_states, target_satellite_id), continue; end

        % --- 4a. 调用新函数，获取积分所需的“原材料” ---
        [residual_doppler, pr_phase_cycles] = calculate_gpsense_components(...
            obs_data(epoch_idx), target_satellite_id, sat_states, receiver_pos, receiver_clk_err);
        
        if isnan(residual_doppler) || isnan(pr_phase_cycles), continue; end

        % --- 4b. 执行积分（累加）---
        % 只有在不是第一个点的时候才进行积分
        if ~isnat(last_epoch_time)
            dt = seconds(current_time - last_epoch_time); % 计算时间间隔
            % 积分: 累积相位 = 上一时刻的累积相位 + 当前残余多普勒 × 时间间隔
            accumulated_residual_phase = accumulated_residual_phase + residual_doppler * dt;
        end
        
        % --- 4c. 合成最终相位 ---
        % 最终相位 = 伪距估计的相位(可看作初始相位) + 残余多普勒累积的相位
        % 这个结果的单位是 “周”
        total_phase_cycles = pr_phase_cycles + accumulated_residual_phase;

        % --- 4d. 存储结果 ---
        valid_results_count = valid_results_count + 1;
        time_vector(valid_results_count) = current_time;
        reconstructed_phase_vector(valid_results_count) = total_phase_cycles * (2 * pi); % 转换为弧度存储
        
        % 更新时间戳，为下一次积分做准备
        last_epoch_time = current_time;

        if mod(loop_idx, 50) == 0, fprintf('    已处理 %d / %d 个历元...\n', loop_idx, num_epochs_to_process); end
        
    catch ME
        fprintf('    在处理历元 %d 时发生错误: %s，跳过。\n', epoch_idx, ME.message);
        last_epoch_time = NaT; % 如果出错，重置时间戳，避免错误累积
        accumulated_residual_phase = 0; % 重置累加器
        continue;
    end
end
fprintf('--> 数据处理循环完成！\n\n');

% --- 5. 绘图 ---
time_vector = time_vector(1:valid_results_count);
reconstructed_phase_vector = reconstructed_phase_vector(1:valid_results_count);
if isempty(time_vector), error('未能计算出任何有效结果，无法绘图。'); end

figure('Name', sprintf('卫星 %s 基于积分法的重建相位', target_satellite_id), 'NumberTitle', 'off');
plot(time_vector, unwrap(reconstructed_phase_vector), 'r-');
title(sprintf('卫星 %s 基于积分法的重建相位', target_satellite_id));
xlabel('时间'); ylabel('重建相位 (弧度)'); grid on;
datetick('x', 'HH:MM:SS', 'keepticks', 'keeplimits');
fprintf('✅ 图形绘制完成！\n');