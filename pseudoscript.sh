#!/bin/bash

###########################################################
#
# Pseudoscript for the analysis of taxonomically relevant sequences from whole algal genomes
#
# Author: Mark Pampuch
# Date: 2026-03-08
#
###########################################################

# Step 1: Use barrnap version 0.9 to extract the rRNA sequences from the genomes
barrnap --kingdom bac --threads 32 KAUST067_purged.fa > KAUST067_purged.bac.rRNA.gff
barrnap --kingdom arc --threads 32 KAUST067_purged.fa > KAUST067_purged.arc.rRNA.gff
barrnap --kingdom euk --threads 32 KAUST067_purged.fa > KAUST067_purged.euk.rRNA.gff
barrnap --kingdom mito --threads 32 KAUST067_purged.fa > KAUST067_purged.mito.rRNA.gff

# Step 2: Combine these into a single GFF file
cat KAUST067_purged.bac.rRNA.gff \
    <(grep -v "##gff-version" KAUST067_purged.arc.rRNA.gff) \
    <(grep -v "##gff-version" KAUST067_purged.euk.rRNA.gff) \
    <(grep -v "##gff-version" KAUST067_purged.mito.rRNA.gff) \
    > KAUST067_purged.all.rRNA.gff

# Step 3: Get the FASTA files from the GFF files for BARRNAP 
# Need all these files

# 12S_rRNA
# 16S_rRNA
# 18S_rRNA
# 23S_rRNA
# 28S_rRNA
# 5_8S_rRNA
# 5S_rRNA
awk '$9 ~ /12S/ {print $1"\t"$4-1"\t"$5"\t"$9}' "KAUST067_purged.all.rRNA.gff" > "KAUST067_purged.12s.bed"
awk '$9 ~ /16S/ {print $1"\t"$4-1"\t"$5"\t"$9}' "KAUST067_purged.all.rRNA.gff" > "KAUST067_purged.16s.bed"
awk '$9 ~ /18S/ {print $1"\t"$4-1"\t"$5"\t"$9}' "KAUST067_purged.all.rRNA.gff" > "KAUST067_purged.18s.bed"
awk '$9 ~ /23S/ {print $1"\t"$4-1"\t"$5"\t"$9}' "KAUST067_purged.all.rRNA.gff" > "KAUST067_purged.23s.bed"
awk '$9 ~ /28S/ {print $1"\t"$4-1"\t"$5"\t"$9}' "KAUST067_purged.all.rRNA.gff" > "KAUST067_purged.28s.bed"
awk '$9 ~ /5_8S/ {print $1"\t"$4-1"\t"$5"\t"$9}' "KAUST067_purged.all.rRNA.gff" > "KAUST067_purged.5_8s.bed"
awk '$9 ~ /5S/ {print $1"\t"$4-1"\t"$5"\t"$9}' "KAUST067_purged.all.rRNA.gff" > "KAUST067_purged.5s.bed"

# Step 4: Use bedtools to extract the sequences from the FASTA files
bedtools getfasta -fi KAUST067_purged.fa -bed KAUST067_purged.12s.bed -fo KAUST067_purged.12s.fa
bedtools getfasta -fi KAUST067_purged.fa -bed KAUST067_purged.16s.bed -fo KAUST067_purged.16s.fa
bedtools getfasta -fi KAUST067_purged.fa -bed KAUST067_purged.18s.bed -fo KAUST067_purged.18s.fa
bedtools getfasta -fi KAUST067_purged.fa -bed KAUST067_purged.23s.bed -fo KAUST067_purged.23s.fa
bedtools getfasta -fi KAUST067_purged.fa -bed KAUST067_purged.28s.bed -fo KAUST067_purged.28s.fa
bedtools getfasta -fi KAUST067_purged.fa -bed KAUST067_purged.5_8s.bed -fo KAUST067_purged.5_8s.fa
bedtools getfasta -fi KAUST067_purged.fa -bed KAUST067_purged.5s.bed -fo KAUST067_purged.5s.fa

