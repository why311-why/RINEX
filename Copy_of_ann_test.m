% ============== test.m (最终调用脚本) ==============
clear; clc; 

close all;

% --- 1. 用户配置 ---
obs_filepath = 'test.obs'; 
nav_filepath = 'test.nav'; 

% --- 2. 解析文件 ---
fprintf('--> 正在解析观测文件: %s\n', obs_filepath);
obs_data = parse_rinex_obs(obs_filepath);

fprintf('--> 正在解析导航文件: %s\n', nav_filepath);
nav_data = parse_rinex_nav_gps_bds(nav_filepath);

fprintf('\n✅ 文件解析全部完成。\n\n');
calculate_average_sampling_rate(obs_data);

%%
calculate_and_plot_all_skyplot(obs_data, nav_data);
%%
%伪距重建按照论文 相位未滤波
analyze_and_plot_gpsense_preV2(obs_data, nav_data, 'G25');
