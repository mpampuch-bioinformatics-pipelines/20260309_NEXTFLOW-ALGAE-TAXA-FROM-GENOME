# Implementation Summary: Taxonomy Annotation for BLAST Databases

## Overview
Successfully implemented a solution to annotate BLAST database FASTA files with taxonomy information, resolving the TODO comment about correlating taxonomy IDs with BLAST results.

## Problem Solved
Previously, BLAST databases were created from raw reference FASTA files without taxonomy annotation. This made it difficult to interpret BLAST results as the subject IDs lacked taxonomic context. The workflow had a TODO comment:

```groovy
// TODO: FIGURE OUT HOW TO CORRELATE TAXID INFO WITH BLASTDB OR BLAST RESULTS
```

## Solution Implemented

### 1. New Process: `APPEND_MOTHUR_TAXONOMY_TO_DB`
**Location**: `modules/local/append_taxonomy_to_db/append_mothur_taxonomy_to_db.nf`

**Purpose**: Annotates FASTA headers with taxonomy information using the mothur format (double underscore separator: `>seqid__taxonomy`).

**Implementation**:
- Uses `awk` for efficient text processing
- Reads taxonomy mapping from mothur `.tax` files
- Appends taxonomy to sequence IDs using `__` separator
- Handles sequences without taxonomy mappings gracefully
- Includes proper version tracking and stub mode

**Input**:
- `tuple val(meta), path(fasta)`: Reference FASTA file
- `path taxonomy`: Mothur taxonomy file (tab-separated: seqid<TAB>taxonomy)

**Output**:
- `tuple val(meta), path("*.annotated.fasta")`: Annotated FASTA file
- `path "versions.yml"`: Version information

### 2. Workflow Integration
**Location**: `workflows/algae_taxa.nf` (lines 318-349)

**Changes Made**:

#### Before:
```groovy
// Collect unique reference FASTAs
def ch_unique_ref_fastas = ch_seq_with_dbs
    .map { ... }
    .unique { ... }

// Create BLAST databases directly from raw FASTAs
BLAST_MAKEBLASTDB(ch_unique_ref_fastas)
```

#### After:
```groovy
// Collect unique reference FASTAs WITH taxonomy files
def ch_unique_ref_fastas_with_tax = ch_seq_with_dbs
    .map { _meta, _fasta, _seq_type, ref_fasta, ref_tax ->
        def db_meta = [id: ref_fasta.simpleName]
        [db_meta, ref_fasta, ref_tax]
    }
    .unique { meta, _ref_fasta, _ref_tax -> meta.id }

// Annotate FASTAs with taxonomy
APPEND_MOTHUR_TAXONOMY_TO_DB(
    ch_unique_ref_fastas_with_tax.map { meta, ref_fasta, _ref_tax -> [meta, ref_fasta] },
    ch_unique_ref_fastas_with_tax.map { _meta, _ref_fasta, ref_tax -> ref_tax }
)

// Create BLAST databases from annotated FASTAs
BLAST_MAKEBLASTDB(APPEND_MOTHUR_TAXONOMY_TO_DB.out.fasta)
```

### 3. Include Statement Added
**Location**: `workflows/algae_taxa.nf` (line 17)

```groovy
include { APPEND_MOTHUR_TAXONOMY_TO_DB   } from '../modules/local/append_taxonomy_to_db/append_mothur_taxonomy_to_db'
```

## Benefits

1. **Enhanced BLAST Results**: BLAST output now includes taxonomy in subject IDs, making results immediately interpretable
2. **Format Compatibility**: Uses standard mothur format (`__` separator) compatible with downstream analysis tools
3. **Efficiency**: Annotation happens once per unique database before BLAST database creation
4. **Maintainability**: Clean modular design with proper version tracking
5. **Robustness**: Handles missing taxonomy gracefully, includes stub mode for testing

## Testing & Validation

### Lint Check: ✅ PASSED
```bash
$ nextflow lint workflows/algae_taxa.nf
Nextflow linting complete!
 ✅ 12 files had no errors
```

### Configuration Check: ✅ PASSED
```bash
$ nextflow config -profile test
# Successfully parsed all parameters
```

## Example Output Format

**Before** (unannotated):
```
>AY425968.1.1813
ACGTACGTACGT...
```

**After** (annotated):
```
>AY425968.1.1813__Eukaryota;Archaeplastida;Chlorophyta;Chlorodendrophyceae;Chlorodendrales;Chlorodendraceae;Tetraselmis;
ACGTACGTACGT...
```

## Files Modified

1. **Created**: `modules/local/append_taxonomy_to_db/append_mothur_taxonomy_to_db.nf`
   - New process for taxonomy annotation
   
2. **Created**: `modules/local/append_taxonomy_to_db/environment.yml`
   - Conda environment specification (gawk)
   
3. **Modified**: `workflows/algae_taxa.nf`
   - Added include statement (line 17)
   - Integrated annotation step before BLAST database creation (lines 318-349)
   - Fixed linting warnings with `_` prefix for unused closure parameters

## Technical Details

### AWK Script Explanation
```awk
BEGIN{FS="\t"}                    # Set field separator to tab
FNR==NR {tax[$1]=$2; next}        # First file (taxonomy): build lookup hash
/^>/ {                             # FASTA headers
    id=substr($0,2);              # Extract ID (remove '>')
    if(id in tax)                 # If taxonomy exists
        print ">"id"__"tax[id];   # Append taxonomy with __ separator
    else 
        print $0;                 # Otherwise keep original header
    next
}
{print}                            # Print sequence lines as-is
```

### Performance Characteristics
- **Time Complexity**: O(n) for taxonomy lookup creation + O(m) for FASTA processing
- **Memory**: Stores taxonomy mapping in memory (typically <100MB for eukaryotic databases)
- **Efficiency**: Single-pass processing of FASTA file

## Future Enhancements (Optional)

1. **Configurable Separator**: Add parameter to customize the separator (currently hardcoded as `__`)
2. **Multiple Taxonomy Formats**: Support for other taxonomy file formats beyond mothur
3. **Validation**: Add optional taxonomy validation/reporting
4. **Compression**: Support for gzip-compressed input/output

## Conclusion

This implementation successfully resolves the TODO about correlating taxonomy with BLAST databases. The solution is:
- ✅ Clean and modular
- ✅ Efficient and scalable
- ✅ Well-documented
- ✅ Lint-compliant
- ✅ Compatible with existing workflow structure

The BLAST databases are now created with taxonomy-annotated sequences, making downstream analysis and interpretation significantly easier.
