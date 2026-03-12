/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DECOMPRESS_GENOME                    } from '../modules/local/decompress_genome/decompress_genome'
include { BARRNAP as BARRNAP_EUK               } from '../modules/nf-core/barrnap/main'
include { BARRNAP as BARRNAP_BAC               } from '../modules/nf-core/barrnap/main'
include { BARRNAP as BARRNAP_ARC               } from '../modules/nf-core/barrnap/main'
include { BARRNAP as BARRNAP_MITO              } from '../modules/nf-core/barrnap/main'
include { COMBINE_GFF                          } from '../modules/local/combine_gff/combine_gff'
include { EXTRACT_BED                          } from '../modules/local/extract_bed/extract_bed'
include { BEDTOOLS_GETFASTA                    } from '../modules/nf-core/bedtools/getfasta/main'
include { CLEAN_FASTA_HEADERS                  } from '../modules/local/clean_fasta_headers/clean_fasta_headers'
include { ITSX                                 } from '../modules/local/itsx/itsx'
include { BLAST_MAKEBLASTDB                    } from '../modules/nf-core/blast/makeblastdb/main'
include { BLAST_BLASTN as BLAST_BLASTN_OUTFMT0 } from '../modules/nf-core/blast/blastn/main'
include { BLAST_BLASTN as BLAST_BLASTN_OUTFMT6 } from '../modules/nf-core/blast/blastn/main'
include { MOTHUR_CLASSIFY                      } from '../modules/local/mothur_classify/mothur_classify'
include { paramsSummaryLog                     } from 'plugin/nf-schema'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ALGAE_TAXA {
    take:
    ch_input // channel: [ val(meta), path(genome) ]

    main:

    ch_versions = channel.empty()

    //
    // MODULE: Decompress genome files if compressed
    //
    ch_input
        .branch { _meta, genome ->
            compressed: genome.name.endsWith('.gz')
            decompressed: true
        }
        .set { ch_branched }

    DECOMPRESS_GENOME(
        ch_branched.compressed
    )

    ch_genome = ch_branched.decompressed.mix(DECOMPRESS_GENOME.out.genome)

    //
    // MODULE: Run BARRNAP for rRNA prediction across all four kingdoms
    //
    // The nf-core barrnap module expects: tuple val(meta), path(fasta), val(dbname)
    // The dbname must be embedded in the channel tuple, not passed as a separate param.
    //
    BARRNAP_EUK(
        ch_genome.map { meta, fasta -> [meta, fasta, 'euk'] }
    )
    ch_versions = ch_versions.mix(BARRNAP_EUK.out.versions)

    BARRNAP_BAC(
        ch_genome.map { meta, fasta -> [meta, fasta, 'bac'] }
    )
    ch_versions = ch_versions.mix(BARRNAP_BAC.out.versions)

    BARRNAP_ARC(
        ch_genome.map { meta, fasta -> [meta, fasta, 'arc'] }
    )
    ch_versions = ch_versions.mix(BARRNAP_ARC.out.versions)

    BARRNAP_MITO(
        ch_genome.map { meta, fasta -> [meta, fasta, 'mito'] }
    )
    ch_versions = ch_versions.mix(BARRNAP_MITO.out.versions)

    //
    // MODULE: Combine GFF files from all four kingdoms per sample
    //
    // Group all four GFFs together by meta, then pass as a list to COMBINE_GFF
    //
    ch_all_gffs = BARRNAP_EUK.out.gff
        .mix(BARRNAP_BAC.out.gff)
        .mix(BARRNAP_ARC.out.gff)
        .mix(BARRNAP_MITO.out.gff)
        .groupTuple(size: 4)

    COMBINE_GFF(
        ch_all_gffs
    )

    //
    // MODULE: Extract BED coordinates from combined GFF
    //
    EXTRACT_BED(
        COMBINE_GFF.out.gff,
        params.organism_type,
    )

    //
    // MODULE: Extract FASTA sequences using bedtools
    //
    // EXTRACT_BED emits [ meta, [bed1, bed2, ...] ] (one list of BED files per sample).
    // bedtools getfasta runs once per BED file, so we transpose to get
    // [ meta, bed ] per-file tuples.
    //
    // We store the BED file stem (e.g. "KAUST067.18s") in meta.bed_stem so that
    // modules.config can set  ext.prefix = { meta.bed_stem }  and each
    // BEDTOOLS_GETFASTA call produces a distinctly-named output like "KAUST067.18s.fa".
    // This preserves the rRNA type in the filename for downstream seq_type detection.
    //
    ch_bed_per_file = EXTRACT_BED.out.bed
        .transpose()
        .map { meta, bed ->
            def stem = bed.name.replaceAll(/\.bed$/, '')
            // e.g. "KAUST067.18s"
            [meta + [bed_stem: stem], bed]
        }
    // [ meta(+bed_stem), bed ] — one tuple per individual BED file

    // Pair each BED file with its own sample's genome fasta by joining on meta.id.
    // This is critical: ch_genome is a queue channel (10 items), so passing it directly
    // as the second input to BEDTOOLS_GETFASTA would zip it 1:1 with the 70 BED files,
    // leaving 60 tasks without a fasta and silently dropping them.
    // Instead we combine by sample ID so every BED file gets the correct genome.
    ch_bed_genome = ch_bed_per_file
        .map { meta, bed -> [meta.id, meta, bed] }
        .combine(
            ch_genome.map { meta, fasta -> [meta.id, fasta] },
            by: 0
        )
        .map { _id, meta, bed, fasta -> [[meta, bed], fasta] }
        .multiMap { bed_tuple, fasta ->
            bed: bed_tuple
            fasta: fasta
        }

    BEDTOOLS_GETFASTA(
        ch_bed_genome.bed,
        ch_bed_genome.fasta,
    )
    ch_versions = ch_versions.mix(BEDTOOLS_GETFASTA.out.versions_bedtools.first())

    // TODO: ADD A SEQKIT MODULE TO FILTER OUT ANY DUPLICATE READS

    //
    // MODULE: Clean FASTA headers — remove spaces to keep metadata about rRNA mapping in header
    //
    CLEAN_FASTA_HEADERS(
        BEDTOOLS_GETFASTA.out.fasta
    )
    ch_versions = ch_versions.mix(CLEAN_FASTA_HEADERS.out.versions.first())

    //
    // MODULE: Run ITSx for ITS extraction (only for eukaryotes)
    //
    if (params.organism_type == 'eukaryotic') {
        // Add organism_code to meta for ITSx — 'G' = Chlorophyta (green algae)
        ch_genome_with_organism = ch_genome.map { meta, genome ->
            def new_meta = meta + [organism_code: 'G']
            [new_meta, genome]
        }

        ITSX(ch_genome_with_organism)
        ch_versions = ch_versions.mix(ITSX.out.versions.first())
    }

    //
    // MODULE: Mothur classification for eukaryotic sequences
    //
    ch_classifications = channel.empty()
    ch_blast_results = channel.empty()

    if (params.organism_type == 'eukaryotic' && params.run_mothur_classification) {

        // Prepare classification inputs by combining sequences with database info
        // Create a channel with all sequence/database combinations to classify

        // Get extracted rRNA sequences from the cleaned bedtools output.
        // Each CLEAN_FASTA_HEADERS call already emits a single [meta, fasta] tuple
        // (no transpose needed). The filename stem is e.g. "KAUST067.18s.fa",
        // so we detect the rRNA type from the BED stem stored in meta.bed_stem.
        def ch_rrna_for_classification = CLEAN_FASTA_HEADERS.out.fasta
            .filter { _meta, fasta -> fasta.size() > 0 }
            .map { meta, fasta ->
                def seq_type = null
                def stem = meta.bed_stem ?: fasta.name
                // e.g. "KAUST067.18s"

                // Determine sequence type from the bed stem (lowercase rRNA type)
                if (stem.endsWith('.18s')) {
                    seq_type = '18S'
                }
                else if (stem.endsWith('.28s')) {
                    seq_type = '28S'
                }
                else if (stem.endsWith('.5_8s')) {
                    seq_type = '5_8S'
                }
                // 16S / 23S / 12S / 5S are prokaryotic — skip for eukaryotic classification

                return seq_type ? [meta, fasta, seq_type] : null
            }
            .filter { v -> v != null }

        // Get ITS sequences from ITSx (always eukaryotic here — outer guard ensures this)
        // Filter out blank FASTA files — ITSx may produce empty output when no ITS is detected
        def ch_its1 = ITSX.out.its1
            .filter { _meta, fasta -> fasta.size() > 0 }
            .map { meta, fasta -> [meta, fasta, 'ITS1'] }
        def ch_its2 = ITSX.out.its2
            .filter { _meta, fasta -> fasta.size() > 0 }
            .map { meta, fasta -> [meta, fasta, 'ITS2'] }
        def ch_its_for_classification = ch_its1.mix(ch_its2)

        // Combine all sequences for classification
        def ch_all_seqs = ch_rrna_for_classification.mix(ch_its_for_classification)

        // Create database configurations based on sequence type
        def ch_seq_with_dbs = ch_all_seqs
            .flatMap { meta, fasta, seq_type ->
                def combinations = []

                // 18S classifications
                if (seq_type == '18S') {
                    if (params.eukaryome_ssu_fasta && params.eukaryome_ssu_taxonomy) {
                        combinations << [
                            meta,
                            fasta,
                            seq_type,
                            'EUKARYOME_SSU',
                            file(params.eukaryome_ssu_fasta),
                            file(params.eukaryome_ssu_taxonomy),
                        ]
                    }
                    if (params.pr2_ssu_fasta && params.pr2_ssu_taxonomy) {
                        combinations << [
                            meta,
                            fasta,
                            seq_type,
                            'PR2_SSU',
                            file(params.pr2_ssu_fasta),
                            file(params.pr2_ssu_taxonomy),
                        ]
                    }
                    if (params.eukaryome_longread_fasta && params.eukaryome_longread_taxonomy) {
                        combinations << [
                            meta,
                            fasta,
                            seq_type,
                            'EUKARYOME_LONGREAD',
                            file(params.eukaryome_longread_fasta),
                            file(params.eukaryome_longread_taxonomy),
                        ]
                    }
                }
                else if (seq_type == '28S') {
                    if (params.eukaryome_lsu_fasta && params.eukaryome_lsu_taxonomy) {
                        combinations << [
                            meta,
                            fasta,
                            seq_type,
                            'EUKARYOME_LSU',
                            file(params.eukaryome_lsu_fasta),
                            file(params.eukaryome_lsu_taxonomy),
                        ]
                    }
                    if (params.eukaryome_longread_fasta && params.eukaryome_longread_taxonomy) {
                        combinations << [
                            meta,
                            fasta,
                            seq_type,
                            'EUKARYOME_LONGREAD',
                            file(params.eukaryome_longread_fasta),
                            file(params.eukaryome_longread_taxonomy),
                        ]
                    }
                }
                else if (seq_type in ['5_8S', 'ITS1', 'ITS2']) {
                    if (params.eukaryome_its_fasta && params.eukaryome_its_taxonomy) {
                        combinations << [
                            meta,
                            fasta,
                            seq_type,
                            'EUKARYOME_ITS',
                            file(params.eukaryome_its_fasta),
                            file(params.eukaryome_its_taxonomy),
                        ]
                    }
                    if (params.eukaryome_longread_fasta && params.eukaryome_longread_taxonomy) {
                        combinations << [
                            meta,
                            fasta,
                            seq_type,
                            'EUKARYOME_LONGREAD',
                            file(params.eukaryome_longread_fasta),
                            file(params.eukaryome_longread_taxonomy),
                        ]
                    }
                }

                return combinations
            }
            .map { meta, fasta, seq_type, db_name, ref_fasta, ref_tax ->
                // Create new meta with sequence type and database info
                def new_meta = meta + [seq_type: seq_type, database: db_name]
                [new_meta, fasta, seq_type, ref_fasta, ref_tax]
            }

        // Run mothur classification
        MOTHUR_CLASSIFY(ch_seq_with_dbs)
        ch_versions = ch_versions.mix(MOTHUR_CLASSIFY.out.versions.first())
        ch_classifications = MOTHUR_CLASSIFY.out.taxonomy.mix(MOTHUR_CLASSIFY.out.summary)

        // TODO: ADD A MODULE TO SUMMARIZE THE MOTHUR RESULTS

        //
        // MODULE: Create BLAST databases and run BLASTN
        //
        // Collect unique reference FASTA files and create BLAST databases
        def ch_unique_ref_fastas = ch_seq_with_dbs
            .map { meta, fasta, seq_type, ref_fasta, ref_tax ->
                // Create a unique identifier for each database
                def db_meta = [id: ref_fasta.simpleName]
                [db_meta, ref_fasta]
            }
            .unique { meta, ref_fasta -> meta.id }

        // TODO: FIGURE OUT HOW TO CORRELATE TAXID INFO WITH BLASTDB OR BLAST RESULTS
        // something like this
        // awk 'BEGIN{FS="\t"} 
        //      FNR==NR {tax[$1]=$2; next} 
        //      /^>/ {id=substr($0,2); if(id in tax) print ">"id"__"tax[id]; else print $0; next} 
        //      {print}' mothur_EUK_SSU_v2.0.tax mothur_EUK_SSU_v2.0.fasta

        // Create BLAST databases
        // TODO: FIGURE OUT WHY THIS IS STILL BEING ADDED TO YOUR OUTPUTS BUT ITS NOT IN PUBLISHDIR
        BLAST_MAKEBLASTDB(ch_unique_ref_fastas)
        ch_versions = ch_versions.mix(BLAST_MAKEBLASTDB.out.versions_makeblastdb.first())

        // Prepare channel for BLASTN by combining query sequences with BLAST databases
        // ch_seq_with_dbs emits: [meta, fasta, seq_type, ref_fasta, ref_tax]
        // We need to match each query with its corresponding BLAST database
        def ch_blast_input = ch_seq_with_dbs
            .map { meta, fasta, seq_type, ref_fasta, ref_tax ->
                def db_id = ref_fasta.simpleName
                [db_id, meta, fasta]
            }
            .combine(
                BLAST_MAKEBLASTDB.out.db.map { db_meta, db -> [db_meta.id, db] },
                by: 0
            )
            .map { db_id, meta, fasta, db ->
                [
                    [meta, fasta],
                    [meta, db],
                ]
            }

        // Run BLASTN
        BLAST_BLASTN_OUTFMT0(
            ch_blast_input.map { ch_fa_and_db -> ch_fa_and_db[0] },
            ch_blast_input.map { ch_fa_and_db -> ch_fa_and_db[1] },
            [],
            [],
            [],
        )
        ch_versions = ch_versions.mix(BLAST_BLASTN_OUTFMT0.out.versions_blastn.first())
        ch_blast_results = BLAST_BLASTN_OUTFMT0.out.txt

        BLAST_BLASTN_OUTFMT6(
            ch_blast_input.map { ch_fa_and_db -> ch_fa_and_db[0] },
            ch_blast_input.map { ch_fa_and_db -> ch_fa_and_db[1] },
            [],
            [],
            [],
        )
        ch_versions = ch_versions.mix(BLAST_BLASTN_OUTFMT6.out.versions_blastn.first())
        ch_blast_results = BLAST_BLASTN_OUTFMT6.out.txt
    }

    emit:
    gff             = COMBINE_GFF.out.gff // channel: [ val(meta), path(gff) ]
    bed             = EXTRACT_BED.out.bed // channel: [ val(meta), path(bed) ]
    fasta           = CLEAN_FASTA_HEADERS.out.fasta // channel: [ val(meta), path(fastas) ]
    its1            = params.organism_type == 'eukaryotic' ? ITSX.out.its1 : channel.empty()
    its2            = params.organism_type == 'eukaryotic' ? ITSX.out.its2 : channel.empty()
    ssu             = params.organism_type == 'eukaryotic' ? ITSX.out.ssu : channel.empty()
    lsu             = params.organism_type == 'eukaryotic' ? ITSX.out.lsu : channel.empty()
    classifications = ch_classifications // channel: [ val(meta), path(taxonomy/summary) ]
    blast_results   = ch_blast_results // channel: [ val(meta), path(blast_txt) ]
    versions        = ch_versions // channel: [ path(versions) ]
}
