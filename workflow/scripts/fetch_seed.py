from Bio import Entrez
from Bio import SeqIO
import sys

Entrez.tool = 'draw presence/abscence v2'
Entrez.email = 'decrecylab@gmail.com'

# Put error and out into the log file
sys.stderr = sys.stdout = open(snakemake.log[0], "w")

# Read line by line the seed file without loading it in memory
with open(snakemake.input[0], 'rt') as r_file :
    with open(snakemake.output.new_seed_file, 'wt') as w_file :
        with open(snakemake.output.fasta_seed, 'w') as general_out_file:
            header = r_file.readline()
            header_split = header.split()
            index_proteinId = header_split.index('protein_id')

            # Adding length to header
            new_line = f"{header.rstrip()}\tlength\n"
            w_file.write(new_line)

            for line in r_file :
                tmp_line = line.split()
                protein_id = tmp_line[index_proteinId]

                handle = Entrez.efetch(db='protein',
                       id=protein_id,
                       rettype='fasta',
                       retmode='text')

                # New protein_id that match the fasta
                seed = SeqIO.read(handle, 'fasta')
                tmp_line[index_proteinId] = seed.id

                # Calculate length
                length = len(seed)
                tmp_line.append(str(length))

                # Write the seed in the output fasta
                SeqIO.write(seed, general_out_file, 'fasta')

                # Write the line in new tsv for the seed
                new_line = '\t'.join(tmp_line)
                new_line = f"{new_line}\n"
                w_file.write(new_line)

# # If pandas is used
# seed_table = pd.read_table(snakemake.params[0])
# id_list = seed_table.protein_id.tolist()

# # getting seed sequences and writing the fasta file
# with open(snakemake.output.fasta_seed, 'w') as out_file:
#     for index, row in seed_table.iterrows() :
#         handle = Entrez.efetch(db='protein',
#                                id=row.protein_id, 
#                                rettype='fasta', 
#                                retmode='text')
#         seed = SeqIO.read(handle, 'fasta')  
#         seed_table.at[index, 'protein_id'] = seed.id
#         seed_table.at[index, 'length'] = len(seed)
#         SeqIO.write(seed, out_file, 'fasta')

# seed_table.to_csv(snakemake.output.new_seed_file, sep='\t', index=False)
