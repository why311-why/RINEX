% ============== test.m (最终调用脚本) ==============
clear; clc; 

% close all;

% --- 1. 用户配置 ---
obs_filepath = 'west_north_25hz_1.obs'; 
nav_filepath = 'west_north_25hz_1.nav'; 

% --- 2. 解析文件 ---
fprintf('--> 正在解析观测文件: %s\n', obs_filepath);
obs_data = parse_rinex_obs(obs_filepath);

fprintf('--> 正在解析导航文件: %s\n', nav_filepath);
nav_data = parse_rinex_nav_gps_bds(nav_filepath);

fprintf('\n✅ 文件解析全部完成。\n\n');

%%
calculate_and_plot_all_skyplot(obs_data, nav_data);

%%
 analyze_and_plot_gpsense(obs_data, nav_data, 'G28');

%%
%伪距重建按照论文 相位未滤波
analyze_and_plot_gpsense_preV2(obs_data, nav_data, 'G28');


