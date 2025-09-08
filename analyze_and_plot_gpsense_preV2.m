% ============== analyze_and_plot_gpsense_preV2.m (最终确认版 - 适配GPS+北斗) ==============
function [time_vector, detrended_phase_rad, processed_pr_vector, amplitude_vector] = analyze_and_plot_gpsense_preV2(obs_data, nav_data, target_satellite_id, epoch_range)
% ANALYZE_AND_PLOT_GPSENSE - 最终版本，支持GPS和北斗，采用多项式和带通滤波处理。

% --- 1. 参数检查与初始化 ---
if nargin < 3, error('请提供目标卫星ID。'); end
if nargin < 4 || isempty(epoch_range), epoch_range = 1:length(obs_data); end

% --- 物理常数 ---
c = 299792458.0;
f_GPS_L1 = 1575.42e6;
f_BDS_B1I = 1561.098e6;
lambda_GPS_L1 = c / f_GPS_L1;
lambda_BDS_B1I = c / f_BDS_B1I;
k_boltzmann = 1.380649e-23;
T_noise_kelvin = 290.0;
Pn_noise_power = k_boltzmann * T_noise_kelvin;

% --- 初始化结果存储向量 ---
num_epochs_to_process = length(epoch_range);
time_vector = NaT(1, num_epochs_to_process);
phase_vector_rad = NaN(1, num_epochs_to_process);
processed_pr_vector = NaN(1, num_epochs_to_process);
amplitude_vector = NaN(1, num_epochs_to_process);
clock_corrected_pr_vector = NaN(1, num_epochs_to_process);
valid_results_count = 0;
initial_phase_anchor_cycles = NaN;
accumulated_residual_phase = 0;
last_epoch_time = NaT;

fprintf('--> 开始GPSense分析流程，历元范围 %d-%d，目标卫星 %s ...\n', epoch_range(1), epoch_range(end), target_satellite_id);

% ====================【请确认此段代码已正确应用】====================
% 根据卫星ID的第一个字母，动态确定要使用的观测码和波长
sys_char = upper(target_satellite_id(1));
if sys_char == 'G'
    pr_code = 'C1C'; dop_code = 'D1C'; snr_code = 'S1C';
    lambda = lambda_GPS_L1;
elseif sys_char == 'C'
    pr_code = 'C2I'; dop_code = 'D2I'; snr_code = 'S2I'; % 根据您的诊断结果，这些是正确的
    lambda = lambda_BDS_B1I;
else
    error('不支持的卫星系统: %s。目前只支持 GPS (G) 和 BeiDou (C)。', target_satellite_id);
end
% ===========================================================================

