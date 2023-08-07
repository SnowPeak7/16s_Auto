configfile: "/data1/01.16s_data/02.analyze/config.yml"


srr=config["sample_srr"]

onsuccess:
    print("Nice bro")
onerror:
    print("Error bro")

rule all:
    input:
        expand("02.clean_fastq/{sample}_1.clean.fastq", sample=srr),
        expand("02.clean_fastq/{sample}_2.clean.fastq", sample=srr),
        expand("02.clean_fastq/{sample}.html", sample=srr),
        "02.clean_fastq/filelist.txt",
        "03.import/reads.qza",
        "03.import/joined.qza",
        "03.import/joined.qzv",
        "03.import/exported_data/forward-seven-number-summaries.tsv"

#TODO 添加multiqc和fastqc以给出测序质量报告

rule fastp:
    input:
        R1="01.raw_fastq/{sample}_1.fastq",
        R2="01.raw_fastq/{sample}_2.fastq"
    output:
        R1_clean="02.clean_fastq/{sample}_1.clean.fastq",
        R2_clean="02.clean_fastq/{sample}_2.clean.fastq",
        html="02.clean_fastq/{sample}.html",
        json="02.clean_fastq/{sample}.json"
    shell:
        "fastp -q 25 -i {input.R1} -I {input.R2} -o {output.R1_clean} -O {output.R2_clean} -h {output.html} -j {output.json}"

rule make_manifest:
    input:
        expand("02.clean_fastq/{sample}.html", sample=srr)
    output:
        "02.clean_fastq/filelist.txt"
    script:
        "manifest.sh"

##TODO进行单双端判断

##目前只能导入双端
rule qiime_import:
    input: 
        "02.clean_fastq/filelist.txt",
    output: 
        "03.import/reads.qza"
    shell:
        """
        qiime tools import \
                 --type 'SampleData[PairedEndSequencesWithQuality]' \
                 --input-path {input} \
                 --output-path {output} \
                 --input-format PairedEndFastqManifestPhred33
        """

rule qiime_join:
    input: 
        "03.import/reads.qza"
    output: 
        "03.import/joined.qza"
    shell: 
        """
        qiime vsearch join-pairs \
                     --i-demultiplexed-seqs {input} \
                     --o-joined-sequences {output}
        """

rule qiime_join_visual:
    input: 
        "03.import/joined.qza"
    output: 
        "03.import/joined.qzv"
    shell:
        """
        qiime demux summarize \
                --i-data {input} \
                --o-visualization {output}
        """ 

##TODO最好对需要的文件进行检测，而不是整个文件夹
rule get_qual:
    input: 
        "03.import/joined.qzv"
    output: 
        file=directory("03.import/exported_data/"),
        qual_tsv="03.import/exported_data/forward-seven-number-summaries.tsv"
    shell: 
        "qiime tools export --input-path {input} --output-path {output.file}"

#使用sigma = 3的高斯函数对函数进行平滑处理，
#随后使用Mann-Kendall (MK) test获取滑动窗口数据
#窗口大小为5-10，下降趋势检测次数为5-10，两者随机组合，最后取中位数即为结果
rule get_trunc_site:
    input: 
        qual_tsv="03.import/exported_data/forward-seven-number-summaries.tsv"
        py_scrip_loc=""
    output: 
        "03.import/trunc_site.txt"
    run: 
        python -