process BEDTOOLS_GETFASTA {
    tag "$meta.id - $bed_file.simpleName"
    label 'process_single'

    conda "bioconda::bedtools=2.31.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bedtools:2.31.1--hf5e1c6e_0' :
        'quay.io/biocontainers/bedtools:2.31.1--hf5e1c6e_0' }"

    input:
    tuple val(meta), path(bed_file), path(fasta)

    output:
    tuple val(meta), path("*.fasta"), emit: fasta
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def bed_name = bed_file.simpleName.replaceAll("${meta.id}\\.", '')
    def output_name = "${prefix}.${bed_name}.fasta"
    """
    bedtools getfasta \\
        -fi ${fasta} \\
        -bed ${bed_file} \\
        -fo ${output_name} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bedtools: \$(bedtools --version | sed 's/bedtools v//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def bed_name = bed_file.simpleName.replaceAll("${meta.id}\\.", '')
    def output_name = "${prefix}.${bed_name}.fasta"
    """
    touch ${output_name}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bedtools: \$(bedtools --version | sed 's/bedtools v//')
    END_VERSIONS
    """
}
