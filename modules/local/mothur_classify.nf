process MOTHUR_CLASSIFY {
    tag "$meta.id - $sequence_type"
    label 'process_high'

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
    def cutoff = task.ext.cutoff ?: 80
    def output_name = "${prefix}.${sequence_type}"
    """
    mothur "#classify.seqs(fasta=${fasta}, \\
        template=${template_db}, \\
        taxonomy=${taxonomy_db}, \\
        cutoff=${cutoff}, \\
        processors=${task.cpus}, \\
        outputdir=., \\
        ${args})"

    # Rename output files to include sequence type
    if [ -f *.taxonomy ]; then
        mv *.taxonomy ${output_name}.taxonomy
    fi
    
    if [ -f *.tax.summary ]; then
        mv *.tax.summary ${output_name}.tax.summary
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mothur: \$(mothur --version | sed 's/Mothur version=//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def output_name = "${prefix}.${sequence_type}"
    """
    touch ${output_name}.taxonomy
    touch ${output_name}.tax.summary

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mothur: 1.48.0
    END_VERSIONS
    """
}
