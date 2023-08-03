#!/bin/bash
# 指定子目录中的02.clean_fastq目录
base_dir="$(pwd)"
clean_fastq_dir="$base_dir/02.clean_fastq/"
# 扫描02.clean_fastq目录中的所有.clean.fastq文件
for file in ${clean_fastq_dir}*.clean.fastq ; do
    # 获取样本ID，这假设文件名的格式是：{sample-id}_{direction}.clean.fastq
    sample_id=$(basename $file | cut -d'_' -f1)
    # 检查是否有双端文件
    if [[ -e ${clean_fastq_dir}${sample_id}_2.clean.fastq ]] ; then
        # 双端测序
        # 在02.clean_fastq目录下创建一个新的CSV文件并写入标题
        if [[ ! -f ${clean_fastq_dir}filelist.txt ]]; then
            echo "sample-id,absolute-filepath,direction" > ${clean_fastq_dir}filelist.txt
        fi
        # 根据文件名中的编号确定方向
        if [[ $file == *_1.clean.fastq ]] ; then
            direction="forward"
        else
            direction="reverse"
        fi
        # 将信息写入CSV文件
        echo "${sample_id},${file},${direction}" >> ${clean_fastq_dir}filelist.txt
    else
        # 单端测序
        # 在02.clean_fastq目录下创建一个新的CSV文件并写入标题
        if [[ ! -f ${clean_fastq_dir}filelist.txt ]]; then
            echo -e "sample-id\tabsolute-filepath" > ${clean_fastq_dir}filelist.txt
        fi
        # 将信息写入CSV文件
        echo -e "${sample_id}\t${file}" >> ${clean_fastq_dir}filelist.txt
    fi
done
