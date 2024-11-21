process BASES2FASTQ {
    tag "${run_dir.baseName}"
    label 'process_high'
    //scratch true

    container "${params.b2f_container_url}:${params.b2f_container_tag}"

    input:
    path run_dir, stageAs: 'run/*'
    
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
    
    //true false params to appluy the b2f option
    def legacy_fastq_option = params.legacy_fastq ? "--legacy-fastq" : ""
    def detect_adapters_option = params.detect_adapters ? "--detect-adapters" : ""
    def force_index_orientation_option = params.force_index_orientation ? "--force-index-orientation" : ""
    def no_error_on_invalid_option = params.no_error_on_invalid ? "--no-error-on-invalid" : ""
    def qc_only_option = params.qc_only ? "--qc-only" : ""
    def split_lanes_option = params.split_lanes ? "--split_lanes" : ""


    //arry of strings input params
    def exclude_tile_option = params.exclude_tile.collect{"--exclude-tile \'${it}\'"}.join(' ')    
    def include_tile_option = params.include_tile.collect{"--include-tile \'${it}\'"}.join(' ')
    def settings_option = params.settings.collect{"--settings \'${it}\'"}.join(' ')

    //string input params
    def filter_mask_option = params.filter_mask ? "--filter-mask ${params.filter_mask}" : ""
    def flowcell_id_option = params.flowcell_id ? "--flowcell-id ${params.flowcell_id}" : ""
    def num_unassigned_option = params.num_unassigned ? "--num-unassigned ${params.num_unassigned}" : ""
    def b2f_args_option = params.b2f_args ? "${params.b2f_args}" : ""

    
    //file input
    def run_manifest_option = params.run_manifest ? " --r ${params.run_manifest}" : ""



    """
    logfile=run.log
    exec > >(tee \$logfile)
    exec 2>&1

    echo "${params.b2f_container_url}:${params.b2f_container_tag}"
    echo "bases2fastq ${run_dir} . -p ${task.cpus} ${b2f_args_option}  ${legacy_fastq_option} ${detect_adapters_option} ${exclude_tile_option} ${include_tile_option} ${filter_mask_option} ${flowcell_id_option} ${force_index_orientation_option} ${no_error_on_invalid_option} ${qc_only_option} ${split_lanes_option}  ${settings_option} ${num_unassigned_option}"
    echo "bases2fastq \\
        ${run_dir} \\
        . \\
        -p ${task.cpus} \\
        ${b2f_args_option} \\
        ${legacy_fastq_option} \\
        ${detect_adapters_option} \\
        ${exclude_tile_option} \\
        ${include_tile_option} \\
        ${filter_mask_option} \\
        ${flowcell_id_option} \\
        ${force_index_orientation_option} \\
        ${no_error_on_invalid_option} \\
        ${qc_only_option} \\
        ${split_lanes_option} \\
        ${settings_option} \\
        ${num_unassigned_option}"



    bases2fastq \\
        ${run_dir} \\
        . \\
        -p ${task.cpus} \\
        ${b2f_args_option} \\
        ${legacy_fastq_option} \\
        ${detect_adapters_option} \\
        ${exclude_tile_option} \\
        ${include_tile_option} \\
        ${filter_mask_option} \\
        ${flowcell_id_option} \\
        ${force_index_orientation_option} \\
        ${no_error_on_invalid_option} \\
        ${qc_only_option} \\
        ${split_lanes_option} \\
        ${settings_option} \\
        ${num_unassigned_option}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bases2fastq: \$(bases2fastq --version | sed -e "s/bases2fastq version //g")
    END_VERSIONS
    """
}


