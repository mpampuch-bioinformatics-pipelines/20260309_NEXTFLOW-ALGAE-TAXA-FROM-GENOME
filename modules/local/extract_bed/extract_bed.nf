process EXTRACT_BED {
    tag "$meta.id"
    label 'process_single'

    conda "conda-forge::gawk=5.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.3.0' :
        'biocontainers/gawk:5.3.0' }"

    input:
    tuple val(meta), path(gff)
    val organism_type

    output:
    tuple val(meta), path("*.bed"), emit: bed
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    // Define rRNA types based on organism type
    def rrna_types = organism_type == 'eukaryotic' ? 
        ['12S', '16S', '18S', '23S', '28S', '5_8S', '5S'] : 
        ['12S', '16S', '23S', '5S']
    
    """
    # Extract BED files for each rRNA type
    ${rrna_types.collect { rrna ->
        def rrna_pattern = rrna.replaceAll('_', '_')
        "awk '\$9 ~ /${rrna_pattern}/ {print \$1\"\\t\"\$4-1\"\\t\"\$5\"\\t\"\$9}' ${gff} > ${prefix}.${rrna.toLowerCase()}.bed"
    }.join('\n    ')}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version | head -n 1 | sed 's/GNU Awk //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def rrna_types = organism_type == 'eukaryotic' ? 
        ['12S', '16S', '18S', '23S', '28S', '5_8S', '5S'] : 
        ['12S', '16S', '23S', '5S']
    """
    ${rrna_types.collect { rrna ->
        "touch ${prefix}.${rrna.toLowerCase()}.bed"
    }.join('\n    ')}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version | head -n 1 | sed 's/GNU Awk //')
    END_VERSIONS
    """
}
