% ============== test.m (遍历所有历元并绘图的最终版) ==============
clear; clc; 
close all;

% --- 1. 用户配置 ---
obs_filepath = 'test.obs'; 
nav_filepath = 'test.nav'; 

% --- 2. 解析文件 ---
fprintf('--> 正在解析观测文件: %s\n', obs_filepath);
obs_data = parse_rinex_obs(obs_filepath);
fprintf('--> 正在解析导航文件: %s\n', nav_filepath);
nav_data = parse_rinex_nav_gps_bds(nav_filepath); % 使用能解析IONO参数的版本，尽管我们暂时不用
fprintf('\n✅ 文件解析全部完成。\n\n');
% calculate_average_sampling_rate(obs_data); % 可以暂时注释掉


% --- 3. [核心修改] 遍历所有历元，进行定位解算并存储结果 ---
num_epochs = length(obs_data);
results = []; % 使用一个简单的数组来存储结果
success_count = 0;

fprintf('\n=========================================================\n');
fprintf('           开始遍历所有 %d 个历元进行定位解算            \n', num_epochs);
fprintf('                 (诊断性测试进行中)                  \n');
fprintf('=========================================================\n');

% 使用 waitbar 显示进度
h_wait = waitbar(0, '正在处理所有历元...');

for epoch_idx = 1:num_epochs
    % 更新 waitbar
    waitbar(epoch_idx / num_epochs, h_wait, sprintf('正在处理历元 %d / %d', epoch_idx, num_epochs));
    
    try
        % 调用我们正在调试的函数
        % 注意：请确保您使用的是我上一条回复中提供的、
        % 移除了TGD改正的 calculate_satellite_state.m 文件。
        [ecef_pos, ~, ~, lat, lon, alt] = ...
            calculate_receiver_position(obs_data, nav_data, epoch_idx);
        
        % 检查定位是否成功 (不是NaN)
        if ~any(isnan(ecef_pos))
            success_count = success_count + 1;
            % 将成功的结果存储起来 [纬度, 经度, 高程]
            results(success_count, :) = [lat, lon, alt];
        end
    catch ME
        % 如果 calculate_receiver_position 内部发生不可恢复的错误，这里会捕捉到
        fprintf('历元 %d 处理失败，错误信息: %s\n', epoch_idx, ME.getReport('basic'));
    end
end

close(h_wait); % 关闭进度条

fprintf('\n=========================================================\n');
fprintf('               所有历元处理完成            \n');
fprintf('           成功解算: %d / %d 个历元\n', success_count, num_epochs);
fprintf('=========================================================\n\n');


% --- 4. [新增] 绘制结果 ---
if success_count > 1
    fprintf('--> 正在绘制定位结果...\n');
    
    % 绘制所有成功定位点的轨迹图
    figure('Name', '所有成功定位点的轨迹图');
    geoplot(results(:,1), results(:,2), 'b.-', 'MarkerSize', 10); % 使用geoplot绘制经纬度轨迹
    geobasemap satellite; % 使用卫星地图作为底图
    title(sprintf('所有成功定位点的轨迹图 (%d 个点)', success_count));
    grid on;
    
    % 绘制高程变化图
    figure('Name', '高程变化图');
    plot(results(:,3), 'm-o', 'LineWidth', 1.5, 'MarkerSize', 4);
    title(sprintf('所有成功定位点的高程变化 (%d 个点)', success_count));
    xlabel('成功定位的历元序号');
    ylabel('高程 (米)');
    grid on;
    
    % 打印平均值
    mean_lat = mean(results(:,1));
    mean_lon = mean(results(:,2));
    mean_alt = mean(results(:,3));
    fprintf('平均定位结果:\n');
    fprintf('  > 平均纬度: %.6f°\n', mean_lat);
    fprintf('  > 平均经度: %.6f°\n', mean_lon);
    fprintf('  > 平均高程: %.3f m\n', mean_alt);
    
else
    fprintf('没有足够多的成功定位点，无法绘图和统计。\n');
end