% --- 2. 遍历历元 ---
for loop_idx = 1:num_epochs_to_process
    epoch_idx = epoch_range(loop_idx);
    current_time = obs_data(epoch_idx).time;
    try
        [receiver_pos, receiver_clk_err, sat_states] = ...
            calculate_receiver_position(obs_data, nav_data, epoch_idx);
        
        if isempty(receiver_pos) || any(isnan(receiver_pos)), continue; end
        if ~isfield(sat_states, target_satellite_id), continue; end
        
        sat_obs = obs_data(epoch_idx).data.(target_satellite_id);
        
        % ====================【请确认此段代码已正确应用】====================
        % 使用动态确定的观测码来检查和提取数据
        if ~(isfield(sat_obs, 'pseudorange') && isfield(sat_obs.pseudorange, pr_code) && ...
             isfield(sat_obs, 'doppler') && isfield(sat_obs.doppler, dop_code) && ...
             isfield(sat_obs, 'snr') && isfield(sat_obs.snr, snr_code))
            continue;
        end
        
        P_raw = sat_obs.pseudorange.(pr_code);
        measured_doppler = sat_obs.doppler.(dop_code);
        cn0_dbhz = sat_obs.snr.(snr_code);
        % ===========================================================================

        if isnan(P_raw) || isnan(measured_doppler) || isnan(cn0_dbhz), continue; end
        
        current_amplitude = sqrt(Pn_noise_power * 10^(cn0_dbhz / 10));
        
        sat_state = sat_states.(target_satellite_id);
        sat_pos = sat_state.position;
        sat_vel = sat_state.velocity;
        sat_clk_err = sat_state.clock_error;
        
        geom_range = norm(sat_pos - receiver_pos);
        clock_corrected_pr = P_raw - c * (receiver_clk_err - sat_clk_err);
        processed_pr = clock_corrected_pr - geom_range;
        
        los_vec = (sat_pos - receiver_pos) / norm(sat_pos - receiver_pos);
        fD_geometric = -(sat_vel' * los_vec) / lambda;
        residual_doppler = measured_doppler - fD_geometric;
        
        if isnan(initial_phase_anchor_cycles)
            initial_phase_anchor_cycles = (P_raw - c * (receiver_clk_err - sat_clk_err)) / lambda;
            accumulated_residual_phase = 0;
        end
        
        if ~isnat(last_epoch_time)
            dt = seconds(current_time - last_epoch_time);
            accumulated_residual_phase = accumulated_residual_phase + residual_doppler * dt;
        end
        total_phase_cycles = initial_phase_anchor_cycles + accumulated_residual_phase;
        
        valid_results_count = valid_results_count + 1;
        time_vector(valid_results_count) = current_time;
        phase_vector_rad(valid_results_count) = total_phase_cycles * (2 * pi);
        processed_pr_vector(valid_results_count) = processed_pr;
        amplitude_vector(valid_results_count) = current_amplitude;
        clock_corrected_pr_vector(valid_results_count) = clock_corrected_pr;
        
        last_epoch_time = current_time;
    catch ME
        % fprintf('在处理历元 %d 时发生错误: %s\n', epoch_idx, ME.message);
    end
end
fprintf('--> 数据处理循环完成！\n\n');

% --- 3. 数据修剪与绘图 ---
if valid_results_count == 0
    error('未能计算出任何有效结果。');
end


time_vector = time_vector(1:valid_results_count);
phase_vector_rad = phase_vector_rad(1:valid_results_count);
processed_pr_vector = processed_pr_vector(1:valid_results_count);
amplitude_vector = amplitude_vector(1:valid_results_count);
clock_corrected_pr_vector = clock_corrected_pr_vector(1:valid_results_count);
if isempty(time_vector), error('未能计算出任何有效结果。'); end

fprintf('--> 转换时间坐标为北京时间...\n');
time_vector_cst = time_vector - seconds(18) + hours(8);

% 绘制复现论文图2(b)的伪距图
time_numeric = seconds(time_vector - time_vector(1));
p_coeffs = polyfit(time_numeric', clock_corrected_pr_vector, 2);
orbital_trend = polyval(p_coeffs, time_numeric);
processed_pr_fig2b_style = clock_corrected_pr_vector - orbital_trend;
figure('Name', sprintf('卫星 %s - 处理后的伪距 (论文图2b)', target_satellite_id), 'NumberTitle', 'off');
plot(time_vector_cst, processed_pr_fig2b_style, 'LineWidth', 1.5);
title(sprintf('卫星 %s - 处理后的伪距', target_satellite_id));
xlabel('时间 (北京时间)');
ylabel('Processed Pseudorange (m)');
grid on;
datetick('x', 'HH:MM:SS', 'keepticks', 'keeplimits');

% ====================【核心修改：恢复为滑动平均去趋势】====================
% 绘制滑动平均去趋势后的相位
unwrapped_phase = unwrap(phase_vector_rad);

% 定义滑动平均窗口大小
window_size = 25; 
trend = movmean(unwrapped_phase, window_size, 'omitnan');

% 从原始展开相位中减去趋势
detrended_phase_rad = unwrapped_phase - trend;

figure('Name', sprintf('卫星 %s - 去趋势后的GPSense相位', target_satellite_id), 'NumberTitle', 'off');
plot(time_vector_cst, detrended_phase_rad, 'r-');
title(sprintf('卫星 %s - 去趋势后的GPSense相位', target_satellite_id));
xlabel('时间 (北京时间)');
ylabel('去趋势相位 (弧度)');
grid on;
datetick('x', 'HH:MM:SS', 'keepticks', 'keeplimits');
% ======================================================================

fprintf('✅ 图形绘制完成！\n');
end
