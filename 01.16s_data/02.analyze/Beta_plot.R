# 加载必要的库
# Load the necessary libraries
library(ade4)
library(ggplot2)
library(RColorBrewer)
library(vegan)
library(plyr)
library(stringr)

# 读取输入参数
# 第一个为矩阵文件，第二个为输出pdf位置，第三个为分组信息（可选）
# Read the input parameters
# The first is the matrix file, the second is the output pdf location, 
# and the third is the grouping information (optional)
args <- commandArgs(trailingOnly = TRUE)
distance_matrix_file <- args[1]
distance_matrix_1 <- read.table(distance_matrix_file, header = TRUE, row.names = 1)
distance_matrix <- as.dist(distance_matrix_1)

if (length(args) > 2) {
  group_file <- args[3]
#   groups <- read.table(group_file, header = FALSE, col.names = c("Sample", "Group"))
#   groups <- factor(groups$Group)
    #假设样本信息为csv格式，第一列为样本ID，第二列为分组信息
    # Assume that the sample information is in csv format, 
    # with the first column being the sample ID and the second column being the grouping information
# TODO 添加格式判断
  groups <- read.table(group_file, sep = ",", header = FALSE, col.names = c("Sample", "Group"))
  groups <- factor(groups$Group)
} else {
  # groups <- factor(rep(1, nrow(distance_matrix_1))) # 如果没有分组信息，则为每个样本创建一个组
  # groups <- factor(1:nrow(distance_matrix_1)) # 如果没有分组信息，则为每个样本创建一个组
  groups <- factor(rownames(distance_matrix_1))
}
out_dir = args[2]

# PCoA
data_pcoa <- cmdscale(distance_matrix, k = 2, eig = TRUE, add = TRUE)
data_pcoa_eig <- data_pcoa$eig
data_pcoa_exp <- data_pcoa_eig / sum(data_pcoa_eig)
sample_site <- data.frame(data_pcoa$points)[1:2]
sample_site$level <- groups
names(sample_site)[1:3] <- c('PCoA1', 'PCoA2', 'level')

find_hull <- function(sample_site) sample_site[chull(sample_site$PCoA1, sample_site$PCoA2),]
hulls <- ddply(sample_site, "level", find_hull)

# PCoA
pcoa_plot <- ggplot(sample_site, aes(PCoA1, PCoA2, color = level, shape = level)) +
  theme_classic() +
  geom_vline(xintercept = 0, color = 'gray', size = 0.4) +
  geom_hline(yintercept = 0, color = 'gray', size = 0.4) +
  geom_polygon(data = hulls, alpha = 0.2, aes(fill = factor(level), color = level), size = 0.2, show.legend = FALSE) +
  geom_point(size = 4, shape = 16) +
#   scale_color_brewer(palette = "Set1") +
#   scale_shape_manual(values = c(20, 20, 20)) +
  scale_x_continuous(limits = c(min(sample_site$PCoA1), max(sample_site$PCoA1))) +
  scale_y_continuous(limits = c(min(sample_site$PCoA2), max(sample_site$PCoA2))) +
  theme(panel.grid = element_line(color = 'black', linetype = 1, size = 0.1),
        panel.background = element_rect(color = 'black', fill = 'transparent'),
        legend.title = element_blank(),plot.title = element_text(hjust = 0.5)) +
  ggtitle(str_sub(out_dir,10,-12))+
  labs(x = paste('PCoA1 [', round(100 * data_pcoa_exp[1], 2), '%]'), y = paste('PCoA2 [', round(100 * data_pcoa_exp[2], 2), '%]'))


# Save PDF
ggsave(out_dir, pcoa_plot, width = 10, height = 8)
