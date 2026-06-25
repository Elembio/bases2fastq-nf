process BASES2FASTQ {
    tag "$meta.id"
    label 'process_high'
    scratch true

    container "${params.b2f_container_url}:${params.b2f_container_tag}"

    input:
    tuple val(meta), val(run_dir)
    path(run_manifest, stageAs: 'runManifest/*')
    path segmentation
    path analysis_region
    path panel
    path tca_manifest

    output:
    path "Panel.json"                      , optional: true, emit: panel_json
    path "Metrics.csv"                     , optional: true, emit: metrics_csv
    path "IndexAssignment.csv"             , optional: true, emit: index_assignment_csv
    path "RunManifest.csv"                 , optional: true, emit: run_manifest_csv
    path "RunManifest.json"                , optional: true, emit: run_manifest_json
    path "RunParameters.json"              , optional: true, emit: run_parameter_json
    path "RunStats.json"                   , optional: true, emit: run_stats
    path "UnassignedSequences.csv"         , optional: true, emit: unassigned_csv
    path "*_QC.html"                       , optional: true, emit: qc_html
    // --no-projects layout
    path "Samples/**.fastq.gz"             , optional: true, emit: sample_fastq
    path "Samples/**.fastq.gz.gzi"         , optional: true, emit: sample_fastq_gzi
    path "Samples/**_stats.json"           , optional: true, emit: sample_json
    path "Samples/**_RunStats.json"        , optional: true, emit: json
    // project layout
    path "Samples/**_QC.html"              , optional: true, emit: project_qc_html
    path "Samples/**_Metrics.csv"          , optional: true, emit: project_metrics_csv
    path "Samples/**_IndexAssignment.csv"  , optional: true, emit: project_index_assignment_csv
    // logs
    path "info/Bases2Fastq.log"            , emit: b2f_log
    path "info/RunManifestErrors.json"     , optional: true, emit: manifest_errors_json
    path "run.log"                         , emit: log
    path "versions.yml"                    , emit: versions
    // Curated small-metadata mirror for downstream tools (build-spatialdata
    // --b2f-dir). Contains only the named files in the allowlist below —
    // bulk artefacts like Samples/**.fastq.gz and info/ are excluded on purpose.
    path "metrics"                         , emit: metrics_dir

    when:
    task.ext.when == null || task.ext.when

    script:
    // Per nf-core convention, all user-configurable CLI flags are composed by
    // the consumer pipeline's conf/modules.config via task.ext.args. See
    // https://github.com/Elembio/bases2fastq-nf#module-configuration
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    // Path inputs that the module knows the CLI flag for. The run_manifest
    // is staged under runManifest/ (see input declaration above) so it cannot
    // collide with the RunManifest.csv that bases2fastq itself emits into
    // OUTPUT_DIRECTORY (= .) during the run.
    def run_manifest_opt    = run_manifest    ? "-r ${run_manifest}"                     : ''
    def panel_opt           = panel           ? "--panel ${panel}"                       : ''
    def tca_manifest_opt    = tca_manifest    ? "--tca-manifest ${tca_manifest}"         : ''
    def segmentation_opt    = segmentation    ? "--segmentation ${segmentation}"         : ''
    def analysis_region_opt = analysis_region ? "--analysis-region ${analysis_region}"   : ''

    """
    logfile=run.log
    exec > >(tee \$logfile)
    exec 2>&1

    echo "Container: ${task.container}"

    bases2fastq \\
        ${run_dir} \\
        . \\
        -p ${task.cpus} \\
        ${run_manifest_opt} \\
        ${panel_opt} \\
        ${tca_manifest_opt} \\
        ${segmentation_opt} \\
        ${analysis_region_opt} \\
        ${args}

    # Curated small-metadata mirror for build-spatialdata --b2f-dir.
    # Top-level files only (bulk Samples/ dir skipped by the file-type
    # test); known-bulk extensions are denylisted, and a 100 MB size cap
    # catches anything else. info/ (Bases2Fastq.log, RunManifestErrors.json)
    # is staged as a subdir. build-spatialdata is the final authority on
    # what actually flows into metadata/inputs/.
    mkdir -p metrics
    for f in *; do
        [ -f "\$f" ] || continue
        case "\$f" in
            *.parquet|*.bam|*.bai|*.cram|*.crai|*.sam|*.fastq.gz|*.fq.gz|*.fastq|*.fq) continue ;;
        esac
        size=\$(stat -c%s "\$f" 2>/dev/null || echo 0)
        [ "\$size" -gt 104857600 ] && continue
        ln -sf "../\$f" "metrics/\$f"
    done
    [ -d info ] && ln -sfn ../info metrics/info

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bases2fastq: \$(bases2fastq --version 2>&1 | sed -nE 's/^bases2fastq(dx)? version:?[[:space:]]+([0-9][^,[:space:]]*).*/\\2/p' | head -n1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch Panel.json
    touch Metrics.csv
    touch IndexAssignment.csv
    touch RunManifest.csv
    touch RunManifest.json
    touch RunParameters.json
    touch RunStats.json
    touch UnassignedSequences.csv
    mkdir -p Samples/DefaultSample
    touch Samples/DefaultSample/DefaultSample_R1.fastq.gz
    mkdir -p info
    touch info/Bases2Fastq.log
    touch run.log

    mkdir -p metrics
    for f in *; do
        [ -f "\$f" ] || continue
        case "\$f" in
            *.parquet|*.bam|*.bai|*.cram|*.crai|*.sam|*.fastq.gz|*.fq.gz|*.fastq|*.fq) continue ;;
        esac
        size=\$(stat -c%s "\$f" 2>/dev/null || echo 0)
        [ "\$size" -gt 104857600 ] && continue
        ln -sf "../\$f" "metrics/\$f"
    done
    [ -d info ] && ln -sfn ../info metrics/info

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bases2fastq: stub
    END_VERSIONS
    """
}