# Step 5: Use ITSx to extract the ITS sequences from the genomes
# Character code Full name Alternative name
# A Alveolata alveolates
# B Bryophyta mosses
# C Bacillariophyta diatoms
# D Amoebozoa
# E Euglenozoa
# F Fungi
# G Chlorophyta green-algae
# H Rhodophyta red-algae
# I Phaeophyceae brown-algae
# L Marchantiophyta liverworts
# M Metazoa animals
# O Oomycota oomycetes
# P Haptophyceae prymnesiophytes
# Q Raphidophyceae raphidophytes
# R Rhizaria
# S Synurophyceae synurids
# T Tracheophyta higher-plants
# U Eustigmatophyceae eustigmatophytes
# X Apusozoa
# Y Parabasalia parabasalids
# . All


unset PERL5LIB
unset PERLLIB
ITSx -i KAUST067_purged.fa -o KAUST067_purged --cpu 32 -t G
# Important outputs
# KAUST067_purged.ITS1.fasta
# KAUST067_purged.ITS2.fasta

# Step 6: Use mothur to classify the sequences against the EUKARYOME database (for eukaryotes) or the SILVA database (for bacteria and archaea)
# For eukaryotes, use 18s, 28s, 5_8s, ITS1, and ITS2 for classification
cat <<EOF > classify.seqs.KAUST067_purged.18s.DB_EUKARYOME-mothur-SSU-v2-0.batch.sh
#! /bin/bash
classify.seqs(fasta=KAUST067_purged.18s.fa, reference=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_SSU_v2.0.fasta, taxonomy=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_SSU_v2.0.tax, cutoff=80, processors=32, probs=T)
rename.file(taxonomy=current, summary=KAUST067_purged.18s.0.wang.tax.summary, accnos=current, prefix=KAUST067_purged.18s.DB_EUKARYOME-mothur-SSU-v2-0)
EOF
chmod +x classify.seqs.KAUST067_purged.18s.DB_EUKARYOME-mothur-SSU-v2-0.batch.sh
srun --time=08:00:00 --mem=32Gb --cpus-per-task=8 bash -c "module load mothur ; mothur classify.seqs.KAUST067_purged.18s.DB_EUKARYOME-mothur-SSU-v2-0.batch.sh"

cat <<EOF > classify.seqs.KAUST067_purged.18s.DB_PR2-mothur-SSU-v5-1-1.batch.sh
#! /bin/bash
classify.seqs(fasta=KAUST067_purged.18s.fa, reference=/ibex/project/c2303/DATABASES/PR2/pr2_version_5.1.1_SSU_mothur.fasta, taxonomy=/ibex/project/c2303/DATABASES/PR2/pr2_version_5.1.1_SSU_mothur.tax, cutoff=80, processors=32, probs=T)
rename.file(taxonomy=current, summary=KAUST067_purged.18s.0.wang.tax.summary, accnos=current, prefix=KAUST067_purged.18s.DB_PR2-mothur-SSU-v5-1-1)
EOF
chmod +x classify.seqs.KAUST067_purged.18s.DB_PR2-mothur-SSU-v5-1-1.batch.sh
srun --time=08:00:00 --mem=32Gb --cpus-per-task=8 bash -c "module load mothur ; mothur classify.seqs.KAUST067_purged.18s.DB_PR2-mothur-SSU-v5-1-1.batch.sh"

cat <<EOF > classify.seqs.KAUST067_purged.28s.DB_EUKARYOME-mothur-LSU-v2-0.batch.sh
#! /bin/bash
classify.seqs(fasta=KAUST067_purged.28s.fa, reference=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_LSU_v2.0.fasta, taxonomy=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_LSU_v2.0.tax, cutoff=80, processors=32, probs=T)
rename.file(taxonomy=current, summary=KAUST067_purged.28s.0.wang.tax.summary, accnos=current, prefix=KAUST067_purged.28s.DB_EUKARYOME-mothur-LSU-v2-0)
EOF
chmod +x classify.seqs.KAUST067_purged.28s.DB_EUKARYOME-mothur-LSU-v2-0.batch.sh
srun --time=08:00:00 --mem=32Gb --cpus-per-task=8 bash -c "module load mothur ; mothur classify.seqs.KAUST067_purged.28s.DB_EUKARYOME-mothur-LSU-v2-0.batch.sh"

