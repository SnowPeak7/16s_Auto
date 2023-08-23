PRJNA = config["PRJNA"]

# 规则：定义最终目标
rule all:
    input:
        f"{PRJNA}/SraRunTable.txt",
        f"{PRJNA}/{PRJNA}_meta.txt",
        f"{PRJNA}_srr.txt",
        "srr_downloaded/",
        "raw_fastq/"


#Downloda metadata form sra run selector
rule get_metadata:
    input:
        dir_getmeta="get_metadata.py"
    output: 
        Run_meta=f"{PRJNA}/SraRunTable.txt"
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
        rename_meta=f"{PRJNA}/{PRJNA}_meta.txt"
    shell:
        """
        # Format, use tools to avoid some weird erro

        csvformat -T {input.origin_meta} > {output.rename_meta}
        sed -i 's/Run/Sample ID/g' {output.rename_meta}
        sed -i 's/,/\t/g' {output.rename_meta}
        """

# Get SRR number from Metadata
rule get_sra:
    input:
        runinfo=rules.format_metadata.output.rename_meta
    output:
        sra=f"{PRJNA}_srr.txt"
    shell:
        "cat {input.runinfo} | cut -f 1 | sed '1d' > {output.sra}"

# 规则：使用 prefetch 下载 SRR 文件
rule download_fastq:
    input:
        sra=rules.get_sra.output.sra
    output:
        directories=directory("srr_downloaded/")
    shell:
        """
        cat {input.sra} | parallel -j 8 --results srr_downloaded/ "prefetch {{}} && mv {{}} srr_downloaded/"
        """


# Convert SRR files to fastq
rule convert_to_fastq:
    input:
        sra=rules.download_fastq.output.directories
    output:
        out_dir=directory("raw_fastq/"),
    threads: 
        8
    shell:
        """
        find {input.sra} -name '*.sra'| parallel -j 8 "fastq-dump --split-files {{}} -O raw_fastq/"
        """

