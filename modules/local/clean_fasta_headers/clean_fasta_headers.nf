process CLEAN_FASTA_HEADERS {
    tag "${meta.id}"
    label 'process_single'

    conda "conda-forge::perl=5.32.1"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/gawk:5.3.0'
        : 'biocontainers/gawk:5.3.0'}"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.cleaned.fa"), emit: fasta
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    // bedtools --name produces headers like:
    //   >Name=12S_rRNA;product=12S ribosomal RNA (partial);note=aligned only 33 percent::contig:100-1850
    //
    // Goal: replace spaces with hyphens in FASTA header lines.
    //
    // The awk command checks for lines beginning with ">" (FASTA headers)
    // and replaces all spaces with "-" using gsub(). Sequence lines are
    // passed through unchanged.
    """

    awk '/^>/ { gsub(/ /,"-") } 1' "${fasta}" > "${prefix}.cleaned.fa"


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version | head -n 1 | sed 's/GNU Awk //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.cleaned.fa


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version | head -n 1 | sed 's/GNU Awk //')
    END_VERSIONS
    """
}
