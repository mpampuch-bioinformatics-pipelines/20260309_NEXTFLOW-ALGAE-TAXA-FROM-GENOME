process BARRNAP {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::barrnap=0.9"
    container "community.wave.seqera.io/library/barrnap:0.9--e933fdf0eb96f35f"

    input:
    tuple val(meta), path(genome)
    val organism_type

    output:
    tuple val(meta), path("*.gff"), emit: gff
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    // Determine kingdoms based on organism type
    def kingdoms = organism_type == 'eukaryotic' ? ['euk', 'mito'] : ['bac', 'arc']
    
    """
    # Run barrnap for each kingdom
    ${kingdoms.collect { kingdom ->
        "barrnap --kingdom ${kingdom} --threads ${task.cpus} ${args} ${genome} > ${prefix}.${kingdom}.rRNA.gff"
    }.join('\n    ')}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        barrnap: \$(echo \$(barrnap --version 2>&1) | sed 's/^.*barrnap //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def kingdoms = organism_type == 'eukaryotic' ? ['euk', 'mito'] : ['bac', 'arc']
    """
    ${kingdoms.collect { kingdom ->
        "touch ${prefix}.${kingdom}.rRNA.gff"
    }.join('\n    ')}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        barrnap: \$(echo \$(barrnap --version 2>&1) | sed 's/^.*barrnap //; s/ .*\$//')
    END_VERSIONS
    """
}
