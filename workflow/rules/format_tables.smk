# Rule for formating tables

##########################################################################
##########################################################################


rule read_psiblast:
    input:
        psiblast=os.path.join(
            OUTPUT_FOLDER,
            "processing_files",
            "psiblast",
            f"psiblast--eval_{e_val_psiblast:.0e}_raw.out",
        ),
    output:
        list_all_prot=os.path.join(
            OUTPUT_FOLDER,
            "processing_files",
            "psiblast",
            f"list_all_proteins_psiblast--eval_{e_val_psiblast:.0e}.tsv",
        ),
    log:
        os.path.join(OUTPUT_FOLDER, "logs", "format_table", "read_psiblast.log"),
    conda:
        "../envs/pandas_plots.yaml"
    script:
        "../scripts/format_psiblast.py"


##########################################################################
##########################################################################


rule read_hmmsearch:
    input:
        hmm_out=os.path.join(
            OUTPUT_FOLDER,
            "processing_files",
            "hmmsearch",
            f"hmmsearch--eval_{e_val_HMM:.0e}.out",
        ),
    output:
        list_all_prot=os.path.join(
            OUTPUT_FOLDER,
            "processing_files",
            "hmmsearch",
            f"list_all_proteins_hmmsearch--eval_{e_val_HMM:.0e}.tsv",
        ),
    log:
        os.path.join(OUTPUT_FOLDER, "logs", "hmmer", "format_hmmsearch.log",),
    resources:
        time=120,
    conda:
        "../envs/pandas_plots.yaml"
    script:
        "../scripts/format_hmmsearch.py"


##########################################################################
##########################################################################


rule merge_hmmsearch_psiblast:
    input:
        list_hmmsearch=os.path.join(
            OUTPUT_FOLDER,
            "processing_files",
            "hmmsearch",
            f"list_all_proteins_hmmsearch--eval_{e_val_HMM:.0e}.tsv",
        ),        
        list_psiblast=os.path.join(
            OUTPUT_FOLDER,
            "processing_files",
            "psiblast",
            f"list_all_proteins_psiblast--eval_{e_val_psiblast:.0e}.tsv",
        ),
    output:
        list_all_prot=os.path.join(
            OUTPUT_FOLDER,
            "processing_files",
            "reduce_taxid",
            f"list_all_proteins.tsv",
        ),
    log:
        os.path.join(
            OUTPUT_FOLDER,
            "logs",
            "fetch_proteins",
            "merge_hmmsearch_psiblast.log",
        ),
    shell:
        """cat '{input.list_psiblast}' '{input.list_hmmsearch}' > '{output.list_all_prot}' 2> {log}"""


##########################################################################
##########################################################################


rule prepare_for_silix:
    input:
        seed_file=os.path.join(OUTPUT_FOLDER, "databases", "seeds", "new_seeds.tsv"),
        blast_out=os.path.join(
            OUTPUT_FOLDER, "processing_files", "blast", "blastp--blast_evalue_1e-2.out"
        ),
    output:
        expand(
            os.path.join(
                OUTPUT_FOLDER,
                "processing_files",
                "blast",
                "split_blast_out",
                "filtered_blast--{gene_constrains}.out",
            ),
            gene_constrains=gene_constrains,
        ),
    params:
        minimum_length = length_min,
    log:
        os.path.join(
            OUTPUT_FOLDER,
            "logs",
            "format_table",
            "prepare_for_silix.log",
        ),
    resources:
        time=30,
    conda:
        "../envs/pandas_plots.yaml"
    script:
        "../scripts/prepare_silix.py"


##########################################################################
##########################################################################


rule find_family:
    input:
        fnodes=os.path.join(
            OUTPUT_FOLDER,
            "processing_files",
            "silix",
            "fnodes_files",
            "filtered_blast--{seed}_evalue_{eval}_cov_{coverage}_pid_{pid}.fnodes",
        ),
        seed_file=os.path.join(OUTPUT_FOLDER, "databases", "seeds", "new_seeds.tsv"),
    output:
        os.path.join(
            OUTPUT_FOLDER,
            "processing_files",
            "silix",
            "modif",
            "filtered_blast--{seed}_evalue_{eval}_cov_{coverage}_pid_{pid}.fnodes.flushed",
        ),
    log:
        os.path.join(
            OUTPUT_FOLDER,
            "logs",
            "find_family",
            "{seed}_evalue_{eval}_cov_{coverage}_pid_{pid}.find_family.log",
        ),
    conda:
        "../envs/pandas_plots.yaml"
    script:
        "../scripts/find_family.py"


##########################################################################
##########################################################################


rule make_PA_table:
    input:
        seed_file=os.path.join(OUTPUT_FOLDER, "databases", "seeds", "new_seeds.tsv"),
        protein_table=proteinTable,
        fnodes=expand(
            os.path.join(
                OUTPUT_FOLDER,
                "processing_files",
                "silix",
                "modif",
                "filtered_blast--{gene_constrains}.fnodes.flushed",
            ),
            gene_constrains=gene_constrains,
        ),
    output:
        final_table=report(
            os.path.join(OUTPUT_FOLDER, "results", "patab_melt.tsv"),
            caption="../report/PA_melt.rst",
            category="Tables",
        ),
        final_table_2=report(
            os.path.join(OUTPUT_FOLDER, "results", "patab_table.tsv"),
            caption="../report/PA_table.rst",
            category="Tables",
        ),
    log:
        os.path.join(OUTPUT_FOLDER, "logs", "format_table", "make_table.log"),
    conda:
        "../envs/pandas_plots.yaml"
    script:
        "../scripts/PA-table.py"


##########################################################################
##########################################################################
