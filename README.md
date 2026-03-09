# Algae Taxa from Genome Pipeline

## Introduction

**Algae Taxa from Genome** is a bioinformatics pipeline that extracts taxonomically relevant sequences (rRNA, ITS) from whole algal genomes and classifies them against multiple reference databases. The pipeline takes assembled genome files as input and produces taxonomic classifications for 18S, 28S, 5.8S rRNA, and ITS1/ITS2 sequences.

## Pipeline Steps

The pipeline performs the following steps:

1. **Decompress genomes** - Automatically handles gzipped genome files
2. **rRNA prediction** - Uses barrnap to identify rRNA genes across bacterial, archaeal, eukaryotic, and mitochondrial kingdoms
3. **GFF combination** - Merges rRNA predictions from all kingdoms
4. **Coordinate extraction** - Converts GFF annotations to BED format for each rRNA type
5. **Sequence extraction** - Uses bedtools to extract FASTA sequences for each rRNA
6. **ITS extraction** - Uses ITSx to identify and extract ITS1, ITS2, SSU, and LSU sequences
7. **Taxonomic classification** - Uses mothur to classify sequences against multiple databases:
   - **18S sequences**: EUKARYOME SSU, PR2 SSU, EUKARYOME longread
   - **28S sequences**: EUKARYOME LSU, EUKARYOME longread
   - **5.8S/ITS sequences**: EUKARYOME ITS, EUKARYOME longread

## Quick Start

### 1. Prepare Input Samplesheet

Create a CSV file with your genome samples:

```csv
sample,genome
KAUST067,/path/to/KAUST067_purged.fa
KAUST068,/path/to/KAUST068_purged.fa.gz
KAUST069,/path/to/KAUST069_purged.fasta
```

Each row represents a genome assembly file. The pipeline automatically handles gzipped files.

### 2. Configure Database Paths

Edit `conf/databases.config` with your database paths or pass them as command-line parameters (see `DOCS/example_commands.md` for details).

### 3. Run the Pipeline

```bash
nextflow run main.nf \
   -c conf/databases.config \
   --input samplesheet.csv \
   --outdir results \
   --organism_type eukaryotic \
   --itsx_organism_code G
```

Available organism codes for ITSx (`--itsx_organism_code`):
- `G` = Chlorophyta (green algae) - **default**
- `H` = Rhodophyta (red algae)
- `I` = Phaeophyceae (brown algae)
- `P` = Haptophyceae
- `C` = Bacillariophyta (diatoms)

See **`DOCS/example_commands.md`** for comprehensive usage examples.

> [!NOTE]
> This pipeline requires reference databases from EUKARYOME and PR2. See `conf/databases.config` for required database paths.

## Parameters

### Required Parameters
- `--input`: Path to samplesheet CSV file
- `--outdir`: Output directory for results

### Database Parameters
Configure in `conf/databases.config` or pass via command line:
- `--eukaryome_ssu_fasta` / `--eukaryome_ssu_taxonomy`: EUKARYOME SSU database
- `--eukaryome_lsu_fasta` / `--eukaryome_lsu_taxonomy`: EUKARYOME LSU database
- `--eukaryome_its_fasta` / `--eukaryome_its_taxonomy`: EUKARYOME ITS database
- `--eukaryome_longread_fasta` / `--eukaryome_longread_taxonomy`: EUKARYOME longread database
- `--pr2_ssu_fasta` / `--pr2_ssu_taxonomy`: PR2 SSU database

### Optional Parameters
- `--run_mothur_classification`: Enable/disable taxonomic classification (default: `true`)
- `--organism_type`: Organism type for barrnap (default: `"eukaryotic"`)
- `--itsx_organism_code`: Organism code for ITSx (default: `"G"` for Chlorophyta)
- `--mothur_cutoff`: Bootstrap confidence cutoff for mothur (default: `80`)

## Credits

nf-core/pipeline was originally written by Mark Pampuch.

We thank the following people for their extensive assistance in the development of this pipeline:

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use nf-core/pipeline for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
