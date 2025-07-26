process MULTIQC {
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${params.multiqc_container_url}:${params.multiqc_container_tag}"

    input:
    path  multiqc_files, stageAs: "?/*"
    path(multiqc_config)
    path(extra_multiqc_config)
    path(multiqc_logo)

    output:
    path "*multiqc_report.html", optional:true, emit: report
    path "*_data"              , optional:true, emit: data
    path "*_plots"             , optional:true, emit: plots
    path "versions.yml"        , emit: versions
    path "run.log"             , emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def config = multiqc_config ? "--config $multiqc_config" : ''
    def extra_config = extra_multiqc_config ? "--config $extra_multiqc_config" : ''
    def logo = multiqc_logo ? "--cl-config 'custom_logo: \"${multiqc_logo}\"'" : ''
    
    """
    logfile=run.log
    exec > >(tee \$logfile)
    exec 2>&1

    echo "multiqc --force ${args} ${config} ${extra_config} ${logo} ."

    multiqc \\
        --force \\
        $args \\
        $config \\
        $extra_config \\
        $logo \\
        .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """

    stub:
    """
    mkdir multiqc_data
    mkdir multiqc_plots
    touch multiqc_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """
}
