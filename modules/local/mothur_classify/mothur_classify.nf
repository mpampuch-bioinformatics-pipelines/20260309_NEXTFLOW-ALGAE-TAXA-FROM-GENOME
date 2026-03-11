process MOTHUR_CLASSIFY {
    tag "${meta.id} - ${meta.seq_type} - ${meta.database}"
    label 'process_high'

    conda "bioconda::mothur=1.48.0"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/eb/ebfa92a9387f2c0d0cbdaa55c5a3641cd5ed9aca4b6275a67397c0beb54de160/data'
        : 'community.wave.seqera.io/library/mothur:1.48.0--a0520c1fa2ab72dc'}"

    input:
    tuple val(meta), path(fasta), val(sequence_type), path(template_db), path(taxonomy_db)

    output:
    tuple val(meta), path("*.taxonomy"), emit: taxonomy
    tuple val(meta), path("*.summary"), emit: summary
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def argsList = task.ext.args ?: []
    // fallback to empty list if null
    def args = argsList ? ', ' + argsList.join(',') : ''
    // join with comma, or empty string if list is empty
    def prefix = task.ext.prefix ?: "${meta.id}"
    def cutoff = params.mothur_cutoff ?: 80
    def database = meta.database ?: 'unknown'
    def output_name = "${prefix}.${sequence_type}.DB_${database}"
    def batch_script = "classify.seqs.${output_name}.batch.sh"
    // Potential bug inside version 1.48.0: summary file does not recognize current. Therefore need to pass in the name explicitly.
    """
    # Create the mothur batch script
    cat <<EOF > ${batch_script}
    #! /bin/bash
    classify.seqs(fasta=${fasta}, reference=${template_db}, taxonomy=${taxonomy_db}, cutoff=${cutoff}, processors=${task.cpus}, probs=T ${args})
    rename.file(taxonomy=current, summary=${fasta.baseName}.0.wang.tax.summary, accnos=current, prefix=${output_name})
    EOF

    chmod +x ${batch_script}

    # Run mothur with the batch script
    mothur ${batch_script}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mothur: \$(mothur --version 2>&1 | grep -oP 'version=\\K[0-9.]+' || echo "1.48.0")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def database = meta.database ?: 'unknown'
    def output_name = "${prefix}.${sequence_type}.DB_${database}"
    """
    touch ${output_name}.taxonomy
    touch ${output_name}.tax.summary

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mothur: 1.48.0
    END_VERSIONS
    """
}
