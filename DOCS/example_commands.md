# Example Commands for Algae Taxa Pipeline

## Basic Usage

### 1. Prepare Input Samplesheet

Create a CSV file with your genome samples:

```csv
sample,genome
KAUST067,/path/to/KAUST067_purged.fa
KAUST068,/path/to/KAUST068_purged.fa.gz
KAUST069,/path/to/KAUST069_purged.fasta
```

### 2. Configure Database Paths

Edit `conf/databases.config` with your actual database paths, or pass them as parameters:

```bash
# Option A: Edit conf/databases.config and include it
nextflow run main.nf \
  -c conf/databases.config \
  --input samplesheet.csv \
  --outdir results

# Option B: Pass database paths as command-line parameters
nextflow run main.nf \
  --input samplesheet.csv \
  --outdir results \
  --eukaryome_ssu_fasta /ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_SSU_v2.0.fasta \
  --eukaryome_ssu_taxonomy /ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_SSU_v2.0.tax \
  --eukaryome_lsu_fasta /ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_LSU_v2.0.fasta \
  --eukaryome_lsu_taxonomy /ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_LSU_v2.0.tax \
  --eukaryome_its_fasta /ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_ITS_v2.0.fasta \
  --eukaryome_its_taxonomy /ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_ITS_v2.0.tax \
  --eukaryome_longread_fasta /ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.fasta \
  --eukaryome_longread_taxonomy /ibex/project/c2303/DATABASES/EUKARYOME/mothur/mothur_EUK_longread_v2.0.tax \
  --pr2_ssu_fasta /ibex/project/c2303/DATABASES/PR2/pr2_version_5.1.1_SSU_mothur.fasta \
  --pr2_ssu_taxonomy /ibex/project/c2303/DATABASES/PR2/pr2_version_5.1.1_SSU_mothur.tax
```

### 3. Basic Run with Default Settings

```bash
nextflow run main.nf \
  -c conf/databases.config \
  --input samplesheet.csv \
  --outdir results \
  --organism_type eukaryotic \
  --itsx_organism_code G
```

## Advanced Options

### Run without Mothur Classification

If you only want rRNA/ITS extraction without classification:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --outdir results \
  --run_mothur_classification false
```

### Adjust Organism Type for ITSx

ITSx organism codes for different algae types:
- `G` = Chlorophyta (green algae) - **default**
- `H` = Rhodophyta (red algae)
- `I` = Phaeophyceae (brown algae)
- `P` = Haptophyceae (prymnesiophytes)
- `C` = Bacillariophyta (diatoms)

```bash
nextflow run main.nf \
  -c conf/databases.config \
  --input samplesheet.csv \
  --outdir results \
  --itsx_organism_code H  # For red algae
```

### Adjust Mothur Classification Cutoff

Change the bootstrap confidence cutoff (default: 80):

```bash
nextflow run main.nf \
  -c conf/databases.config \
  --input samplesheet.csv \
  --outdir results \
  --mothur_cutoff 90  # More stringent classification
```

### Run with Different Profiles

```bash
# Using Docker
nextflow run main.nf -profile docker -c conf/databases.config --input samplesheet.csv

# Using Singularity
nextflow run main.nf -profile singularity -c conf/databases.config --input samplesheet.csv

# Using Conda
nextflow run main.nf -profile conda -c conf/databases.config --input samplesheet.csv

# HPC with SLURM
nextflow run main.nf -profile slurm -c conf/databases.config --input samplesheet.csv
```

## Output Structure

```
results/
├── KAUST067/
│   ├── barrnap/
│   │   ├── KAUST067.bac.rRNA.gff
│   │   ├── KAUST067.arc.rRNA.gff
│   │   ├── KAUST067.euk.rRNA.gff
│   │   └── KAUST067.mito.rRNA.gff
│   ├── combined_gff/
│   │   └── KAUST067.all.rRNA.gff
│   ├── bed_coordinates/
│   │   ├── KAUST067.18s.bed
│   │   ├── KAUST067.28s.bed
│   │   ├── KAUST067.5_8s.bed
│   │   └── ...
│   ├── extracted_sequences/
│   │   ├── KAUST067.18s.fa
│   │   ├── KAUST067.28s.fa
│   │   ├── KAUST067.5_8s.fa
│   │   └── ...
│   ├── itsx/
│   │   ├── KAUST067.ITS1.fasta
│   │   ├── KAUST067.ITS2.fasta
│   │   ├── KAUST067.SSU.fasta
│   │   └── KAUST067.LSU.fasta
│   └── classifications/
│       ├── KAUST067.18S.DB_EUKARYOME_SSU.taxonomy
│       ├── KAUST067.18S.DB_EUKARYOME_SSU.tax.summary
│       ├── KAUST067.18S.DB_PR2_SSU.taxonomy
│       ├── KAUST067.18S.DB_PR2_SSU.tax.summary
│       ├── KAUST067.28S.DB_EUKARYOME_LSU.taxonomy
│       ├── KAUST067.ITS1.DB_EUKARYOME_ITS.taxonomy
│       └── ...
└── KAUST068/
    └── ...
```

## What Classifications Are Generated?

For each sample, the pipeline generates classifications for:

### 18S rRNA sequences:
- vs EUKARYOME SSU database
- vs PR2 SSU database
- vs EUKARYOME longread database

### 28S rRNA sequences:
- vs EUKARYOME LSU database
- vs EUKARYOME longread database

### 5.8S rRNA sequences:
- vs EUKARYOME ITS database
- vs EUKARYOME longread database

### ITS1 sequences:
- vs EUKARYOME ITS database
- vs EUKARYOME longread database

### ITS2 sequences:
- vs EUKARYOME ITS database
- vs EUKARYOME longread database

**Total: Up to 12 classifications per sample** (depending on which sequences are found and which databases are configured)
