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

# 使用α=0.1的指数移动平均处理数据
ema_values = exponential_moving_average(median_quality_scores, alpha=0.15)

# 使用σ=3的高斯平滑处理数据
gaussian_smoothed_values = gaussian_smoothing(median_quality_scores, sigma=3)

# 滑动窗口大小
window_size = 5
# 连续下降的窗口数量
consecutive_decreasing_windows = 10

# 从第75个碱基开始
start_position = 75

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

# 结果存储，将两种方法的结果存储在同一个列表中
results = []

# 遍历参数组合
for window_size in range(5, 10):
    for consecutive_decreasing_windows in range(5, 10):
        drop_position_ema = evaluate_methods(ema_values, start_position, window_size, consecutive_decreasing_windows)
        drop_position_gaussian = evaluate_methods(gaussian_smoothed_values, start_position, window_size, consecutive_decreasing_windows)
        results.append({
            "window_size": window_size,
            "consecutive_decreasing_windows": consecutive_decreasing_windows,
            "drop_position": drop_position_ema,
            "method": "EMA"
        })
        results.append({
            "window_size": window_size,
            "consecutive_decreasing_windows": consecutive_decreasing_windows,
            "drop_position": drop_position_gaussian,
            "method": "Gaussian Smoothing"
        })

# 转换为DataFrame
results_df = pd.DataFrame(results)

# 计算每种方法的中位数
median_values = results_df.groupby('method')['drop_position'].median()

# 输出中位数
print("Median drop positions for each method:")
for method, median in median_values.items():
    median_int = int(median)
    print(f"{method},{median_int}")

# 记录结束时间
end_time = time.time()

# 计算并打印所用时间
#elapsed_time = end_time - start_time
# print(f"The code took {elapsed_time:.1f} seconds to run.")
