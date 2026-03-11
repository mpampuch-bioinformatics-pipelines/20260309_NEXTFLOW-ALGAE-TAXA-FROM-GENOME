process ITSX {
    tag "${meta.id}"
    label 'process_medium'

    conda "bioconda::itsx=1.1.3"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/d0/d0726c80a5d0d376875a8c228e6ae2aede150dda0ae49578e3640a79e5f0ca6d/data'
        : 'community.wave.seqera.io/library/itsx:1.1.3--63fdf3992725b351'}"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.ITS1.fasta"), optional: true, emit: its1
    tuple val(meta), path("*.ITS2.fasta"), optional: true, emit: its2
    tuple val(meta), path("*.full.fasta"), optional: true, emit: full
    tuple val(meta), path("*.SSU.fasta"), optional: true, emit: ssu
    tuple val(meta), path("*.LSU.fasta"), optional: true, emit: lsu
    tuple val(meta), path("*.5_8S.fasta"), optional: true, emit: s58
    tuple val(meta), path("*.chimeric.fasta"), optional: true, emit: chimeric
    tuple val(meta), path("*.problematic.txt"), optional: true, emit: problematic
    tuple val(meta), path("*.graph"), optional: true, emit: graph
    tuple val(meta), path("*.summary.txt"), emit: summary
    tuple val(meta), path("*.positions.txt"), optional: true, emit: positions
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def organism_code = meta.organism_code ?: '.'
    // Character code Full name Alternative name
    // A Alveolata alveolates
    // B Bryophyta mosses
    // C Bacillariophyta diatoms
    // D Amoebozoa
    // E Euglenozoa
    // F Fungi
    // G Chlorophyta green-algae
    // H Rhodophyta red-algae
    // I Phaeophyceae brown-algae
    // L Marchantiophyta liverworts
    // M Metazoa animals
    // O Oomycota oomycetes
    // P Haptophyceae prymnesiophytes
    // Q Raphidophyceae raphidophytes
    // R Rhizaria
    // S Synurophyceae synurids
    // T Tracheophyta higher-plants
    // U Eustigmatophyceae eustigmatophytes
    // X Apusozoa
    // Y Parabasalia parabasalids
    // . All
    """
    ITSx \\
        -i ${fasta} \\
        -o ${prefix} \\
        --nhmmer T \\
        --cpu ${task.cpus} \\
        -t ${organism_code} \\
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
    touch ${prefix}.chimeric.fasta
    touch ${prefix}.problematic.txt
    touch ${prefix}.graph
    touch ${prefix}.summary.txt
    touch ${prefix}.positions.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        itsx: 1.1.3
    END_VERSIONS
    """
}
