/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DECOMPRESS_GENOME       } from '../modules/local/decompress_genome/decompress_genome'
include { BARRNAP as BARRNAP_EUK  } from '../modules/nf-core/barrnap/main'
include { BARRNAP as BARRNAP_BAC  } from '../modules/nf-core/barrnap/main'
include { BARRNAP as BARRNAP_ARC  } from '../modules/nf-core/barrnap/main'
include { BARRNAP as BARRNAP_MITO } from '../modules/nf-core/barrnap/main'
include { COMBINE_GFF             } from '../modules/local/combine_gff/combine_gff'
include { EXTRACT_BED             } from '../modules/local/extract_bed/extract_bed'
include { BEDTOOLS_GETFASTA       } from '../modules/nf-core/bedtools/getfasta/main'
include { ITSX                    } from '../modules/local/itsx/itsx'
include { MOTHUR_CLASSIFY         } from '../modules/local/mothur_classify/mothur_classify'
include { paramsSummaryLog        } from 'plugin/nf-schema'

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
        .groupTuple()

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
    // [ meta, bed ] per-file tuples, then join the genome FASTA (bare path, no meta)
    // as the second input channel.
    //
    ch_bed_per_file = EXTRACT_BED.out.bed
        .transpose() // [ meta, bed ] — one tuple per individual BED file

    BEDTOOLS_GETFASTA(
        ch_bed_per_file,                           // input[0]: tuple val(meta), path(bed)
        ch_genome.map { _meta, fasta -> fasta }    // input[1]: path fasta (bare, no meta)
    )
    ch_versions = ch_versions.mix(BEDTOOLS_GETFASTA.out.versions_bedtools.first())

    //
    // MODULE: Run ITSx for ITS extraction (only for eukaryotes)
    //
    if (params.organism_type == 'eukaryotic') {
        // Add organism_type to meta for ITSx
        ch_genome_with_organism = ch_genome.map { meta, genome ->
            def new_meta = meta + [organism_type: params.itsx_organism_code]
            [new_meta, genome]
        }

        ITSX(ch_genome_with_organism)
        ch_versions = ch_versions.mix(ITSX.out.versions.first())
    }

    //
    // MODULE: Mothur classification for eukaryotic sequences
    //
    ch_classifications = channel.empty()

    if (params.organism_type == 'eukaryotic' && params.run_mothur_classification) {

        // Prepare classification inputs by combining sequences with database info
        // Create a channel with all sequence/database combinations to classify

        // Get extracted rRNA sequences from bedtools output
        def ch_rrna_for_classification = BEDTOOLS_GETFASTA.out.fasta
            .transpose()
            .map { meta, fasta ->
                def filename = fasta.name
                def seq_type = null

                // Determine sequence type from filename
                if (filename.contains('.18s.')) {
                    seq_type = '18S'
                }
                else if (filename.contains('.28s.')) {
                    seq_type = '28S'
                }
                else if (filename.contains('.5_8s.')) {
                    seq_type = '5_8S'
                }
                else if (filename.contains('.16s.')) {
                    seq_type = '16S'
                }
                else if (filename.contains('.23s.')) {
                    seq_type = '23S'
                }

                return seq_type ? [meta, fasta, seq_type] : null
            }
            .filter { it != null }

        // Get ITS sequences from ITSx
        def ch_its_for_classification = channel.empty()
        if (params.organism_type == 'eukaryotic') {
            def ch_its1 = ITSX.out.its1.map { meta, fasta -> [meta, fasta, 'ITS1'] }
            def ch_its2 = ITSX.out.its2.map { meta, fasta -> [meta, fasta, 'ITS2'] }
            ch_its_for_classification = ch_its1.mix(ch_its2)
        }

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
    }

    emit:
    gff             = COMBINE_GFF.out.gff // channel: [ val(meta), path(gff) ]
    bed             = EXTRACT_BED.out.bed // channel: [ val(meta), path(bed) ]
    fasta           = BEDTOOLS_GETFASTA.out.fasta // channel: [ val(meta), path(fastas) ]
    its1            = params.organism_type == 'eukaryotic' ? ITSX.out.its1 : channel.empty()
    its2            = params.organism_type == 'eukaryotic' ? ITSX.out.its2 : channel.empty()
    ssu             = params.organism_type == 'eukaryotic' ? ITSX.out.ssu : channel.empty()
    lsu             = params.organism_type == 'eukaryotic' ? ITSX.out.lsu : channel.empty()
    classifications = ch_classifications // channel: [ val(meta), path(taxonomy/summary) ]
    versions        = ch_versions // channel: [ path(versions) ]
}
