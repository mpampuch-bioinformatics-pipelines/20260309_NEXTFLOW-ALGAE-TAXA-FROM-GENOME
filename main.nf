#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Algae Taxa from Genome Pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/mpampuch-bioinformatics-pipelines/20260309_NEXTFLOW-ALGAE-TAXA-FROM-GENOME
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ALGAE_TAXA              } from './workflows/algae_taxa'
include { paramsSummaryLog        } from 'plugin/nf-schema'
include { validateParameters      } from 'plugin/nf-schema'
include { paramsSummaryMap        } from 'plugin/nf-schema'
include { samplesheetToList       } from 'plugin/nf-schema'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline
//
workflow NFCORE_ALGAE_TAXA {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    //
    // WORKFLOW: Run algae taxa analysis
    //
    ALGAE_TAXA (
        ch_samplesheet
    )

    emit:
    gff         = ALGAE_TAXA.out.gff
    bed         = ALGAE_TAXA.out.bed
    fasta       = ALGAE_TAXA.out.fasta
    its         = ALGAE_TAXA.out.its
    taxonomy    = ALGAE_TAXA.out.taxonomy
    tax_summary = ALGAE_TAXA.out.tax_summary
    versions    = ALGAE_TAXA.out.versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    //
    // Validate parameters
    //
    validateParameters()

    //
    // Print parameter summary
    //
    log.info paramsSummaryLog(workflow)

    //
    // Create input channel from samplesheet
    //
    ch_input = channel.fromList(samplesheetToList(params.input, "assets/schema_input.json"))

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_ALGAE_TAXA (
        ch_input
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
