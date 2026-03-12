process APPEND_MOTHUR_TAXONOMY_TO_DB {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.1.0' :
        'biocontainers/gawk:5.1.0' }"

    input:
    tuple val(meta), path(fasta)
    path taxonomy

    output:
    tuple val(meta), path("*.annotated.fasta"), emit: fasta
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    awk 'BEGIN{FS="\\t"} \\
        FNR==NR {tax[\$1]=\$2; next} \\
        /^>/ {id=substr(\$0,2); if(id in tax) print ">"id"__"tax[id]; else print \$0; next} \\
        {print}' \\
        ${taxonomy} \\
        ${fasta} \\
        > ${prefix}.annotated.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk --version | head -n1 | sed 's/^GNU Awk //; s/, .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.annotated.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk --version | head -n1 | sed 's/^GNU Awk //; s/, .*\$//')
    END_VERSIONS
    """
}
