'''
Author: SnowPeak7
Date: 2023-08-02 09:05:22
LastEditTime: 2023-08-02 09:05:23
LastEditors: SnowPeak7
Description: 
FilePath: /undefined/Users/snowpeak7/Documents/bioinfo/shellScript/01.16s_auto/16s_downLoad.py
Allways remember:Ignorance is fatal
'''

PRJNA = "PRJNA252404"

# 函数：从 SRR 列表文件中读取 SRR 号,注：此函数在检查时会报错，故舍弃
# def get_srr_ids():
#     with open(f"{PRJNA}_srr.txt") as file:
#         return [line.strip() for line in file]

# 规则：定义最终目标
rule all:
    input:
        "split_done.txt"

# 规则：获取 PRJNA 号的运行信息
rule get_runinfo:
    output:
        runinfo=f"{PRJNA}_runinfo.csv"
    shell:
        f"esearch -db sra -query {PRJNA} | efetch -format runinfo > {{output.runinfo}}"

# 规则：从运行信息中提取 SRR 编号
rule get_sra:
    input:
        runinfo=f"{PRJNA}_runinfo.csv"
    output:
        sra=f"{PRJNA}_srr.txt"
    shell:
        "cat {input.runinfo} | cut -d ',' -f 1 | sed '1d' > {output.sra}"

# 规则：使用 prefetch 下载 SRR 文件
rule get_fastq:
    input:
        sra=f"{PRJNA}_srr.txt"
    output:
        done="srr_down_done.txt"
    shell:
        """
        cat {input.sra} | parallel -j 8 prefetch {{}}
        touch {output.done}
        """

#规则：将 SRA 文件转换为 FASTQ 格式
rule convert_to_fastq:
    input:
        "srr_down_done.txt",
        sra=f"{PRJNA}_srr.txt"
    output:
        done="split_done.txt"
    run:
        #读取 SRR 号列表
        with open(input.sra,"r") as file:
            srr_ids = [line.strip() for line in file]
        sra_files_str = ' '.join([f"{id}/{id}.sra" for id in srr_ids])
        shell(
            """
            # 使用 GNU parallel 来并行运行 fastq-dump
            parallel -j 8 "fastq-dump --split-files {{}} -O raw_fastq/" ::: {sra_files_str}
            touch {output.done}
            """
        )

#Downloda metadata form sra run selector
rule get_metadata:
    input:
        dir_getmeta="get_metadata.py"
    output: 
        Run_meta="{PRJNA}/SraRunTable.txt"
    shell:
        """
        # Download

        python {input.dir_getmeta} -p {PRJNA}
        """

#Rename metadata file make it more readable
rule format_metadata:
    input: 
        origin_meta=rules.get_metadata.output.Run_meta
    output: 
        rename_meta="{PRJNA}/{PRJNA}_meta.txt"
    shell:
        """
        # Rename

        cp {input.origin_meta} {output.rename_meta}

        #Format

        sed -i 's/Run/Sample ID/g' {output.rename_meta}
        sed -i 's/,/\t/g' {output.rename_meta}
        """