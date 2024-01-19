process B2F {
    tag "$id"
    label 'process_high'
    scratch true

    container "${params.container_url}:${params.container_tag}"

    input:
    val run_dir
    val id
    val run_manifest_csv

    output:
    // run level metrics
    path "Metrics.csv"                     , emit: metrics_csv
    path "IndexAssignment.csv"             , emit: index_assignment_csv
    path "RunManifest.csv"                 , emit: run_manifest_csv
    path "RunManifest.json"                , emit: run_manifest_json
    path "RunParameters.json"              , emit: run_parameter_json
    path "RunStats.json"                   , emit: run_stats
    path "UnassignedSequences.csv"         , emit: unassigned_csv
    path "*_QC.html"                       , emit: qc_html
    // for --no-projects flag applied
    path "Samples/**.fastq.gz"             , optional: true, emit: sample_fastq
    path "Samples/**_stats.json"           , optional: true, emit: sample_json
    path "Samples/**_RunStats.json"        , optional: true, emit: json
    // for default structure (with projects)
    path "Samples/**_QC.html"              , optional: true, emit: project_qc_html
    path "Samples/**_Metrics.csv"          , optional: true, emit: project_metrics_csv
    path "Samples/**_IndexAssignment.csv"  , optional: true, emit: project_index_assignment_csv
    // b2f logs/info
    path "info/Bases2Fastq.log"            , emit: b2f_log
    path "info/RunManifestErrors.json"     , optional: true, emit: manifest_errors_json
    path "run.log"                         , emit: log
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def b2f_options = params.b2f_args ?: ''
    def run_manifest_option = run_manifest_csv ? "-r ${run_manifest_csv}" : ''

    """
    logfile=run.log
    exec > >(tee \$logfile)
    exec 2>&1

    echo "${params.container_url}:${params.container_tag}"
    echo "bases2fastq ${run_dir} . -p ${task.cpus} ${run_manifest_option} ${b2f_options}"

    bases2fastq \\
        ${run_dir} \\
        . \\
        -p ${task.cpus} \\
        ${run_manifest_option} \\
        ${b2f_options}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bases2fastq: \$(bases2fastq --version | sed -e "s/bases2fastq version //g")
    END_VERSIONS
    """
}