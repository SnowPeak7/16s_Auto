configfile: "/data1/01.16s_data/02.analyze/config.yml"


srr=config["sample_srr"]
core_metric_conf=config["core_metrics"]
# alpha_type=config['alpha_type']

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
        "03.import/exported_data/forward-seven-number-summaries.tsv",
        "03.import/trunc_site.txt",
        "04.Denoise/representative_sequences.qza",
        "04.Denoise/table.qza",
        "04.Denoise/deblur-stats.qza",
        "04.Denoise/table.qzv",
        "04.Denoise/rep_seqs.qzv",
        "04.Denoise/deblur-stats.qzv",
        "04.Denoise/table_export/",
        "04.Denoise/table_export/sample-frequency-detail.csv",
        "05.Build_phylogenetic_tree/aligned_representative_sequences.qza",
        "05.Build_phylogenetic_tree/masked_aligned_representative_sequences.qza",
        "05.Build_phylogenetic_tree/unrooted-tree.qza",
        "05.Build_phylogenetic_tree/rooted-tree.qza",
        "05.Build_phylogenetic_tree/unrooted/",
        "05.Build_phylogenetic_tree/rooted/",
        "06.Taxonomy_Classify/taxonomy.qza",
        "06.Taxonomy_Classify/taxonomy.qzv",
        "06.Taxonomy_Classify/taxa-bar-plots.qzv",
        "06.Taxonomy_Classify/tax_bar_export/",
        expand("07.Diversity_analysis/{core_metric}",core_metric=core_metric_conf),
        "10.other/alpha-rarefaction.qzv",
        "10.other/export_alpha_rarefaction",
        "11.Plots/Alpha_rarefaction_Curve.pdf",
        expand("07.Diversity_analysis/{AD}.qza",AD=config["Alpha_Diversity"]),
        expand("07.Diversity_analysis/{AD}.qzv",AD=config["Alpha_Diversity"])





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

# Create a description file for qiime import
rule make_manifest:
    input:
        expand("02.clean_fastq/{sample}.html", sample=srr)
    output:
        "02.clean_fastq/filelist.txt"
    script:
        "manifest.sh"

##TODO：进行单双端判断

# Fornow onliy deal with pair-end squences
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

#TODO：最好对需要的文件进行检测，而不是整个文件夹
rule get_qual:
    input: 
        "03.import/joined.qzv"
    output: 
        file=directory("03.import/exported_data/"),
        qual_tsv="03.import/exported_data/forward-seven-number-summaries.tsv"
    shell: 
        "qiime tools export --input-path {input} --output-path {output.file}"

#使用sigma = 3的高斯函数对函数进行平滑处理，
#随后使用Mann-Kendall (MK) test获取滑动窗口趋势
#窗口大小为5-10，下降趋势检测次数为5-10，两者随机组合，最后取中位数即为结果
#TODO：增加序列数量判断，有时候质量没开始下降，长度已经下降了
rule get_trunc_site:
    input: 
        qual_tsv="03.import/exported_data/forward-seven-number-summaries.tsv",
        py_scrip_loc="get_trunc_length.py"
    output: 
        "03.import/trunc_site.txt"
    shell: 
        "python {input.py_scrip_loc} {input.qual_tsv} > {output}"

# Deblur denoise-16S
rule Deblur_denoise_16s:
    input: 
        joined=rules.qiime_join.output,
        trunc_site=rules.get_trunc_site.output
    output:
        rep_seqs="04.Denoise/representative_sequences.qza",
        table="04.Denoise/table.qza",
        stats="04.Denoise/deblur-stats.qza"
    shell:
        """
        qiime deblur denoise-16S \
              --i-demultiplexed-seqs {input.joined} \
              --p-trim-length $(grep 'Gaussian' {input.trunc_site}|cut -f 2 -d ',') \
              --o-representative-sequences {output.rep_seqs} \
              --o-table {output.table} \
              --p-sample-stats \
              --o-stats {output.stats}
        """

# Table visualization
rule table_visual:
    input: 
        table2visual=rules.Deblur_denoise_16s.output.table
    output: 
        table_qzv="04.Denoise/table.qzv"
    shell: 
        """
        qiime feature-table summarize \
        --i-table {input.table2visual} \
        --o-visualization {output.table_qzv}
        """

