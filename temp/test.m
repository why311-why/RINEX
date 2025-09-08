% ============== test.m (最终版 - 修复数据类型错误并优化) ==============
clear; clc; close all;

% --- 1. 用户配置 ---
% 文件路径
obs_filepath = 'COM5___460800_250614_122524.obs'; 
nav_filepath = 'COM5___460800_250614_122524.24n'; 

% 选择要分析的目标卫星

% 选择要处理的历元范围 (例如，处理前1000个历元)
epoch_range = 1:1000; 

% 选择信号重建方法: 'standard'
reconstruction_method = 'standard'; 

% --- 2. 解析文件 ---
fprintf('--> 正在解析观测文件: %s\n', obs_filepath);
obs_data = parse_rinex_obs_advanced(obs_filepath);
fprintf('--> 正在解析导航文件: %s\n', nav_filepath);
nav_data = parse_rinex_nav(nav_filepath);
fprintf('\n✅ 文件解析全部完成。\n\n');
%%
epoch_idx = 1;
[rec_pos, rec_clk_err_sec, sat_states] = calculate_receiver_position(obs_data, nav_data, epoch_idx);
disp(rec_pos);
%%
test_satellite = 'G10';

plot_observations_per_satellite(obs_data, test_satellite, '1C'); 
plot_phase_and_doppler(obs_data, test_satellite, '1C');
%%

plot_reconstructed_signals(obs_data, nav_data,test_satellite);         % 使用全部历元

plot_gpsense_phase_literal(obs_data, nav_data, test_satellite);         % 默认全部历元

