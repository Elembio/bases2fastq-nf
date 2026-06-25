# Usage Guide

Practical examples for running the bases2fastq-nf pipeline.

---

## Prerequisites

### Software Requirements

1. **Nextflow** (>= 21.10.3)
   ```bash
   curl -s https://get.nextflow.io | bash
   ```

2. **Container Runtime** (one of):
   - Docker
   - Singularity/Apptainer
   - Podman

### Data Requirements

The pipeline expects an AVITI run directory produced by the Element AVITI System.

---

## Basic Usage

### Local Run with Docker

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/aviti/run/directory \
    -profile docker
```

### AWS S3 Data

```bash
nextflow run bases2fastq-nf \
    --run_dir s3://bucket/runs/20240101_AV123456_WHTF-1234/ \
    -profile docker
```

The `run_id` is auto-extracted from the `run_dir` path (the last path component).

---

## Test Run

Run with a minimal simulated dataset to verify installation:

```bash
git clone https://gitlab.com/elembio/analysis/bases2fastq-nf.git
cd bases2fastq-nf

nextflow run . -profile test,docker
```

The test profile:
- Uses a simulated 151-151-9-9 run from public S3
- Enables adapter trimming via `b2f_settings`
- Outputs to `results/` directory

---

## Subset by Tile

### Include Specific Tiles

Process only specific tiles using `b2f_include_tile`. When include patterns are set, all other tiles are auto-excluded:

```groovy
// In a config file — single tile
params.b2f_include_tile = ["L1R12C03S1"]

// Multiple tiles
params.b2f_include_tile = ["L1R12C03S1", "L1R12C04S1"]
```

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    -params-file params.json \
    -profile docker
```

### Using Shared Tile Parameter

If `b2f_include_tile` is empty, the module falls back to the shared `tile` parameter (used across Element pipelines):

```groovy
params.tile = ["L1R12C03S1"]
```

### Exclude Specific Tiles

```groovy
params.b2f_exclude_tile = ["L1R01C01S1", "L1R01C02S1"]
```

---

## Subset by Batch

Process only specific batches:

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    --filter_batch "B01,B02" \
    -profile docker
```

---

## Custom Run Manifest

Override the run manifest discovered from the run directory:

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    --b2f_run_manifest /path/to/custom/RunManifest.csv \
    -profile docker
```

---

## Adapter Trimming

Enable adapter trimming via `b2f_settings`:

```groovy
// In a config file
params.b2f_settings = ["R1AdapterTrim,true", "R2AdapterTrim,true"]
```

Or via `-params-file params.json`:

```json
{
    "run_dir": "/path/to/run",
    "b2f_settings": ["R1AdapterTrim,true", "R2AdapterTrim,true"]
}
```

---

## Demux-Only Mode

Generate demux metrics without producing FASTQ files:

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    --b2f_demux_only true \
    -profile docker
```

---

## QC-Only Mode

Generate QC metrics without producing FASTQ files:

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    --b2f_qc_only true \
    -profile docker
```

---

## Legacy FASTQ Naming

Use Illumina-compatible naming (`SampleName_S1_L001_R1_001.fastq.gz`):

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    --b2f_legacy_fastq true \
    -profile docker
```

---

## AWS Batch Execution

### Using Seqera Tower (Platform)

```bash
nextflow run bases2fastq-nf \
    --run_dir s3://bucket/runs/RUNID/ \
    -profile tower_spot \
    -with-tower
```

---

## Custom Output Directory

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    --outdir /path/to/output \
    -profile docker
```

---

## Resume Failed Runs

Nextflow automatically caches completed tasks. To resume a failed run:

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    -profile docker \
    -resume
```

---

## Resource Configuration

### Override Process Resources

Create a custom config file:

```groovy
// custom_resources.config
process {
    withName: 'BASES2FASTQ' {
        cpus = 24
        memory = '96.GB'
        time = '4.h'
    }
}
```

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    -c custom_resources.config \
    -profile docker
```

### Global Resource Limits

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    --max_memory 128.GB \
    --max_cpus 24 \
    --max_time 8.h \
    -profile docker
```

---

## Passthrough Arguments

For bases2fastq CLI flags not exposed as named parameters, use `--b2f_args`:

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    --b2f_args "--some-advanced-flag value" \
    -profile docker
```

---

## Debugging

### Enable Detailed Logging

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    -profile docker \
    -with-report \
    -with-timeline \
    -with-trace
```

### Increase bases2fastq Log Level

```bash
nextflow run bases2fastq-nf \
    --run_dir /path/to/run \
    --b2f_log_level DEBUG \
    -profile docker
```
