#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// `params.run_dir` is required, but the strict check happens inside `workflow {}`
// below so that `nextflow inspect` (which loads main.nf without params being set)
// can succeed during e.g. `nf-core modules update` container-config regeneration.
def run_dir = (params.run_dir ?: '').replaceAll(/\/$/, '')

// run_id extraction — keep in sync with cells2stats-nf / elembio-tetonatlas-nf main.nf
def analysisRunMatch = (run_dir =~ /.*\/runs\/[^\/]+\/([^\/]+)\/analysis\/[^\/]+(?:\/|$)/)
def run_id = params.id ?: (analysisRunMatch ? analysisRunMatch[0][1] : (run_dir ? file(run_dir).name : 'unset'))
def meta = [id: run_id]
def run_manifest = params.b2f_run_manifest ? file(params.b2f_run_manifest, checkIfExists: true) : []

// Channel inputs for the bases2fastq module. Empty-list / empty-channel
// sentinels follow the convention used by the upstream module.
ch_segmentation          = params.b2f_segmentation
    ? Channel.value(file(params.b2f_segmentation, checkIfExists: true))
    : Channel.value([])
ch_analysis_region       = params.b2f_analysis_region
    ? Channel.value(file(params.b2f_analysis_region, checkIfExists: true))
    : Channel.value([])
ch_panel                 = params.b2f_panel_json
    ? Channel.value(file(params.b2f_panel_json, checkIfExists: true))
    : Channel.value([])
ch_tca_manifest          = params.b2f_tca_manifest_csv
    ? Channel.value(file(params.b2f_tca_manifest_csv, checkIfExists: true))
    : Channel.value([])

log.info """\
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   B A S E S 2 F A S T Q - N F
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ▸ Run Info
 ──────────────────────────────────────────────────────────────────────
   run_dir:  ${run_dir}
   run_id:   ${run_id}
   outdir:   ${params.outdir}

 ▸ Data Filtering
 ──────────────────────────────────────────────────────────────────────
   filter_batch:    ${params.filter_batch ?: '*'}
   b2f_include_tile: ${params.b2f_include_tile ?: '*'}
   b2f_exclude_tile: ${params.b2f_exclude_tile ?: '*'}

 ▸ bases2fastq (b2f)
 ──────────────────────────────────────────────────────────────────────
   container:           ${params.b2f_container_url}:${params.b2f_container_tag}
   run_manifest:        ${params.b2f_run_manifest ?: 'N/A'}
   b2f_segmentation:    ${params.b2f_segmentation ?: 'N/A'}
   b2f_analysis_region: ${params.b2f_analysis_region ?: 'N/A'}
   b2f_no_projects:     ${params.b2f_no_projects}
   b2f_qc_only:         ${params.b2f_qc_only}
   b2f_settings:        ${params.b2f_settings ?: 'N/A'}
   b2f_log_level:       ${params.b2f_log_level ?: 'N/A'}
   b2f_args:            ${params.b2f_args ? "${params.b2f_args} (deprecated; use ext.args in conf/modules.config)" : 'N/A'}

 ▸ Config
 ──────────────────────────────────────────────────────────────────────
   custom_config_version: ${params.custom_config_version}
   custom_config_base:    ${params.custom_config_base}
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 """

include { BASES2FASTQ } from './modules/elembio/bases2fastq/main'

workflow {

    if (!params.run_dir) {
        exit 1, "ERROR: 'params.run_dir' must be set."
    }

    BASES2FASTQ (
        Channel.value([meta, run_dir]),
        run_manifest,
        ch_segmentation,
        ch_analysis_region,
        ch_panel,
        ch_tca_manifest
    )
}
