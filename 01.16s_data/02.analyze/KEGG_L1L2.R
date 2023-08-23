library(ggplot2)
library(dplyr)

args <- commandArgs(trailingOnly = TRUE)

L1L2 <- read.table(args[1],header = TRUE,sep = "\t")
KEGG <- read.table(args[2],header = TRUE,sep = "\t")
#计算平均丰度
KEGG$Average <- rowMeans(KEGG[, 2:length(KEGG)])
KEGG <- KEGG[, c( "PathwayL2","Average")]
#将两个数据框L1L2和KEGG根据列PathwayL2合并
merged_df <- merge(L1L2, KEGG, by = "PathwayL2", all = TRUE)
# 去除存在缺失值的行
merged_df <- merged_df[complete.cases(merged_df), ]
merged_df_summary <- merged_df %>%
  group_by(PathwayL2, PathwayL1) %>%
  summarize(Average = mean(Average, na.rm = TRUE))
# Remove human diseases
merged_df_summary = subset(merged_df_summary,merged_df_summary$PathwayL1!="Human Diseases")

p <- ggplot(merged_df_summary, aes(Average, PathwayL2)) +
  geom_bar(aes(fill = PathwayL1), stat = "identity", width = 0.6) +
  xlab("Relative abundance") +
  ylab("KEGG Pathway") +
  theme(panel.background = element_rect(fill = "white", colour = 'black'),
        panel.grid.major = element_line(color = "grey", linetype = "dotted", size = 0.3),
        panel.grid.minor = element_line(color = "grey", linetype = "dotted", size = 0.3),
        axis.ticks.length = unit(0.4, "lines"),
        axis.ticks = element_line(color = 'black'),
        axis.line = element_line(colour = "black"),
        axis.title.x = element_text(colour = 'black', size = 8, face = "bold"),
        axis.title.y = element_text(colour = 'black', size = 8),
        axis.text.x = element_text(colour = 'black', size = 8),  # 移动此行到正确位置
        axis.text.y = element_text(color = "black", size = 8),
        legend.position = "none",  # 移动到正确位置
        strip.text.y = element_text(angle = 0, size = 12, face = "bold")) +
  facet_grid(PathwayL1 ~ ., space = "free_y", scales = "free_y")

# Save PDF
ggsave(args[3], p, width = 12, height = 16)

















