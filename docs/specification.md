# Specification: bases2fastq-nf

This document is the definitive reference for the `bases2fastq-nf` pipeline.
It describes every input file, every output artifact, every convention,
and every assumption required to run or consume outputs produced by this pipeline.

---

## Table of Contents

- [1. Pipeline Overview](#1-pipeline-overview)
- [2. Input Files](#2-input-files)
  - [2.1 AVITI Run Directory](#21-aviti-run-directory)
  - [2.2 Run Manifest](#22-run-manifest)
  - [2.3 Cyto-Fastq Directories (segmentation, analysis_region)](#23-cyto-fastq-directories-segmentation-analysis_region)
- [3. Conventions](#3-conventions)
  - [3.1 Naming Conventions](#31-naming-conventions)
  - [3.2 Tile Filtering](#32-tile-filtering)
  - [3.3 Batch Filtering](#33-batch-filtering)
  - [3.4 Run ID Extraction](#34-run-id-extraction)
- [4. Process Specifications](#4-process-specifications)
  - [4.1 BASES2FASTQ](#41-bases2fastq)
- [5. Output Directory Structure](#5-output-directory-structure)
- [6. Channel Data Flow](#6-channel-data-flow)
- [7. Configuration Profiles](#7-configuration-profiles)
  - [7.1 Profile Summary](#71-profile-summary)
  - [7.2 Base Configuration](#72-base-configuration)
  - [7.3 AVITI Profile](#73-aviti-profile)
  - [7.4 Test Profile](#74-test-profile)
  - [7.5 Other Profiles](#75-other-profiles)
  - [7.6 Container Version](#76-container-version)
  - [7.7 Resource Capping](#77-resource-capping)
- [8. Failure Modes and Recovery](#8-failure-modes-and-recovery)
  - [8.1 Retry Behavior](#81-retry-behavior)
  - [8.2 CPU Step-Down Retry Strategy](#82-cpu-step-down-retry-strategy)
  - [8.3 Resume Behavior](#83-resume-behavior)

---

## 1. Pipeline Overview

The pipeline runs the Element Biosciences
[Bases2Fastq](https://docs.elembio.io/docs/bases2fastq/introduction/) tool on
raw AVITI sequencing data, producing demultiplexed FASTQ files, per-sample
QC reports (generated natively by the `bases2fastq` binary), and run-level
statistics. Starting from a single AVITI run directory, it calls the
`BASES2FASTQ` module sourced from
[elembio-nf-modules](https://gitlab.com/elembio/analysis/elembio-nf-modules):

```
  ┌──────────┐       ┌───────────────────────────────────────────────┐
  │  AVITI   │──────▶│ BASES2FASTQ                                   │
  │  Run     │       │   Demux base calls → FASTQ per sample/well    │
  │  Dir     │       │   Produces *_QC.html reports natively          │
  └──────────┘       └───────────────────────────────────────────────┘
```

The pipeline validates inputs at launch (run directory existence), constructs
filtering and option flags from parameters, and passes them to the module via
`task.ext.args`. The `bases2fastq` binary handles demultiplexing and QC
report generation internally.

**Requirements:** Nextflow >= 21.10.3, a container runtime (Docker, Singularity,
or Podman).

---

## 2. Input Files

### 2.1 AVITI Run Directory

**Required.** The root input to the pipeline, specified via `--run_dir`.

The path must point to the AVITI run directory (local filesystem or S3). The
pipeline expects base call data and instrument metadata at known relative
locations within this directory.

**Path normalization:** Trailing slashes are stripped at launch:
```
run_dir = params.run_dir.replaceAll(/\/$/, '')
```

**Validation at launch:**
- `params.run_dir` must be set (non-null). If missing, the pipeline exits with
  `ERROR: 'params.run_dir' must be set.`

**Run ID extraction** (same rule as cells2stats-nf / elembio-tetonatlas-nf): If
`params.id` is set, it is used. Else if `run_dir` matches
`.../runs/<instrument>/<run_id>/analysis/<analysis_id>/...`, that `run_id` is
used. Otherwise `run_id` is the last path segment of `run_dir`:
```
def analysisRunMatch = (run_dir =~ /.*\/runs\/[^\/]+\/([^\/]+)\/analysis\/[^\/]+(?:\/|$)/)
def run_id = params.id ?: (analysisRunMatch ? analysisRunMatch[0][1] : file(run_dir).name)
```

**S3 paths** are supported natively via Nextflow's S3 integration. The
`run_dir` is passed to bases2fastq as a `val` input (not staged), allowing
bases2fastq to handle S3 access directly.

---

### 2.2 Run Manifest

**Optional.** Override the run manifest via `--b2f_run_manifest`.

When provided, the file is staged into a `runManifest/` subdirectory and passed
to bases2fastq via `-r`. When not provided, bases2fastq discovers the manifest
from the run directory automatically.

```
run_manifest = params.b2f_run_manifest ? file(params.b2f_run_manifest, checkIfExists: true) : []
```

---

### 2.3 Cyto-Fastq Directories (segmentation, analysis_region)

**Optional.** Two directory inputs forwarded to bases2fastq's cyto-fastq path:

- `--b2f_segmentation` → `--segmentation` (path to `CellSegmentation/`)
- `--b2f_analysis_region` → `--analysis-region` (path to `AnalysisRegion/`)

Both are wired directly into the `BASES2FASTQ` module as channel inputs. When
the corresponding pipeline param is unset, the channel emits `Channel.value([])`
and the module conditionally omits the CLI flag.

**Container requirement:** these flags exist in bases2fastq `2.4.0`
and newer. On older container tags the path is staged but the CLI flag is
silently omitted by the module.

---

## 3. Conventions

### 3.1 Naming Conventions

| Entity | Pattern | Examples |
|--------|---------|----------|
| Tile ID | `L{lane}R{row}C{col}S{site}` | `L2R01C01S1`, `L1R17C04S1` |
| DISS/Barcoding batch | `B{nn}` | `B01`, `B05` |
| Run ID | `params.id`, else analysis-path rule, else last path segment of `run_dir` | e.g. `20240101_AV123456_WHTF-1234` |

---

### 3.2 Tile Filtering

Three parameters control which tiles are processed. They are translated into
bases2fastq `--include-tile` and `--exclude-tile` CLI flags.

**Include logic (fallback chain):**
```
include_tile_list = params.b2f_include_tile ?: (params.tile ?: [])
```

`b2f_include_tile` takes priority. If empty, falls back to the shared `tile`
parameter (used across Element pipelines). If both are empty, no inclusion
filter is applied.

**Auto-exclude logic:**
```
exclude_tile_list = params.b2f_exclude_tile ?: (include_tile_list ? ['L.R..C..S.'] : [])
```

When tile includes are active but no explicit excludes are set, all tiles are
auto-excluded with the regex `L.R..C..S.` so that includes work as a filter
(otherwise bases2fastq would include them in addition to all other tiles).

**CLI flag assembly:**
```
--include-tile 'pattern1' --include-tile 'pattern2' ...
--exclude-tile 'pattern1' --exclude-tile 'pattern2' ...
```

---

### 3.3 Batch Filtering

| Parameter | Type | Default | CLI flag | Behavior |
|-----------|------|---------|----------|----------|
| `filter_batch` | string | `null` (all batches) | `--batch {value}` | Comma-delimited batch names |

```
params.filter_batch = "B01,B02"
→ --batch B01,B02
```

---

### 3.4 Run ID Extraction

Precedence: `params.id` if set; else if `run_dir` matches
`.../runs/<instrument>/<run_id>/analysis/<analysis_id>/...`, use that `run_id`;
else the last path segment of `run_dir`.

Examples:

- `s3://bucket/runs/AV233101/20251218_AV233101_WHTF-1706/` → last segment.
- `s3://bucket/runs/AV233101/20251218_AV233101_WHTF-1706/analysis/custom123/` →
  `20251218_AV233101_WHTF-1706` (not `custom123`).

The `run_id` is used to set `meta.id` for the process tag.

---

## 4. Process Specifications

The pipeline calls a single module sourced from
[elembio-nf-modules](https://gitlab.com/elembio/analysis/elembio-nf-modules).

### 4.1 BASES2FASTQ

**Purpose:** Demultiplex raw AVITI base calls into per-sample FASTQ files,
generate run-level QC metrics, and produce index assignment statistics.

**Container:** `{b2f_container_url}:{b2f_container_tag}` (default: `904220683607.dkr.ecr.us-west-2.amazonaws.com/bases2fastq-release:2.4.0`)

**Label:** `process_high`

**Scratch:** `true` (global default; uses local scratch storage)

### Inputs

| Input | Type | Channel | Description |
|-------|------|---------|-------------|
| `meta` | val | `ch_run_dir` | Run metadata map (`{id: run_id}`) |
| `run_dir` | val | `ch_run_dir` | Path to AVITI run directory (not staged; bases2fastq accesses directly) |
| `run_manifest` | path (stageAs: `runManifest/*`) | value | Optional custom RunManifest.csv (empty list `[]` if not provided) |
| `segmentation` | path (directory) | `ch_segmentation` | Optional `CellSegmentation/` directory → `--segmentation`. Requires bases2fastq ≥ `2.4.0`. Empty list `[]` if not provided. |
| `analysis_region` | path (directory) | `ch_analysis_region` | Optional `AnalysisRegion/` directory → `--analysis-region`. Requires bases2fastq ≥ `2.4.0`. Empty list `[]` if not provided. |
| `panel` | path | `ch_panel` | Optional Panel.json → `--panel`. Empty list `[]` if not provided. |
| `tca_manifest` | path | `ch_tca_manifest` | Optional TargetCellAssignmentManifest CSV → `--tca-manifest`. Empty list `[]` if not provided. |

### Outputs

| Output | Format | Optional | Emit name | Description |
|--------|--------|----------|-----------|-------------|
| `Panel.json` | JSON | Yes | `panel_json` | Assay panel configuration (copy) |
| `Metrics.csv` | CSV | Yes | `metrics_csv` | Run-level demux metrics |
| `IndexAssignment.csv` | CSV | Yes | `index_assignment_csv` | Index assignment statistics |
| `RunManifest.csv` | CSV | Yes | `run_manifest_csv` | Run manifest (CSV) |
| `RunManifest.json` | JSON | Yes | `run_manifest_json` | Run manifest (JSON) |
| `RunParameters.json` | JSON | Yes | `run_parameter_json` | Instrument parameters (copy) |
| `RunStats.json` | JSON | Yes | `run_stats` | Run-level statistics |
| `UnassignedSequences.csv` | CSV | Yes | `unassigned_csv` | Unassigned sequence report |
| `*_QC.html` | HTML | Yes | `qc_html` | QC report(s) |
| `Samples/**.fastq.gz` | FASTQ | Yes | `sample_fastq` | Demultiplexed FASTQ files |
| `Samples/**_stats.json` | JSON | Yes | `sample_json` | Per-sample statistics |
| `Samples/**_RunStats.json` | JSON | Yes | `json` | Per-sample run statistics |
| `Samples/**_QC.html` | HTML | Yes | `project_qc_html` | Per-project QC reports |
| `Samples/**_Metrics.csv` | CSV | Yes | `project_metrics_csv` | Per-project metrics |
| `Samples/**_IndexAssignment.csv` | CSV | Yes | `project_index_assignment_csv` | Per-project index assignment |
| `info/Bases2Fastq.log` | Text | No | `b2f_log` | Bases2Fastq process log |
| `info/RunManifestErrors.json` | JSON | Yes | `manifest_errors_json` | Manifest validation errors |
| `run.log` | Text | No | `log` | Full stdout/stderr log |
| `metrics/` | Directory | No | `metrics_dir` | Curated small-metadata mirror (top-level files, denylisted bulk extensions, 100 MB cap, plus `info/`) — consumed by `build-spatialdata --b2f-dir` |
| `versions.yml` | YAML | No | `versions` | Nextflow-standard version tracking (bare path, not `tuple val(meta), ...`) |

### Module CLI Flag Mapping

The mapping from pipeline parameters to bases2fastq CLI flags is composed in
**[`conf/modules.config`](../conf/modules.config)** via a `task.ext.args` closure
on the `withName: BASES2FASTQ` block — per the nf-core convention adopted by the
upstream module registry. The module itself reads only `task.ext.args`, `task.ext.when`,
and the named channel inputs declared in its `input:` block — it does **not** read
`params.*` directly.

For the canonical `ext.args` pattern (with consumer-side examples, override
mechanism, and conventions for grouping / shared filters), see the upstream
README section
[Module configuration via `task.ext.args`](https://gitlab.com/elembio/analysis/elembio-nf-modules#module-configuration-via-taskextargs).

To **override** any flag in this pipeline without forking, drop a `-c
custom.config` file with your own `withName: BASES2FASTQ { ext.args = { ... } }`
closure that fully replaces the closure in `conf/modules.config`. Closures
specified later in the config chain replace earlier ones rather than merging.

### CLI Construction

The closure produces a CLI shaped roughly as:

```
bases2fastq {run_dir} . -p {cpus} \
    [-r {run_manifest}] \
    [--panel {path}] [--tca-manifest {csv}] \
    [--segmentation {dir}] [--analysis-region {dir}] \
    [-l {log_level}] \
    [--demux-only] [--detect-adapters] [--error-on-missing] \
    [--no-error-on-invalid] [--no-projects] [--legacy-fastq] \
    [--qc-only] [--skip-empty-fq-files] [--skip-multi-qc] [--skip-qc-report] \
    [--split-lanes] [--group-fastq] \
    [--force-detect-index-orientation] [--force-index-orientation] \
    [--per-target-fastq] \
    [--num-unassigned {n}] \
    [--filter-mask {mask}] [--flowcell-id {id}] \
    [--cyto-fastq-mask {mask}] \
    [--batch {batches}] \
    [--exclude-tile 'pattern']... [--include-tile 'pattern']... \
    [--settings 'key,val']... \
    [{b2f_args}]
```

**Parameter-to-flag mapping:**

| Parameter | Condition | CLI flag |
|-----------|-----------|----------|
| (cpus) | Always | `-p {task.cpus}` |
| `b2f_run_manifest` | Non-null (staged as `run_manifest`) | `-r {run_manifest}` |
| `b2f_panel_json` | Non-null (staged as `panel`) | `--panel {path}` |
| `b2f_tca_manifest_csv` | Non-null (staged as `tca_manifest`) | `--tca-manifest {path}` |
| `b2f_segmentation` | Non-null (staged as `segmentation`) | `--segmentation {dir}` (b2f ≥ `2.4.0`) |
| `b2f_analysis_region` | Non-null (staged as `analysis_region`) | `--analysis-region {dir}` (b2f ≥ `2.4.0`) |
| `b2f_log_level` | Non-null | `-l {value}` |
| `b2f_demux_only` | `true` | `--demux-only` |
| `b2f_detect_adapters` | `true` | `--detect-adapters` |
| `b2f_error_on_missing` | `true` | `--error-on-missing` |
| `b2f_no_error_on_invalid` | `true` | `--no-error-on-invalid` |
| `b2f_no_projects` | `true` | `--no-projects` |
| `b2f_legacy_fastq` | `true` | `--legacy-fastq` |
| `b2f_qc_only` | `true` | `--qc-only` |
| `b2f_skip_empty_fq_files` | `true` | `--skip-empty-fq-files` (b2f ≥ `2.4.0`) |
| `b2f_skip_multi_qc` | `true` | `--skip-multi-qc` |
| `b2f_skip_qc_report` | `true` | `--skip-qc-report` |
| `b2f_split_lanes` | `true` | `--split-lanes` |
| `b2f_group_fastq` | `true` | `--group-fastq` |
| `b2f_force_detect_index_orientation` | `true` | `--force-detect-index-orientation` (b2f ≥ `2.4.0`) |
| `b2f_force_index_orientation` | `true` | `--force-index-orientation` |
| `b2f_per_target_fastq` | `true` | `--per-target-fastq` |
| `b2f_num_unassigned` | Non-null | `--num-unassigned {value}` |
| `b2f_filter_mask` | Non-null | `--filter-mask {value}` |
| `b2f_flowcell_id` | Non-null | `--flowcell-id {value}` |
| `b2f_cyto_fastq_mask` | Non-null | `--cyto-fastq-mask {value}` |
| `filter_batch` | Non-null | `--batch {value}` |
| `b2f_exclude_tile` | Non-empty list | `--exclude-tile 'pattern'` (one per element) |
| `b2f_include_tile` | Non-empty list (or fallback from `tile`) | `--include-tile 'pattern'` (one per element) |
| `b2f_settings` | Non-empty list | `--settings 'key,val'` (one per element) |
| `b2f_args` | Non-null | Appended verbatim (deprecated — prefer `withName: BASES2FASTQ { ext.args = { ... } }` overlay) |

### Post-Processing Steps

After bases2fastq completes:

1. **Curated small-metadata mirror:** A `metrics/` directory is populated with
   top-level files (`*.json`, `*.csv`, etc.) using a denylist for bulk extensions
   (parquet, bam/bai, cram/crai, sam, fastq.gz, fq.gz) and a 100 MB per-file size
   cap. `info/` is symlinked in as a subdirectory. Used downstream by
   `build-spatialdata --b2f-dir`.

2. **Version capture:** The bases2fastq version is extracted and written to
   `versions.yml` in nf-core standard format. The extractor uses a hardened
   `sed -nE` regex anchored on the tool name (`^bases2fastq(dx)? version:?`) to
   tolerate colons / commas / multi-line license blurbs in the `--version`
   output — see `.cursor/rules/versions-yml.mdc` in `elembio-nf-modules`.

### Logging

All stdout and stderr are captured to `run.log` via `exec > >(tee $logfile)`.
The log includes the container image reference and the full bases2fastq output.

---

## 5. Output Directory Structure

All outputs are published to `{outdir}/bases2fastq/` by default. The publish
directory mode is controlled by `params.publish_dir_mode` (default: `copy`).

```
{outdir}/bases2fastq/
├── Panel.json                     Assay panel configuration
├── Metrics.csv                    Run-level demux metrics
├── IndexAssignment.csv            Index assignment statistics
├── RunManifest.csv                Run manifest
├── RunManifest.json               Run manifest (JSON)
├── RunParameters.json             Instrument parameters
├── RunStats.json                  Run-level statistics
├── UnassignedSequences.csv        Unassigned sequence report
├── *_QC.html                      QC report(s)
├── Samples/
│   └── {SampleName}/
│       ├── *.fastq.gz            Demultiplexed FASTQ files
│       ├── *_stats.json          Per-sample statistics
│       └── *_RunStats.json       Per-sample run statistics
├── info/
│   ├── Bases2Fastq.log           Bases2Fastq process log
│   └── RunManifestErrors.json    Manifest validation errors (if any)
└── run.log                        Full process stdout/stderr
```

**Publish rules** (composed in [`conf/modules.config`](../conf/modules.config) `withName: BASES2FASTQ { publishDir = ... }`):

Behavior is gated by the boolean param `disable_task_publish`. The two branches differ in directory layout and in how patterns are filtered.

**Branch A — `disable_task_publish = false` (default).** Publishes a structured `{outdir}/bases2fastq/...` tree using four pattern-scoped rules:

| Rule | Path | Pattern | What it captures |
|------|------|---------|------------------|
| 1 | `{outdir}/bases2fastq/` | `*.{json,csv,html,log}` | All top-level flat outputs (`Panel.json`, `Metrics.csv`, `RunStats.json`, `*_QC.html`, etc.) |
| 2 | `{outdir}/bases2fastq/` | `info/*.{log,json}` | Process log + manifest errors (preserves `info/` subdir) |
| 3 | `{outdir}/bases2fastq/` | `Samples/*/*.{json,fastq.gz}` | Per-sample outputs in flat (no-projects) layout |
| 4 | `{outdir}/bases2fastq/` | `Samples/*/*/*.{json,fastq.gz}` | Per-sample outputs in project-directory layout |

The curated `metrics/` mirror emit (`metrics_dir`) is **not** published in this branch — it's an internal channel consumed by downstream tools (`build-spatialdata --b2f-dir`) and lives only in the work directory.

**Branch B — `disable_task_publish = true`.** Publishes everything flat to `{outdir}/` with a single rule:

| Rule | Path | Mode | `saveAs` filter |
|------|------|------|-----------------|
| 1 | `{outdir}/` | `params.publish_dir_mode` (default `copy`) | `{ filename -> filename.equals('versions.yml') ? null : filename }` |

Used by downstream pipelines (e.g. `elembio-tetonatlas-nf`) that consume bases2fastq outputs in-place rather than from a categorized subdirectory. The `saveAs` closure drops `versions.yml` to keep the flat output clean.

In **both** branches, the same set of process outputs are emitted by the module (see the Outputs table above) — `disable_task_publish` only controls *where* they land on disk.

---

## 6. Channel Data Flow

The pipeline constructs input channels from parameters at launch and
passes them to the `BASES2FASTQ_SUBWORKFLOW`.

### 6.1 Input Channel Construction

```groovy
meta = [id: run_id]
run_manifest = params.b2f_run_manifest ? file(params.b2f_run_manifest, checkIfExists: true) : []

ch_segmentation     = params.b2f_segmentation     ? Channel.value(file(params.b2f_segmentation,     checkIfExists: true)) : Channel.value([])
ch_analysis_region  = params.b2f_analysis_region  ? Channel.value(file(params.b2f_analysis_region,  checkIfExists: true)) : Channel.value([])
ch_panel            = params.b2f_panel_json       ? Channel.value(file(params.b2f_panel_json,       checkIfExists: true)) : Channel.value([])
ch_tca_manifest     = params.b2f_tca_manifest_csv ? Channel.value(file(params.b2f_tca_manifest_csv, checkIfExists: true)) : Channel.value([])
```

When optional inputs are not provided, the channel emits an empty list (`Channel.value([])`) and the
BASES2FASTQ process checks for truthiness of the staged path to decide whether
to include the corresponding CLI flag.

### 6.2 Workflow

```groovy
include { BASES2FASTQ } from './modules/elembio/bases2fastq/main'

workflow {
    BASES2FASTQ (
        Channel.value([meta, run_dir]),
        run_manifest,
        ch_segmentation,
        ch_analysis_region,
        ch_panel,
        ch_tca_manifest
    )
}
```

The module is sourced from
[elembio-nf-modules](https://gitlab.com/elembio/analysis/elembio-nf-modules)
and installed via `nf-core modules install`.

### 6.3 Output Channels

The module emits the following named channels:

| Emit name | Source | Description |
|-----------|--------|-------------|
| `sample_fastq` | `BASES2FASTQ.out.sample_fastq` | Demultiplexed FASTQ files |
| `sample_fastq_gzi` | `BASES2FASTQ.out.sample_fastq_gzi` | BGZF block-index files (present only when `--bgzf-compression` is active) |
| `fastq_dir` | Derived | Path to bases2fastq output directory |
| `run_stats` | `BASES2FASTQ.out.run_stats` | Run-level `RunStats.json` |
| `b2f_log` | `BASES2FASTQ.out.b2f_log` | Bases2Fastq process log |
| `metrics_dir` | `BASES2FASTQ.out.metrics_dir` | Curated small-metadata mirror (consumed by `build-spatialdata --b2f-dir`) |
| `versions` | `BASES2FASTQ.out.versions` | Version tracking |

Individual BASES2FASTQ process outputs (Metrics.csv, RunStats.json, etc.) are
published via `modules.config` publishDir directives. Optional outputs use
`optional: true` and are not emitted if the file was not produced.

---

## 7. Configuration Profiles

### 7.1 Profile Summary

| Profile | Purpose | Config file |
|---------|---------|-------------|
| `docker` | Enable Docker container engine | Inline in `nextflow.config` |
| `test` | Simulated run for fast iteration | `conf/test.config` |
| `local` | Local compute with reduced resources | `conf/local.config` |
| `fusion` | Seqera Fusion file system | `conf/fusion.config` |
| `AVITI` | Full production AVITI flowcell | `conf/AVITI.config` |
| `AVITI_highmem` | AVITI high-memory profile | `conf/AVITI_highmem.config` |
| `ElembioCloud` | Elembio Cloud infrastructure | `conf/ElembioCloud.config` |
| `tower` | Seqera Platform (Tower) | `conf/tower.config` |
| `tower_spot` | AWS Batch Spot via Seqera Platform | `conf/tower_spot.config` |
| `notaskdir` | Flat publish directory (no task subdirs) | `conf/notaskdir.config` |

Profiles are combined: `-profile AVITI,docker` or `-profile test,docker`.

---

### 7.2 Base Configuration

Default resource allocations (from `conf/base.config`), always loaded:

| Label | CPUs | Memory | Time |
|-------|------|--------|------|
| (default) | 1 * attempt | 6 GB * attempt | 4 h * attempt |
| `process_low` | 2 * attempt | 12 GB * attempt | 4 h * attempt |
| `process_medium` | 6 * attempt | 36 GB * attempt | 8 h * attempt |
| `process_high` | 12 * attempt | 72 GB * attempt | 16 h * attempt |
| `process_long` | -- | -- | 20 h * attempt |
| `process_high_memory` | -- | 200 GB * attempt | -- |

**BASES2FASTQ-specific override (base.config):**

| Property | Value |
|----------|-------|
| CPUs | Step-down: `[48, 42, 36]` (attempt 1 = 48, attempt 2 = 42, attempt 3 = 36, attempt 4+ = 12) |
| Memory | 346 GB (constant across attempts) |
| Time | 2 h * attempt |
| maxRetries | 4 |

**Error strategy:** Retry on exit codes 130-145 and 104 (signal-related and
OOM). Retry on null, negative, or zero exit codes (unexpected termination).
Finish (terminate) on all other codes.

---

### 7.3 AVITI Profile

Production resources for full AVITI flowcells:

| Property | Value |
|----------|-------|
| CPUs | 46 |
| Memory | 186 GB |
| Time | 3 h |
| maxRetries | 2 |

Additional settings:
- `cleanup = true` (remove work directories after completion)
- Adapter trimming enabled: `b2f_settings = ["R1AdapterTrim,true", "R2AdapterTrim,true"]`
- AWS batch/client configuration for S3 transfer optimization

---

### 7.4 Test Profile

Designed for quick validation with a simulated dataset:

| Setting | Value |
|---------|-------|
| `run_dir` | `s3://element-public-data/bases2fastq-share/bases2fastq-v2/20230404-bases2fastq-sim-151-151-9-9/` |
| `b2f_run_manifest` | Matching `RunManifest.csv` from the same path |
| `b2f_settings` | `["R1AdapterTrim,true", "R2AdapterTrim,true"]` |
| Container | `904220683607.dkr.ecr.us-west-2.amazonaws.com/bases2fastq-release:latest` |

**Process resources (reduced):**

| Property | Value |
|----------|-------|
| CPUs | 2 |
| Memory | 6 GB |
| Time | 2 h |

**Global caps:** `max_cpus = 2`, `max_memory = 6.GB`, `max_time = 6.h`.

`cleanup = false` (preserve work directories for debugging).

---

### 7.5 Other Profiles

**local** -- Local compute with minimal resources:

| Property | Value |
|----------|-------|
| CPUs | 2 |
| Memory | 6 GB |
| `cleanup` | `false` |
| `fusion.enabled` | `false` |
| `process.scratch` | `true` |

**tower** -- Includes the nf-core AWS Tower config and sets profile metadata:
```
includeConfig "https://raw.githubusercontent.com/nf-core/configs/master/conf/aws_tower.config"
```

**tower_spot** -- Assigns BASES2FASTQ to a specific AWS Batch queue.

**fusion** -- Enables Seqera Fusion and Wave, disables scratch:
```
fusion.enabled = true
wave.enabled = true
process.scratch = false
```

**notaskdir** -- Overrides the default `publishDir` to publish all outputs flat.

---

### 7.6 Container Version

| Tool | Default Image | Default Tag |
|------|---------------|-------------|
| bases2fastq | `904220683607.dkr.ecr.us-west-2.amazonaws.com/bases2fastq-release` | `2.4.0-rc1` |

Controlled by two parameters:

| Parameter | Default |
|-----------|---------|
| `b2f_container_url` | `904220683607.dkr.ecr.us-west-2.amazonaws.com/bases2fastq-release` |
| `b2f_container_tag` | `2.4.0` |

The container reference is assembled as `${params.b2f_container_url}:${params.b2f_container_tag}`.

---

### 7.7 Resource Capping

All resources are capped by global maximums via the `check_max()` function
defined in `nextflow.config`:

| Parameter | Default |
|-----------|---------|
| `max_memory` | `384.GB` |
| `max_cpus` | `48` |
| `max_time` | `8.h` |

The `check_max()` function compares the requested resource against the cap and
returns the lesser value. If the cap is invalid, the original value is used with
a warning.

---

## 8. Failure Modes and Recovery

### 8.1 Retry Behavior

The base configuration retries failed tasks (from `base.config`):

| Exit code | Strategy |
|-----------|----------|
| 130-145, 104 (signals, OOM) | `retry` |
| null, negative, or zero (unexpected) | `retry` |
| All other codes | `finish` (terminate immediately) |

Maximum 4 retries (base label default), unlimited total errors (`maxErrors = -1`).

### 8.2 CPU Step-Down Retry Strategy

The BASES2FASTQ process uses a CPU step-down strategy. This reflects the
observation that bases2fastq may encounter thread contention or memory pressure
with high parallelism:

| Attempt | CPUs | Memory | Time |
|---------|------|--------|------|
| 1 | 48 | 346 GB | 2 h |
| 2 | 42 | 346 GB | 4 h |
| 3 | 36 | 346 GB | 6 h |
| 4+ | 12 | 346 GB | 2 h * attempt |

Memory remains constant at 346 GB across all attempts. Time scales linearly
with attempt number.

This strategy applies in the base configuration. The AVITI and test profiles
override it with fixed resource allocations.

### 8.3 Resume Behavior

Nextflow's `-resume` flag enables work directory caching. Successfully completed
tasks are skipped on re-run. Only failed or new tasks execute.

```bash
nextflow run bases2fastq-nf --run_dir /path/to/run -profile docker -resume
```

Cached results are stored in the `work/` directory. The cache is keyed on:
- Process name and script hash
- Input file hashes (content-based)
- Container image
- Parameter values (via CLI flag assembly)
