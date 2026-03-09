# Pipeline File Structure

This document provides an overview of the complete file structure for the Algae Taxa from Genome pipeline.

## Core Pipeline Files

```
20260309_NEXTFLOW-ALGAE-TAXA-FROM-GENOME/
├── main.nf                          # Main entry point
├── nextflow.config                  # Main configuration file
├── nextflow_schema.json             # Parameter schema for validation
└── nf-test.config                   # nf-test configuration
```

## Workflows

```
workflows/
├── algae_taxa.nf                    # Main scientific workflow
└── pipeline.nf                      # nf-core template wrapper (not used directly)
```

## Custom Modules

```
modules/local/
├── barrnap.nf                       # rRNA prediction (bac, arc, euk, mito)
├── combine_gff.nf                   # Merge GFF files from all kingdoms
├── extract_bed.nf                   # Convert GFF to BED coordinates
├── bedtools_getfasta.nf             # Extract FASTA sequences from BED
├── itsx.nf                          # ITS1/ITS2 extraction
├── decompress_genome.nf             # Handle gzipped genome files
└── mothur_classify.nf               # Taxonomic classification
```

## Configuration Files

```
conf/
├── base.config                      # Base resource configuration
├── modules.config                   # Module-specific directives
├── test.config                      # Test profile configuration
├── test_full.config                 # Full test configuration
└── databases.config                 # Database paths (USER MUST CONFIGURE)
```

## Documentation

```
DOCS/
└── example_commands.md              # Comprehensive usage examples

README.md                             # Main documentation
PIPELINE_SUMMARY.md                   # Implementation summary
FILE_STRUCTURE.md                     # This file
```

## Input/Output Specification

### Required Input

**Samplesheet CSV** (`--input`):
```csv
sample,genome
SAMPLE_ID,/path/to/genome.fa
```

**Database Files** (configured in `conf/databases.config`):
- EUKARYOME SSU: FASTA + taxonomy
- EUKARYOME LSU: FASTA + taxonomy
- EUKARYOME ITS: FASTA + taxonomy
- EUKARYOME longread: FASTA + taxonomy
- PR2 SSU: FASTA + taxonomy

### Output Structure

```
results/
└── {sample}/
    ├── barrnap/
    │   ├── {sample}.bac.rRNA.gff
    │   ├── {sample}.arc.rRNA.gff
    │   ├── {sample}.euk.rRNA.gff
    │   └── {sample}.mito.rRNA.gff
    ├── combined_gff/
    │   └── {sample}.all.rRNA.gff
    ├── bed_coordinates/
    │   ├── {sample}.5s.bed
    │   ├── {sample}.5_8s.bed
    │   ├── {sample}.12s.bed
    │   ├── {sample}.16s.bed
    │   ├── {sample}.18s.bed
    │   ├── {sample}.23s.bed
    │   └── {sample}.28s.bed
    ├── extracted_sequences/
    │   ├── {sample}.5s.fa
    │   ├── {sample}.5_8s.fa
    │   ├── {sample}.12s.fa
    │   ├── {sample}.16s.fa
    │   ├── {sample}.18s.fa
    │   ├── {sample}.23s.fa
    │   └── {sample}.28s.fa
    ├── itsx/
    │   ├── {sample}.ITS1.fasta
    │   ├── {sample}.ITS2.fasta
    │   ├── {sample}.SSU.fasta
    │   ├── {sample}.LSU.fasta
    │   └── {sample}.summary.txt
    └── classifications/
        ├── {sample}.18S.DB_EUKARYOME_SSU.taxonomy
        ├── {sample}.18S.DB_EUKARYOME_SSU.tax.summary
        ├── {sample}.18S.DB_PR2_SSU.taxonomy
        ├── {sample}.18S.DB_PR2_SSU.tax.summary
        ├── {sample}.18S.DB_EUKARYOME_LONGREAD.taxonomy
        ├── {sample}.18S.DB_EUKARYOME_LONGREAD.tax.summary
        ├── {sample}.28S.DB_EUKARYOME_LSU.taxonomy
        ├── {sample}.28S.DB_EUKARYOME_LSU.tax.summary
        ├── {sample}.28S.DB_EUKARYOME_LONGREAD.taxonomy
        ├── {sample}.28S.DB_EUKARYOME_LONGREAD.tax.summary
        ├── {sample}.5_8S.DB_EUKARYOME_ITS.taxonomy
        ├── {sample}.5_8S.DB_EUKARYOME_ITS.tax.summary
        ├── {sample}.5_8S.DB_EUKARYOME_LONGREAD.taxonomy
        ├── {sample}.5_8S.DB_EUKARYOME_LONGREAD.tax.summary
        ├── {sample}.ITS1.DB_EUKARYOME_ITS.taxonomy
        ├── {sample}.ITS1.DB_EUKARYOME_ITS.tax.summary
        ├── {sample}.ITS1.DB_EUKARYOME_LONGREAD.taxonomy
        ├── {sample}.ITS1.DB_EUKARYOME_LONGREAD.tax.summary
        ├── {sample}.ITS2.DB_EUKARYOME_ITS.taxonomy
        ├── {sample}.ITS2.DB_EUKARYOME_ITS.tax.summary
        ├── {sample}.ITS2.DB_EUKARYOME_LONGREAD.taxonomy
        └── {sample}.ITS2.DB_EUKARYOME_LONGREAD.tax.summary
```

