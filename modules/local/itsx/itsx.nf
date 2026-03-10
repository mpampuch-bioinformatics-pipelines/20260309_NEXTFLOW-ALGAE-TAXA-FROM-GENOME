process ITSX {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::itsx=1.1.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/itsx:1.1.3--hdfd78af_1' :
        'quay.io/biocontainers/itsx:1.1.3--hdfd78af_1' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.ITS1.fasta")      , optional: true, emit: its1
    tuple val(meta), path("*.ITS2.fasta")      , optional: true, emit: its2
    tuple val(meta), path("*.full.fasta")      , optional: true, emit: full
    tuple val(meta), path("*.SSU.fasta")       , optional: true, emit: ssu
    tuple val(meta), path("*.LSU.fasta")       , optional: true, emit: lsu
    tuple val(meta), path("*.5_8S.fasta")      , optional: true, emit: s58
    tuple val(meta), path("*.summary.txt")     , emit: summary
    tuple val(meta), path("*.positions.txt")   , optional: true, emit: positions
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def organism_type = meta.organism_type ?: 'all'
    """
    ITSx \\
        -i ${fasta} \\
        -o ${prefix} \\
        --cpu ${task.cpus} \\
        --organism_type ${organism_type} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        itsx: \$(ITSx -h | grep 'Version:' | sed 's/Version: //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.ITS1.fasta
    touch ${prefix}.ITS2.fasta
    touch ${prefix}.full.fasta
    touch ${prefix}.SSU.fasta
    touch ${prefix}.LSU.fasta
    touch ${prefix}.5_8S.fasta
    touch ${prefix}.summary.txt
    touch ${prefix}.positions.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        itsx: 1.1.3
    END_VERSIONS
    """
}
