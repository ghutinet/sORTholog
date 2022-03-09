##########################################################################
##########################################################################
##
##                                Library
##
##########################################################################
##########################################################################

import os, sys
import pandas as pd
import numpy as np
from snakemake.utils import validate
from glob import glob

##########################################################################
##########################################################################
##
##                               Functions
##
##########################################################################
##########################################################################


def get_final_output():
    """
    Generate final output name
    """
    final_output = multiext(
        os.path.join(OUTPUT_FOLDER, "results", "plots", "gene_PA"), ".png", ".pdf"
    )
    return final_output


##########################################################################


def infer_gene_constrains(seed_df):
    """
    Infer gene_constrains from default config value or table
    """

    list_constrains = []

    for index, row in seed_df.iterrows():
        if "evalue" in seed_df.columns and not pd.isna(row.evalue):
            tmp_evalue = row.evalue
        else:
            tmp_evalue = config["default_blast_option"]["e_val"]
            seed_df.at[index, "evalue"] = tmp_evalue

        if "coverage" in seed_df.columns and not pd.isna(row.coverage):
            tmp_coverage = row.coverage
        else:
            tmp_coverage = config["default_blast_option"]["cov"]
            seed_df.at[index, "coverage"] = tmp_coverage

        if "pident" in seed_df.columns and not pd.isna(row.pident):
            tmp_pident = row.pident
        else:
            tmp_pident = config["default_blast_option"]["pid"]
            seed_df.at[index, "pident"] = tmp_pident

        tmp_text = (
            f"{row.seed}_evalue_{tmp_evalue:.0e}_cov_{tmp_coverage}_pid_{tmp_pident}"
        )

        list_constrains.append(tmp_text)

    return list_constrains, seed_df


##########################################################################


def check_color_seed(seed_df):
    """
    Infer color if color is not set by the user in the seed's file
    """

    for index, row in seed_df.iterrows():
        if "color" not in seed_df.columns or pd.isna(row.color):
            seed_df.at[index, "color"] = config["default_values_plot"]["color"]

    return seed_df


##########################################################################


def get_list_hmm(hmm_folder, seed_df, seed_dtypes):
    """
    Gather the list of HMM files from a folder and make sure they are in the seed table
    Update the seed table with the proper hmm profile file name
    """
    list_hmm = []
    list_psiblast = seed_df.protein_id.to_list()
    list_file = glob_wildcards(os.path.join(hmm_folder,"{hmm_file_name}")).hmm_file_name
    if "hmm" in seed_df.columns and list_file:
        seed_df['hmm'] = seed_df.hmm.apply(lambda x: x if pd.isna(x) or x.split('.')[-1] == 'hmm' else f'{x}.hmm')
        seed_df['hmm'] = seed_df.hmm.apply(lambda x: "none" if pd.isna(x) else x)
        # Put back the HMM column to string instead of objects (necessary for comparison in compare_seed_table)
        seed_df = seed_df.astype(seed_dtypes)
        list_hmm = seed_df[(seed_df.hmm.isin(list_file) ) & ~(seed_df.hmm.isnull())].hmm.to_list()
        #list_hmm = seed_df[seed_df.hmm.isin(list_file)].hmm.to_list()
        list_psiblast = seed_df[~seed_df.hmm.isin(list_file)].protein_id.to_list()

    return list_hmm, list_psiblast, seed_df


##########################################################################

def compare_seed_table(seed_df, new_seed_file, start_seed_file, seed_dtypes):
    """
    Compare the seed and new seed if exists to update the new_seed
    Restart the pipeline from start if:
        - New seed file not found
        - Seed file and new seed file don't have the same number of seeds
        - Protein id does not match
    Else:
        - Update new seed file
    """

    columns2change = ["seed", "evalue", "pident", "coverage", "color"]

    if os.path.isfile(new_seed_file):
        new_seed_df = pd.read_table(new_seed_file, dtype=seed_dtypes)
        start_seed_df = pd.read_table(start_seed_file, dtype=seed_dtypes)

        # If seed is added
        if seed_df.shape[0] != start_seed_df.shape[0]:
            seed_df.to_csv(start_seed_file, sep="\t", index=False)

        # If protein name change
        elif not seed_df.protein_id.equals(start_seed_df.protein_id):
            seed_df.to_csv(start_seed_file, sep="\t", index=False)

        # If hmm added or removed
        elif not seed_df["hmm"].equals(start_seed_df["hmm"]):
            print(seed_df["hmm"].equals(start_seed_df["hmm"]), '\n',seed_df["hmm"], '\n', start_seed_df["hmm"])
            seed_df.to_csv(start_seed_file,sep="\t",index=False)

        # If something else change
        elif not seed_df[columns2change].equals(new_seed_df[columns2change]):
            # Update new seed with information of seed
            new_seed_df.update(seed_df[columns2change])
            new_seed_df.to_csv(new_seed_file, sep="\t", index=False)
    else:
        seed_df.to_csv(start_seed_file, sep="\t", index=False)

    return


##########################################################################


def create_folder(mypath):
    """
    Created the folder that I need to store my result if it doesn't exist
    :param mypath: path where I want the folder (write at the end of the path)
    :type: string
    :return: Nothing
    """

    try:
        os.makedirs(mypath)
    except OSError:
        pass

    return