# Extract table info for Qiime2 diversity option: '--p-sampling-depth'
rule table_export:
    input: 
        table_qzv=rules.table_visual.output.table_qzv
    output: 
        table_file=directory("04.Denoise/table_export/"),
        table_tsv="04.Denoise/table_export/sample-frequency-detail.csv"
    shell:
         "qiime tools export --input-path {input.table_qzv} --output-path {output.table_file}"


# Rep_seqs visualization
rule rep_seqs_visual:
    input: 
        seqs2visual=rules.Deblur_denoise_16s.output.rep_seqs
    output: 
        seqs_qzv="04.Denoise/rep_seqs.qzv"
    shell: 
        """
        qiime feature-table tabulate-seqs \
        --i-data {input.seqs2visual} \
        --o-visualization {output.seqs_qzv}
        """

# Stats visualization
rule stats_visual:
    input: 
        stats2visual=rules.Deblur_denoise_16s.output.stats
    output: 
        stats_qzv="04.Denoise/deblur-stats.qzv"
    shell:
        """
        qiime deblur visualize-stats \
        --i-deblur-stats {input.stats2visual} \
        --o-visualization {output.stats_qzv}
        """

# Constructing a phylogenetic tree
rule phy_analysis:
    input: 
        rep_seqs=rules.Deblur_denoise_16s.output.rep_seqs
    output: 
        alignment="05.Build_phylogenetic_tree/aligned_representative_sequences.qza",
        masked_alignment="05.Build_phylogenetic_tree/masked_aligned_representative_sequences.qza",
        unrooted_tree="05.Build_phylogenetic_tree/unrooted-tree.qza",
        rooted_tree="05.Build_phylogenetic_tree/rooted-tree.qza"
    threads: 24
    shell:
        """
        qiime phylogeny align-to-tree-mafft-fasttree \
           --i-sequences {input} \
           --o-alignment {output.alignment} \
           --o-masked-alignment {output.masked_alignment} \
           --o-tree {output.unrooted_tree} \
           --o-rooted-tree {output.rooted_tree} \
           --p-n-threads 24
        """

# Export unrooted tree
rule export_ur_tree:
    input: 
        ur_tree=rules.phy_analysis.output.unrooted_tree
    output: 
        export_ur_tree=directory("05.Build_phylogenetic_tree/unrooted/")
    shell: 
        """
        qiime tools export \
        --input-path {input.ur_tree} \
        --output-path {output.export_ur_tree}
        """

# Export rooted tree
rule export_r_tree:
    input: 
        r_tree=rules.phy_analysis.output.rooted_tree
    output: 
        export_r_tree=directory("05.Build_phylogenetic_tree/rooted/")
    shell: 
        """
        qiime tools export \
        --input-path {input.r_tree} \
        --output-path {output.export_r_tree}
        """

#TODO:添加进化树自动绘图

# Qiime2 core-metrics
rule q2_diversity:
    input: 
        rooted_tree=rules.phy_analysis.output.rooted_tree,
        table_qza=rules.Deblur_denoise_16s.output.table,
        table_tsv=rules.table_export.output.table_tsv,
        metadata=config["metadata"]
    output: 
        expand("07.Diversity_analysis/{core_metric}", core_metric=core_metric_conf),
        results_dir=directory("07.Diversity_analysis/")
    shell:
        """
        # Get reads counts from the minest sample
        sample_length=$(cut -f 2 -d ',' {input.table_tsv} | sed '1d' | sort -n | head -1|xargs printf "%.0f\n")

        # Core-metrics compute
        qiime diversity core-metrics-phylogenetic \
            --i-phylogeny {input.rooted_tree} \
            --i-table {input.table_qza} \
            --p-sampling-depth $sample_length\
            --m-metadata-file {input.metadata} \
            --output-dir 07.Diversity_analysis_temp/
        mv 07.Diversity_analysis_temp/* {output.results_dir} && rm -rf 07.Diversity_analysis_temp/
        """ 

