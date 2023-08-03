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
        "03.import/reads.qza"

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