cat <<EOF > classify.seqs.KAUST067_purged.5_8s.DB_EUKARYOME-mothur-ITS-v2-0.batch.sh
#! /bin/bash
classify.seqs(fasta=KAUST067_purged.5_8s.fa, reference=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_ITS_v2.0.fasta, taxonomy=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_ITS_v2.0.tax, cutoff=80, processors=32, probs=T)
rename.file(taxonomy=current, summary=KAUST067_purged.5_8s.0.wang.tax.summary, accnos=current, prefix=KAUST067_purged.5_8s.DB_EUKARYOME-mothur-ITS-v2-0)
EOF
chmod +x classify.seqs.KAUST067_purged.5_8s.DB_EUKARYOME-mothur-ITS-v2-0.batch.sh
srun --time=08:00:00 --mem=32Gb --cpus-per-task=8 bash -c "module load mothur ; mothur classify.seqs.KAUST067_purged.5_8s.DB_EUKARYOME-mothur-ITS-v2-0.batch.sh"

cat <<EOF > classify.seqs.KAUST067_purged.ITS1.DB_EUKARYOME-mothur-ITS-v2-0.batch.sh
#! /bin/bash
classify.seqs(fasta=KAUST067_purged.ITS1.fasta, reference=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_ITS_v2.0.fasta, taxonomy=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_ITS_v2.0.tax, cutoff=80, processors=32, probs=T)
rename.file(taxonomy=current, summary=KAUST067_purged.ITS1.0.wang.tax.summary, accnos=current, prefix=KAUST067_purged.ITS1.DB_EUKARYOME-mothur-ITS-v2-0)
EOF
chmod +x classify.seqs.KAUST067_purged.ITS1.DB_EUKARYOME-mothur-ITS-v2-0.batch.sh
srun --time=08:00:00 --mem=32Gb --cpus-per-task=8 bash -c "module load mothur ; mothur classify.seqs.KAUST067_purged.ITS1.DB_EUKARYOME-mothur-ITS-v2-0.batch.sh"

cat <<EOF > classify.seqs.KAUST067_purged.ITS2.DB_EUKARYOME-mothur-ITS-v2-0.batch.sh
#! /bin/bash
classify.seqs(fasta=KAUST067_purged.ITS2.fasta, reference=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_ITS_v2.0.fasta, taxonomy=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_ITS_v2.0.tax, cutoff=80, processors=32, probs=T)
rename.file(taxonomy=current, summary=KAUST067_purged.ITS2.0.wang.tax.summary, accnos=current, prefix=KAUST067_purged.ITS2.DB_EUKARYOME-mothur-ITS-v2-0)
EOF
chmod +x classify.seqs.KAUST067_purged.ITS2.DB_EUKARYOME-mothur-ITS-v2-0.batch.sh
srun --time=08:00:00 --mem=32Gb --cpus-per-task=8 bash -c "module load mothur ; mothur classify.seqs.KAUST067_purged.ITS2.DB_EUKARYOME-mothur-ITS-v2-0.batch.sh"

cat <<EOF > classify.seqs.KAUST067_purged.18s.DB_EUKARYOME-mothur-longread-v2-0.batch.sh
#! /bin/bash
classify.seqs(fasta=KAUST067_purged.18s.fa, reference=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.fasta, taxonomy=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.tax, cutoff=80, processors=32, probs=T)
rename.file(taxonomy=current, summary=KAUST067_purged.18s.0.wang.tax.summary, accnos=current, prefix=KAUST067_purged.18s.DB_EUKARYOME-mothur-longread-v2-0)
EOF
chmod +x classify.seqs.KAUST067_purged.18s.DB_EUKARYOME-mothur-longread-v2-0.batch.sh
srun --time=08:00:00 --mem=32Gb --cpus-per-task=8 bash -c "module load mothur ; mothur classify.seqs.KAUST067_purged.18s.DB_EUKARYOME-mothur-longread-v2-0.batch.sh"

