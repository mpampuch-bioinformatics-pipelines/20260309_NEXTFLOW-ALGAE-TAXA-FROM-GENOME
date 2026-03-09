process COMBINE_GFF {
    tag "$meta.id"
    label 'process_single'

    conda "conda-forge::coreutils=9.4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(gff_files)

    output:
    tuple val(meta), path("*.all.rRNA.gff"), emit: gff
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def gff_list = gff_files instanceof List ? gff_files : [gff_files]
    
    """
    # Start with the first GFF file (includes header)
    cat ${gff_list[0]} > ${prefix}.all.rRNA.gff
    
    # Append remaining GFF files without headers
    ${gff_list.size() > 1 ? gff_list[1..-1].collect { gff ->
        "grep -v '##gff-version' ${gff} >> ${prefix}.all.rRNA.gff"
    }.join('\n    ') : '# Only one GFF file provided'}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cat: \$(cat --version | head -n 1 | sed 's/cat (GNU coreutils) //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.all.rRNA.gff

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cat: \$(cat --version | head -n 1 | sed 's/cat (GNU coreutils) //')
    END_VERSIONS
    """
}
