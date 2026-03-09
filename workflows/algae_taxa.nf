/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DECOMPRESS_GENOME       } from '../modules/local/decompress_genome'
include { BARRNAP                 } from '../modules/local/barrnap'
include { COMBINE_GFF             } from '../modules/local/combine_gff'
include { EXTRACT_BED             } from '../modules/local/extract_bed'
include { BEDTOOLS_GETFASTA       } from '../modules/local/bedtools_getfasta'
include { ITSX                    } from '../modules/local/itsx'
include { MOTHUR_CLASSIFY         } from '../modules/local/mothur_classify'
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

    ch_genome = ch_branched.decompressed
        .mix(DECOMPRESS_GENOME.out.genome)

    //
    // MODULE: Run BARRNAP for rRNA prediction
    //
    BARRNAP(
        ch_genome,
        params.organism_type
    )
    ch_versions = ch_versions.mix(BARRNAP.out.versions)

    //
    // MODULE: Combine GFF files from different kingdoms
    //
    COMBINE_GFF(
        BARRNAP.out.gff
    )

    //
    // MODULE: Extract BED coordinates from combined GFF
    //
    EXTRACT_BED(
        COMBINE_GFF.out.gff,
        params.organism_type
    )

    //
    // MODULE: Extract FASTA sequences using bedtools
    //
    BEDTOOLS_GETFASTA(
        ch_genome
            .join(EXTRACT_BED.out.bed)
    )
    ch_versions = ch_versions.mix(BEDTOOLS_GETFASTA.out.versions.first())

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
    // TEMPORARY PLACEHOLDER: Classification module needs to be implemented
    // This would classify rRNA/ITS sequences using appropriate databases
    //

    emit:
    gff          = COMBINE_GFF.out.gff         // channel: [ val(meta), path(gff) ]
    bed          = EXTRACT_BED.out.bed         // channel: [ val(meta), path(bed) ]
    fasta        = BEDTOOLS_GETFASTA.out.fasta // channel: [ val(meta), path(fastas) ]
    its1         = params.organism_type == 'eukaryotic' ? ITSX.out.its1 : channel.empty()
    its2         = params.organism_type == 'eukaryotic' ? ITSX.out.its2 : channel.empty()
    ssu          = params.organism_type == 'eukaryotic' ? ITSX.out.ssu : channel.empty()
    lsu          = params.organism_type == 'eukaryotic' ? ITSX.out.lsu : channel.empty()
    versions     = ch_versions                      // channel: [ path(versions) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
