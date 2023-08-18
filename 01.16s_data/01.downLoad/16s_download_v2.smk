# 规则：定义最终目标
# rule all:
#     input:
        

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