cat <<EOF > classify.seqs.KAUST067_purged.28s.DB_EUKARYOME-mothur-longread-v2-0.batch.sh
#! /bin/bash
classify.seqs(fasta=KAUST067_purged.28s.fa, reference=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.fasta, taxonomy=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.tax, cutoff=80, processors=32, probs=T)
rename.file(taxonomy=current, summary=KAUST067_purged.28s.0.wang.tax.summary, accnos=current, prefix=KAUST067_purged.28s.DB_EUKARYOME-mothur-longread-v2-0)
EOF
chmod +x classify.seqs.KAUST067_purged.28s.DB_EUKARYOME-mothur-longread-v2-0.batch.sh
srun --time=08:00:00 --mem=32Gb --cpus-per-task=8 bash -c "module load mothur ; mothur classify.seqs.KAUST067_purged.28s.DB_EUKARYOME-mothur-longread-v2-0.batch.sh"

cat <<EOF > classify.seqs.KAUST067_purged.5_8s.DB_EUKARYOME-mothur-longread-v2-0.batch.sh
#! /bin/bash
classify.seqs(fasta=KAUST067_purged.5_8s.fa, reference=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.fasta, taxonomy=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.tax, cutoff=80, processors=32, probs=T)
rename.file(taxonomy=current, summary=KAUST067_purged.5_8s.0.wang.tax.summary, accnos=current, prefix=KAUST067_purged.5_8s.DB_EUKARYOME-mothur-longread-v2-0)
EOF
chmod +x classify.seqs.KAUST067_purged.5_8s.DB_EUKARYOME-mothur-longread-v2-0.batch.sh
srun --time=08:00:00 --mem=32Gb --cpus-per-task=8 bash -c "module load mothur ; mothur classify.seqs.KAUST067_purged.5_8s.DB_EUKARYOME-mothur-longread-v2-0.batch.sh"

cat <<EOF > classify.seqs.KAUST067_purged.ITS1.DB_EUKARYOME-mothur-longread-v2-0.batch.sh
#! /bin/bash
classify.seqs(fasta=KAUST067_purged.ITS1.fasta, reference=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.fasta, taxonomy=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.tax, cutoff=80, processors=32, probs=T)
rename.file(taxonomy=current, summary=KAUST067_purged.ITS1.0.wang.tax.summary, accnos=current, prefix=KAUST067_purged.ITS1.DB_EUKARYOME-mothur-longread-v2-0)
EOF
chmod +x classify.seqs.KAUST067_purged.ITS1.DB_EUKARYOME-mothur-longread-v2-0.batch.sh
srun --time=08:00:00 --mem=32Gb --cpus-per-task=8 bash -c "module load mothur ; mothur classify.seqs.KAUST067_purged.ITS1.DB_EUKARYOME-mothur-longread-v2-0.batch.sh"

cat <<EOF > classify.seqs.KAUST067_purged.ITS2.DB_EUKARYOME-mothur-longread-v2-0.batch.sh
#! /bin/bash
classify.seqs(fasta=KAUST067_purged.ITS2.fasta, reference=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.fasta, taxonomy=/ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.tax, cutoff=80, processors=32, probs=T)
rename.file(taxonomy=current, summary=KAUST067_purged.ITS2.0.wang.tax.summary, accnos=current, prefix=KAUST067_purged.ITS2.DB_EUKARYOME-mothur-longread-v2-0)
EOF
chmod +x classify.seqs.KAUST067_purged.ITS2.DB_EUKARYOME-mothur-longread-v2-0.batch.sh
srun --time=08:00:00 --mem=32Gb --cpus-per-task=8 bash -c "module load mothur ; mothur classify.seqs.KAUST067_purged.ITS2.DB_EUKARYOME-mothur-longread-v2-0.batch.sh"
