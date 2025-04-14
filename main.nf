#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

log.info """
================================================
  B A S E S 2 F A S T Q - N F   P I P E L I N E
================================================
 run_dir: ${params.run_dir} 
 b2f_args: ${params.b2f_args}
 detect_adapters: ${params.detect_adapters}
 exclude_tile: ${params.exclude_tile}
 filter_mask: ${params.filter_mask}
 flowcell_id: ${params.flowcell_id}
 force_index_orientation: ${params.force_index_orientation}
 include_tile: ${params.include_tile}
 legacy_fastq: ${params.legacy_fastq}
 no_error_on_invalid: ${params.no_error_on_invalid}
 num_unassigned: ${params.num_unassigned}
 qc_only: ${params. qc_only}
 run_manifest: ${params.run_manifest}
 settings: ${params.settings}
 split_lanes: ${params.split_lanes}
 b2f_container_url: ${params.b2f_container_url}
 b2f_container_tag: ${params.b2f_container_tag}
 disable_task_publish: ${params.disable_task_publish}
 outdir: ${params.outdir}
 """
 
include { BASES2FASTQ } from './modules/local/bases2fastq'

//bases2fastq optional path params
def run_manifest = params.run_manifest ? file(params.run_manifest, checkIfExists: true) : []

workflow {

    BASES2FASTQ (
        params.run_dir,
        run_manifest
     )
}