##########################################################################
##########################################################################
##
##                                Variables
##
##########################################################################
##########################################################################

# Validation of the config.yaml file
validate(config, schema="../schemas/config.schema.yaml")

# path to seeds sheet (TSV format, columns: seed, protein_id, ...)
seed_file = config["seed"]

# Validation of the seed file
seed_dtypes = {
    "seed": "string",
    "protein_id": "string",
    "hmm": "string",
    "evalue": np.float64,
    "pident": np.float64,
    "coverage": np.float64,
    "color": "string",
}

seed_table = pd.read_table(seed_file, dtype=seed_dtypes)

validate(seed_table, schema="../schemas/seeds.schema.yaml")

# path to taxonomic id to search seeds in (TSV format, columns: TaxId, NCBIGroups)
taxid = config["taxid"]

# Validation of the taxid file
taxid_dtypes = {
    "TaxId": "Int64",
    "NCBIGroups": "string",
}

taxid_table = pd.read_table(taxid, dtype=taxid_dtypes)

validate(taxid_table, schema="../schemas/taxid.schema.yaml")

##########################################################################
##########################################################################
##
##                        Core configuration
##
##########################################################################
##########################################################################

## Store some workflow metadata
config["__workflow_basedir__"] = workflow.basedir
config["__workflow_basedir_short__"] = os.path.basename(workflow.basedir)
config["__workflow_workdir__"] = os.getcwd()

if workflow.config_args:
    tmp_config_arg = '" '.join(workflow.config_args).replace("=", '="')
    config["__config_args__"] = f' -C {tmp_config_arg}"'
else:
    config["__config_args__"] = ""

with open(os.path.join(workflow.basedir, "../config/VERSION"), "rt") as version:
    url = "https://github.com/vdclab/sORTholog/releases/tag"
    config["__workflow_version__"] = version.readline()
    config["__workflow_version_link__"] = f"{url}/{config['__workflow_version__']}"


##########################################################################
##########################################################################
##
##                           Options
##
##########################################################################
##########################################################################

# Name your project
project_name = config["project_name"]

# Result folder
OUTPUT_FOLDER = os.path.join(config["output_folder"], project_name)
# Adding to config for report
config["__output_folder__"] = os.path.abspath(OUTPUT_FOLDER)

# Psiblast default e-value thershold
e_val_psiblast = config["default_psiblast_option"]["psiblast_e_val"]

# Psiblast default e-value thershold
iteration_psiblast = config["default_psiblast_option"]["iteration"]

# HMM profile folder
hmm_folder = config['hmm_profiles']

# HMM default e-value threshold
e_val_HMM = config['default_HMM_option']['e_val']

# HMM type of filtering
hmm_type = '-E' if config['default_HMM_option']['type'] == 'full' else '--domE'

# Option for ncbi_genome_download
section = config["ndg_option"]["section"]

# Values for assembly_levels :
assembly_levels = config["ndg_option"]["assembly_levels"]

# Values for refseq_categories :
refseq_categories = config["ndg_option"]["refseq_categories"]

# Definition of the requirements for each seed
gene_constrains, seed_table = infer_gene_constrains(seed_table)

# Check color of the seeds
seed_table = check_color_seed(seed_table)

# Seepup option that create a reduced dataset using a psiblast step with the seed
seed2psiblast = []
if config["speedup"]:
    speedup = os.path.join(
        OUTPUT_FOLDER,
        "databases",
        "reduce_taxid",
        f"all_protein--psi_blast_eval_{e_val_psiblast:.0e}_hmm_eval_{e_val_HMM:.0e}.fasta",
    )

    # gather list of HMM profiles if any, else return an empty list
    hmm_profiles, seed2psiblast, seed_table = get_list_hmm(hmm_folder, seed_table, seed_dtypes)
    list_all_proteins = []

    if hmm_profiles:
        list_all_proteins.append(os.path.join(
            OUTPUT_FOLDER,
            "processing_files",
            "HMM",
            f"list_all_protein--eval_{e_val_HMM:.0e}.tsv",
            )
        )

    if seed2psiblast:
        list_all_proteins.append(os.path.join(
            OUTPUT_FOLDER,
            "processing_files",
            "psiblast",
            f"list_all_protein--eval_{e_val_psiblast:.0e}.tsv",
            )
        )

else:
    speedup = os.path.join(
        OUTPUT_FOLDER, "databases", "all_taxid", "taxid_all_together.fasta"
    )
    seed2psiblast = seed_table.protein_id.to_list()

# Compare seed_table and new_seed_table (if exists) to update e_val, cov, pident
new_seed_file = os.path.join(OUTPUT_FOLDER, "databases", "seeds", "new_seeds.tsv")

# Create a file as input of the first rule that change on if seeds.tsv change in required value
create_folder(os.path.join(OUTPUT_FOLDER, "databases", "seeds"))
start_seed_file = os.path.join(OUTPUT_FOLDER, "databases", "seeds", "start_seeds.tsv")

compare_seed_table(seed_table, new_seed_file, start_seed_file, seed_dtypes)
