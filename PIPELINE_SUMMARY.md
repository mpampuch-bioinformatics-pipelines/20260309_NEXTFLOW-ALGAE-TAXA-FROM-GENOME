# Algae Taxa from Genome Pipeline - Implementation Summary

## Overview

This Nextflow DSL2 pipeline was created to extract and taxonomically classify rRNA and ITS sequences from whole algal genome assemblies. It automates the entire workflow from genome input to taxonomic classification across multiple reference databases.

## Pipeline Architecture

### Main Components

1. **Main Workflow** (`main.nf`)
   - Entry point for the pipeline
   - Includes schema validation and help functionality
   - Calls the ALGAE_TAXA workflow

2. **ALGAE_TAXA Workflow** (`workflows/algae_taxa.nf`)
   - Core workflow logic
   - Orchestrates all processing steps
   - Manages data flow between processes

3. **Custom Modules** (`modules/local/`)
   - `decompress_genome.nf` - Handles gzipped genome files
   - `barrnap.nf` - rRNA prediction across multiple kingdoms
   - `combine_gff.nf` - Merges GFF files from different kingdoms
   - `extract_bed.nf` - Converts GFF to BED coordinates
   - `bedtools_getfasta.nf` - Extracts FASTA sequences
   - `itsx.nf` - ITS region extraction
   - `mothur_classify.nf` - Taxonomic classification

## Key Features

### Flexible Input Handling
- Accepts both compressed (.gz) and uncompressed genome files
- Simple CSV samplesheet format
- Supports multiple genome file extensions (.fa, .fasta, .fna)

### Comprehensive rRNA Detection
- Runs barrnap across 4 kingdoms: bacterial, archaeal, eukaryotic, mitochondrial
- Identifies: 5S, 5.8S, 12S, 16S, 18S, 23S, 28S rRNA genes
- Combines predictions from all kingdoms into unified output

### ITS Region Extraction
- Uses ITSx for precise ITS1/ITS2 identification
- Configurable organism types for different algal groups
- Extracts SSU and LSU sequences alongside ITS regions

### Multi-Database Classification
Pipeline classifies sequences against multiple databases:

**For 18S rRNA:**
- EUKARYOME SSU database
- PR2 SSU database
- EUKARYOME longread database

**For 28S rRNA:**
- EUKARYOME LSU database
- EUKARYOME longread database

**For 5.8S rRNA and ITS regions:**
- EUKARYOME ITS database
- EUKARYOME longread database

**Total:** Up to 12 classifications per sample

### Process Isolation
- Each step produces outputs to dedicated directories
- Clear separation between tools and stages
- Easy to track and debug individual steps

## Configuration

### Profiles
- `docker` - Run with Docker containers
- `singularity` - Run with Singularity containers
- `conda` - Run with Conda environments
- `test` - Quick test with minimal data
- `test_full` - Full test with real data

### Customizable Parameters

**Core Parameters:**
- `--input` - Input samplesheet path
- `--outdir` - Output directory
- `--run_mothur_classification` - Enable/disable classification

**Tool-specific Parameters:**
- `--organism_type` - Organism type for barrnap (default: "eukaryotic")
- `--itsx_organism_code` - ITSx organism code (default: "G" for green algae)
- `--mothur_cutoff` - Classification confidence cutoff (default: 80)

**Database Paths:**
All database paths configurable via `conf/databases.config` or command line

## Outputs

### Directory Structure
```
results/
├── {sample}/
│   ├── barrnap/              # rRNA predictions per kingdom
│   ├── combined_gff/         # Merged rRNA annotations
│   ├── bed_coordinates/      # BED files per rRNA type
│   ├── extracted_sequences/  # FASTA files per rRNA type
│   ├── itsx/                 # ITS1, ITS2, SSU, LSU sequences
│   └── classifications/      # Taxonomy files per sequence-database combination
```

### Output Files Per Sample

**rRNA Prediction:**
- `{sample}.{kingdom}.rRNA.gff` (bac, arc, euk, mito)
- `{sample}.all.rRNA.gff` (combined)

**Coordinates:**
- `{sample}.{rRNA_type}.bed` (5s, 5_8s, 12s, 16s, 18s, 23s, 28s)

**Extracted Sequences:**
- `{sample}.{rRNA_type}.fa`

**ITS Extraction:**
- `{sample}.ITS1.fasta`
- `{sample}.ITS2.fasta`
- `{sample}.SSU.fasta`
- `{sample}.LSU.fasta`

**Classifications:**
- `{sample}.{sequence_type}.{database}.taxonomy`
- `{sample}.{sequence_type}.{database}.tax.summary`

## Technical Details

### Channel Management
- Uses `splitCsv` for samplesheet parsing
- Channels properly forked for multiple consumers
- Efficient data flow with minimal re-computation

### Error Handling
- Graceful handling of missing sequences (some rRNA types may not be found)
- Optional classification step can be disabled
- Each process publishes outputs independently

### Resource Management
- Conservative default resources (4 CPUs, 8 GB memory)
- Configurable via `conf/base.config`
- Task-specific resource allocation possible

### Container Support
- All tools available as containers
- Wave/Fusion integration supported
- Conda environments as fallback option

## Validation

### Linting Status
✅ All Nextflow files pass `nextflow lint` validation (32/32 files)
- Excludes `nf-test.config` which uses nf-test-specific syntax

### Code Quality
- Follows Nextflow DSL2 best practices
- Uses strict syntax patterns for future compatibility
- Clear separation of concerns
- Well-documented parameters and processes

## Usage Recommendations

### For Green Algae (Chlorophyta)
```bash
nextflow run main.nf \
  -c conf/databases.config \
  --input samplesheet.csv \
  --outdir results \
  --itsx_organism_code G
```

### For Red Algae (Rhodophyta)
```bash
nextflow run main.nf \
  -c conf/databases.config \
  --input samplesheet.csv \
  --outdir results \
  --itsx_organism_code H
```

### For Brown Algae (Phaeophyceae)
```bash
nextflow run main.nf \
  -c conf/databases.config \
  --input samplesheet.csv \
  --outdir results \
  --itsx_organism_code I
```

### For Diatoms (Bacillariophyta)
```bash
nextflow run main.nf \
  -c conf/databases.config \
  --input samplesheet.csv \
  --outdir results \
  --itsx_organism_code C
```

## Future Enhancements

Potential areas for expansion:
1. Add MultiQC report generation for aggregated QC metrics
2. Include BLAST-based classification as alternative to mothur
3. Add phylogenetic tree construction from classified sequences
4. Implement automated database downloading and setup
5. Add support for contaminant detection and filtering
6. Include consensus taxonomy determination across databases

## Documentation

- **README.md** - Main documentation with quick start guide
- **DOCS/example_commands.md** - Comprehensive usage examples
- **conf/databases.config** - Database configuration template
- **This file** - Implementation details and technical summary

## Credits

Pipeline developed for taxonomic classification of algal genomes using industry-standard bioinformatics tools integrated into a robust, reproducible Nextflow workflow.

**Tools Used:**
- barrnap - rRNA prediction
- ITSx - ITS extraction  
- bedtools - Sequence extraction
- mothur - Taxonomic classification
- Nextflow - Workflow management

**Databases Supported:**
- EUKARYOME - Comprehensive eukaryotic reference database
- PR2 - Protist ribosomal reference database
