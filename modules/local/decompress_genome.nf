process DECOMPRESS_GENOME {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::gzip=1.12"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gzip:1.12' :
        'biocontainers/gzip:1.12' }"

    input:
    tuple val(meta), path(genome)

    output:
    tuple val(meta), path("*.{fa,fasta,fna}"), emit: genome
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def output_name = genome.name.replaceAll(/\.gz$/, '')
    """
    gunzip -c ${genome} > ${output_name}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(echo \$(gunzip --version 2>&1) | sed 's/^.*(gzip) //; s/ Copyright.*\$//')
    END_VERSIONS
    """

    stub:
    def output_name = genome.name.replaceAll(/\.gz$/, '')
    """
    touch ${output_name}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(echo \$(gunzip --version 2>&1) | sed 's/^.*(gzip) //; s/ Copyright.*\$//')
    END_VERSIONS
    """
}