## Process Flow

```
Input Samplesheet (CSV)
    ↓
[DECOMPRESS_GENOME]  ← Handle .gz files
    ↓
[BARRNAP x4]  ← Run for bac, arc, euk, mito
    ↓
[COMBINE_GFF]  ← Merge all kingdom predictions
    ↓
[EXTRACT_BED]  ← Convert to BED coordinates (per rRNA type)
    ↓
[BEDTOOLS_GETFASTA]  ← Extract sequences (7 rRNA types)
    ↓
[ITSX]  ← Extract ITS1/ITS2 regions
    ↓
[MOTHUR_CLASSIFY]  ← Classify against multiple databases
    ↓
Results per sample (up to 12 classifications)
```

## Key Design Decisions

### Module Organization
- **Custom modules** (`modules/local/`) - Project-specific processes
- **nf-core modules** (`modules/nf-core/`) - Community-maintained tools (currently just multiqc template)

### Configuration Strategy
- **Base config** - Default resources for all processes
- **Modules config** - Override resources for specific processes
- **Database config** - Separate file for user-specific paths
- **Test configs** - Minimal and full test profiles

### Data Flow
- **Channel forking** - Automatic in DSL2, enables reuse
- **Per-sample processing** - Each sample independent
- **Conditional classification** - Can be disabled via parameter

### Output Publishing
- **Per-process directories** - Easy to navigate
- **Descriptive filenames** - Sample and type clearly indicated
- **Mode 'copy'** - Preserve original files in work directory

## Technical Specifications

### Language Version
- Nextflow DSL2
- Compatible with Nextflow 25.04+
- Uses strict syntax patterns where applicable

### Container Support
- Docker images available for all tools
- Singularity conversion supported
- Conda environments as fallback

### Resource Defaults
- CPUs: 4 per process
- Memory: 8 GB per process
- Time: Configurable per process
- Adjustable in `conf/base.config`

## Quality Assurance

### Validation
✅ All 32 Nextflow files pass linting
✅ Schema validation for parameters
✅ Input samplesheet validation
✅ Conditional execution based on file availability

### Error Handling
- Graceful handling of missing rRNA types
- Optional classification step
- Clear error messages
- Process-level retry logic

### Reproducibility
- Version-pinned containers
- Explicit tool versions in module names
- Configuration files under version control
- Work directory preservation for debugging
