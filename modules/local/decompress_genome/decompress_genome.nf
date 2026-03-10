process DECOMPRESS_GENOME {
    tag "${meta.id}"
    label 'process_low'

    conda "conda-forge::gzip=1.12"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/f9/f9bfad58c74343625d23685a5ea7006c3c154eec7ad85584b8474d7bd8ec956c/data'
        : 'community.wave.seqera.io/library/gzip:1.14--19aaa2c84c85ddbc'}"

    input:
    tuple val(meta), path(genome)

    output:
    tuple val(meta), path("*.{fa,fasta,fna}"), emit: genome
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def output_name = genome.name.replaceAll(/\.gz$/, '').replaceAll(/\.(fasta|fna)$/, '.fa')
    """
    gunzip -c ${genome} > ${output_name}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(echo \$(gunzip --version 2>&1) | sed 's/^.*(gzip) //; s/ Copyright.*\$//')
    END_VERSIONS
    """

    stub:
    def output_name = genome.name.replaceAll(/\.gz$/, '').replaceAll(/\.(fasta|fna)$/, '.fa')
    """
    touch ${output_name}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(echo \$(gunzip --version 2>&1) | sed 's/^.*(gzip) //; s/ Copyright.*\$//')
    END_VERSIONS
    """
}
