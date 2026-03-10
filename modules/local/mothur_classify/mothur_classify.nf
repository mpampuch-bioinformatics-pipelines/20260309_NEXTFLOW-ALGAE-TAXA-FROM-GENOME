process MOTHUR_CLASSIFY {
    tag "$meta.id - $meta.seq_type - $meta.database"
    label 'process_high'
    publishDir "${params.outdir}/${meta.id}/classifications", mode: params.publish_dir_mode

    conda "bioconda::mothur=1.48.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mothur:1.48.0--h43eeafb_0' :
        'quay.io/biocontainers/mothur:1.48.0--h43eeafb_0' }"

    input:
    tuple val(meta), path(fasta), val(sequence_type), path(template_db), path(taxonomy_db)

    output:
    tuple val(meta), path("*.taxonomy")     , emit: taxonomy
    tuple val(meta), path("*.tax.summary")  , emit: summary
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def cutoff = params.mothur_cutoff ?: 80
    def database = meta.database ?: 'unknown'
    def output_name = "${prefix}.${sequence_type}.DB_${database}"
    """
    # Run mothur classify.seqs
    mothur "#classify.seqs(fasta=${fasta}, \\
        template=${template_db}, \\
        taxonomy=${taxonomy_db}, \\
        cutoff=${cutoff}, \\
        processors=${task.cpus}, \\
        probs=T, \\
        outputdir=., \\
        ${args})"

    # Rename output files to include sequence type and database
    # Mothur creates files with the input filename as base
    BASE=\$(basename ${fasta} | sed 's/\\.fa.*\$//')
    
    if [ -f \${BASE}.*.wang.taxonomy ]; then
        mv \${BASE}.*.wang.taxonomy ${output_name}.taxonomy
    fi
    
    if [ -f \${BASE}.*.wang.tax.summary ]; then
        mv \${BASE}.*.wang.tax.summary ${output_name}.tax.summary
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mothur: \$(mothur --version 2>&1 | grep -oP 'version=\\K[0-9.]+' || echo "1.48.0")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def database = meta.database ?: 'unknown'
    def output_name = "${prefix}.${sequence_type}.DB_${database}"
    """
    touch ${output_name}.taxonomy
    touch ${output_name}.tax.summary

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mothur: 1.48.0
    END_VERSIONS
    """
}
