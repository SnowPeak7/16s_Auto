'''
Author: SnowPeak7
Date: 2023-08-04 17:40:03
LastEditTime: 2023-08-04 18:26:25
LastEditors: SnowPeak7
Description: 
FilePath: /smooth/smooth_benchmark.py
Allways remember:Ignorance is fatal
'''

import argparse
import numpy as np
from scipy.ndimage import gaussian_filter1d
import pymannkendall as mk
import pandas as pd
import time


# 创建解析器
parser = argparse.ArgumentParser(description='Process the given file path.')
parser.add_argument('file_path', type=str, help='Path to the joined TSV file')

# 解析参数
args = parser.parse_args()

# 记录开始时间
start_time = time.time()

# 读取数据
file_path = args.file_path
data = pd.read_csv(file_path, sep='\t', index_col=0)
median_quality_scores = data.loc['50%']
base_positions = median_quality_scores.index.astype(int)

# 定义高斯平滑函数
def gaussian_smoothing(values, sigma):
    return gaussian_filter1d(values, sigma)

# 定义指数移动平均函数
def exponential_moving_average(values, alpha):
    ema_values = [values[0]]
    for value in values[1:]:
        ema_values.append(alpha * value + (1 - alpha) * ema_values[-1])
    return ema_values

# 使用α=0.15的指数移动平均处理数据
ema_values = exponential_moving_average(median_quality_scores, alpha=0.15)

# 使用σ=3的高斯平滑处理数据
gaussian_smoothed_values = gaussian_smoothing(median_quality_scores, sigma=3)

# 定义评估函数
def evaluate_methods(values, start_position, window_size, consecutive_decreasing_windows):
    # 寻找连续下降的窗口
    decreasing_count = 0
    drop_position = None
    for i in range(start_position - 1, len(values) - window_size + 1):
        window_data = values[i: i + window_size]
        result = mk.original_test(window_data)
        if result.trend == "decreasing":
            decreasing_count += 1
            if decreasing_count >= consecutive_decreasing_windows:
                drop_position = base_positions[i]
                break
        else:
            decreasing_count = 0
    return drop_position

# EMA函数封装
def evaluate_ema(start_position):
    tmp_EMA=[]
    for window_size in range(7, 10):
        for consecutive_decreasing_windows in range(7, 10):
            drop_position_ema = evaluate_methods(ema_values, start_position, window_size, consecutive_decreasing_windows)
            if drop_position_ema != None:
                tmp_EMA.append({
                    "window_size": window_size,
                    "consecutive_decreasing_windows": consecutive_decreasing_windows,
                    "drop_position": drop_position_ema,
                    "method": "EMA"
                })
    return tmp_EMA

# Gaussian函数封装
def evaluate_gaussian(start_position):
    tmp_Gaussian=[]
    for window_size in range(7, 10):
        for consecutive_decreasing_windows in range(7, 10):
            drop_position_gaussian = evaluate_methods(gaussian_smoothed_values, start_position, window_size, consecutive_decreasing_windows)
            if drop_position_gaussian != None:
                tmp_Gaussian.append({
                    "window_size": window_size,
                    "consecutive_decreasing_windows": consecutive_decreasing_windows,
                    "drop_position": drop_position_gaussian,
                    "method": "Gaussian Smoothing"
                })
    return tmp_Gaussian

# 定义函数以检测给定位置前5bp,后15bp的最大质量差异
def max_quality_difference(values, position):
    start = max(0, position - 5)
    end = min(len(values), position + 15)
    return max(values[start:end]) - min(values[start:end])

# 从第75个碱基开始-指数移动平均
start_position_EMA = 75

filtered_results_length_EMA = 0

while filtered_results_length_EMA == 0:

    results_EMA = evaluate_ema(start_position_EMA)

    # 过滤结果，只保留最大差值大于或等于2的位点
    filtered_results_EMA = []
    for result in results_EMA:
        position = result['drop_position']
        quality_diff = max_quality_difference(ema_values, position)
        if quality_diff >= 2:
            filtered_results_EMA.append(result)

    # print(filtered_results_df.head())
    filtered_results_length_EMA = len(filtered_results_EMA)

    # 如果找不到满足条件的位点，则增加start_position并重新运行
    if filtered_results_length_EMA == 0:
        start_position_EMA += 25

# 从第75个碱基开始-高斯平滑
start_position_Gaussian = 75

filtered_results_length_Gaussian = 0

while filtered_results_length_Gaussian == 0:
    
        results_Gaussian = evaluate_gaussian(start_position_Gaussian)
    
        # 过滤结果，只保留最大差值大于或等于2的位点
        filtered_results_Gaussian = []
        for result in results_Gaussian:
            position = result['drop_position']
            quality_diff = max_quality_difference(gaussian_smoothed_values, position)
            if quality_diff >= 2:
                filtered_results_Gaussian.append(result)
    
        # print(filtered_results_df.head())
        filtered_results_length_Gaussian = len(filtered_results_Gaussian)
    
        # 如果找不到满足条件的位点，则增加start_position并重新运行
        if filtered_results_length_Gaussian == 0:
            start_position_Gaussian += 25


filtered_results_df_EMA = pd.DataFrame(filtered_results_EMA)
filter_median_values_EMA = filtered_results_df_EMA.groupby('method')['drop_position'].median().round().astype(int)

filtered_results_df_Gaussian = pd.DataFrame(filtered_results_Gaussian)
filter_median_values_Gaussian = filtered_results_df_Gaussian.groupby('method')['drop_position'].median().round().astype(int)


# #输出过滤后的中位数
print("Median drop positions for two method after filtering:")
for method, median in filter_median_values_EMA.items():
    print(f"{method},{median}")
for method, median in filter_median_values_Gaussian.items():
    print(f"{method},{median}")

# 记录结束时间
end_time = time.time()