# Obtaining Data on Four Alpha Diversity: 
# Shannon’s diversity index, Observed Features, 
# Faith’s Phylogenetic Diversity, Evenness
rule four_alpha_diversity:
    input: 
        in_qza="{AD}.qza"
        # expand("07.Diversity_analysis/{AD}.qza",AD=config["Alpha_Diversity"])
        # Shannon_qza="07.Diversity_analysis/shannon_vector.qza",
        # Observed_Features_qza="07.Diversity_analysis/observed_features_vector.qza",
        # faith_pd_qza=""
    output: 
        out_qzv="{AD}.qzv"
        # expand("07.Diversity_analysis/{AD}.qzv",AD=config["Alpha_Diversity"])
    shell: 
        """
        qiime diversity alpha-group-significance \
            --i-alpha-diversity {input.in_qza} \
            --m-metadata-file /data1/01.16s_data/01.downLoad/PRJNA252404/PRJNA252404_meta.txt \
            --o-visualization {output.out_qzv}
        """

# TODO：这个可视化是在网页指定metadata的列，需要本地化
# TODO: 多样性绘图暂时不做，因为网络数据的分组信息太不明确，不利于自动判别




# Classify the representative sequences (OTU to Taxon)
rule classify_rep_seqs:
    input: 
        rep_seqs=rules.Deblur_denoise_16s.output.rep_seqs,
        classifier=config["classifier"]
    output: 
        taxonomy="06.Taxonomy_Classify/taxonomy.qza",
        taxonomy_visual="06.Taxonomy_Classify/taxonomy.qzv"
    shell:
        """
        # Taxonomy classification

        qiime feature-classifier classify-sklearn \
           --i-classifier {input.classifier} \
           --i-reads {input.rep_seqs} \
           --o-classification {output.taxonomy} 


        # Taxonomy visualization

        qiime metadata tabulate \
           --m-input-file {output.taxonomy} \
           --o-visualization {output.taxonomy_visual}
        """ 

# Access to species abundance data
rule tax_bar_plot:
    input: 
        table_qza=rules.Deblur_denoise_16s.output.table,
        tax_qza=rules.classify_rep_seqs.output.taxonomy,
        metadata=config["metadata"]
    output: 
        tax_bar="06.Taxonomy_Classify/taxa-bar-plots.qzv",
        tax_bar_file=directory("06.Taxonomy_Classify/tax_bar_export")
    shell:
         """
         qiime taxa barplot \
            --i-table {input.table_qza} \
            --i-taxonomy {input.tax_qza} \
            --m-metadata-file {input.metadata} \
            --o-visualization {output.tax_bar}

        # Export bar plot dataset
        qiime tools export \
            --input-path {output.tax_bar} \
            --output-path {output.tax_bar_file}
         """

# Alpha rarefaction plotting
rule Alpha_rarefaction_data:
    input: 
        table_qza=rules.Deblur_denoise_16s.output.table,
        rooted_tree=rules.phy_analysis.output.rooted_tree,
        metadata=config["metadata"]
    output: 
        alpha_rarefaction_qzv="10.other/alpha-rarefaction.qzv",
        alpha_rarefaction_file=directory("10.other/export_alpha_rarefaction")
    shell: 
        """
        # Generate Alpha rarefaction result
        qiime diversity alpha-rarefaction \
            --i-table {input.table_qza} \
            --i-phylogeny {input.rooted_tree} \
            --p-max-depth 4000 \
            --m-metadata-file {input.metadata} \
            --o-visualization {output.alpha_rarefaction_qzv}

        # Export Alpha rarefaction plot dataset
        qiime tools export \
            --input-path {output.alpha_rarefaction_qzv} \
            --output-path {output.alpha_rarefaction_file}
        """

# Alpha rarefaction plotting
# All plot in one pdf file
rule Rarefaction_plot:
    input: 
        alpha_csv="10.other/export_alpha_rarefaction/"
    output: 
        Plot_name="11.Plots/Alpha_rarefaction_Curve.pdf"
    shell: 
        """
        # Get vcs file and format
        csv_input=$(ls {input.alpha_csv}/*.csv | tr '\\n' ' ' | sed 's/ $//')

        python Rarefaction_plot.py -i $csv_input -o {output.Plot_name} 
        """

