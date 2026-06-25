# Parameter Reference

Complete reference for all bases2fastq-nf parameters.

---

## Input/Output Parameters

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| `run_dir` | Path | Path to AVITI run directory. Can be local filesystem or S3 path. |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `id` | String | Auto-detected | Run identifier. If not set: analysis-path rule when `run_dir` matches `.../runs/<instrument>/<run_id>/analysis/<analysis_id>/...`, else last path segment of `run_dir`. |
| `outdir` | Path | `./results` | Output directory. |
| `b2f_run_manifest` | Path | `null` | Path to a custom RunManifest.csv file. When provided, passed to bases2fastq via `-r`. |

---

## Shared Filtering Parameters

These parameters are shared with other Element pipelines (e.g., cells2stats, tetonatlas) for consistent data subsetting. The module uses fallback logic: `b2f_include_tile` takes priority, then `tile`.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `filter_batch` | String | `null` | Restrict to specific batch(es), comma-delimited (e.g., `B01,B02,B03`). Passed to bases2fastq via `--batch`. |
| `tile` | List | `[]` | Tile regex pattern(s). Falls back to `b2f_include_tile` when that param is empty. |

---

## bases2fastq (b2f) Parameters

### Boolean Flags

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `b2f_demux_only` | Boolean | `false` | Only demultiplex, skip FASTQ generation. |
| `b2f_detect_adapters` | Boolean | `false` | Detect and trim adapters. |
| `b2f_error_on_missing` | Boolean | `false` | Error on missing files in the run directory. |
| `b2f_force_detect_index_orientation` | Boolean | `false` | Detect index orientation by scanning all tiles and using the highest-PF tile in each lane. **Requires bases2fastq ≥ `2.4.0`.** |
| `b2f_force_index_orientation` | Boolean | `false` | Force index read orientation. |
| `b2f_group_fastq` | Boolean | `false` | Group FASTQs by sample. |
| `b2f_legacy_fastq` | Boolean | `false` | Use legacy naming: `SampleName_S1_L001_R1_001.fastq.gz`. |
| `b2f_no_error_on_invalid` | Boolean | `false` | Skip invalid files instead of erroring. |
| `b2f_no_projects` | Boolean | `false` | Disable project directories (flat Samples/ layout). |
| `b2f_per_target_fastq` | Boolean | `false` | Create per-target FASTQ for each cell assignment target. |
| `b2f_qc_only` | Boolean | `false` | Generate QC metrics only, no FASTQs. |
| `b2f_skip_empty_fq_files` | Boolean | `false` | Do not create FASTQ files for sample/read outputs with zero reads. **Requires bases2fastq ≥ `2.4.0`.** |
| `b2f_skip_multi_qc` | Boolean | `false` | Skip MultiQC report generation. |
| `b2f_skip_qc_report` | Boolean | `false` | Skip QC report generation. |
| `b2f_split_lanes` | Boolean | `false` | Split output by lane. |

### Value Flags

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `b2f_analysis_region` | Path | `null` | Path to `AnalysisRegion/` directory (local or remote). Forwarded to bases2fastq via `--analysis-region`. **Requires bases2fastq ≥ `2.4.0`.** |
| `b2f_cyto_fastq_mask` | String | `null` | Cycle mask for cyto FASTQ generation. |
| `b2f_filter_mask` | String | `null` | Filter mask value for bases2fastq. |
| `b2f_flowcell_id` | String | `null` | Override flowcell ID. |
| `b2f_log_level` | String | `null` | Log level: DEBUG, INFO, WARNING, ERROR. |
| `b2f_num_unassigned` | Integer | `null` | Maximum unassigned sequences to report. |
| `b2f_panel_json` | Path | `null` | Path to Panel.json file. Forwarded to bases2fastq via `--panel`. |
| `b2f_segmentation` | Path | `null` | Path to `CellSegmentation/` directory (local or remote). Forwarded to bases2fastq via `--segmentation`. **Requires bases2fastq ≥ `2.4.0`.** |
| `b2f_tca_manifest_csv` | Path | `null` | Path to TargetCellAssignment manifest CSV. Forwarded to bases2fastq via `--tca-manifest`. |

### Tile Filtering

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `b2f_include_tile` | List | `[]` | Tile inclusion regex patterns. When set, auto-excludes all tiles first so includes work as a filter. Falls back to shared `tile` param if empty. |
| `b2f_exclude_tile` | List | `[]` | Tile exclusion regex patterns. Auto-set to `['L.R..C..S.']` when `b2f_include_tile` is active. |

### List Flags

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `b2f_settings` | List | `[]` | Repeated `--settings 'key,val'` flags (e.g., `["R1AdapterTrim,true", "R2AdapterTrim,true"]`). |

### Custom Arguments

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `b2f_args` | String | `null` | **Deprecated.** Additional custom arguments passed directly to bases2fastq. Prefer overriding `withName: BASES2FASTQ { ext.args = { ... } }` in a `-c custom.config` overlay; see `conf/modules.config` for the canonical closure. Will be removed in a future release. |

---

## Container Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `b2f_container_url` | String | `904220683607.dkr.ecr.us-west-2.amazonaws.com/bases2fastq-release` | bases2fastq container repository. |
| `b2f_container_tag` | String | `2.4.0` | bases2fastq container version. |

---

## Resource Limits

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_memory` | String | `384.GB` | Maximum memory per process. |
| `max_cpus` | Integer | `48` | Maximum CPUs per process. |
| `max_time` | String | `8.h` | Maximum time per process. |

---

## Publishing Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `publish_dir_mode` | String | `copy` | How to publish output files: `copy`, `symlink`, `move`, etc. |
| `tracedir` | Path | `{outdir}/pipeline_info` | Directory for Nextflow trace/timeline/report files. |
| `disable_task_publish` | Boolean | `false` | When `true`, publish all outputs flat to `{outdir}/` without subdirectories. |
