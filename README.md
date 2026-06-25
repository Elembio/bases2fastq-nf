# bases2fastq-nf

Nextflow pipeline for running Element Biosciences [Bases2Fastq](https://docs.elembio.io/docs/bases2fastq/introduction/) — demultiplexing and FASTQ generation from AVITI sequencing data.

---

## Quick Start

```bash
# Minimal run (requires Docker)
nextflow run . --run_dir /path/to/aviti/run/directory -profile docker

# Test profile (simulated run, fast iteration)
nextflow run . -profile test,docker

# AWS Batch via Seqera Platform
nextflow run . --run_dir s3://bucket/runs/RUNID/ -profile tower
```

The only required parameter is `--run_dir` — the path to an AVITI run directory (local or S3).

---

## Pipeline Overview

```
AVITI Run Directory
        │
        └──► BASES2FASTQ      Demux base calls → FASTQ per sample/well
```

---

## Requirements

- **Java** >= 11 (OpenJDK recommended)
- **Nextflow** >= 21.10.3
- **Docker** or **Singularity/Apptainer**

---

## Parameters

### Required

| Parameter | Description |
|-----------|-------------|
| `--run_dir` | Path to AVITI run directory (local or S3). |

### Key Optional

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--outdir` | `./results` | Output directory. |
| `--b2f_run_manifest` | `null` | Path to a custom RunManifest.csv. |
| `--tile` | `[]` | Tile regex pattern(s) as a list. Falls back to `b2f_include_tile`. |
| `--filter_batch` | `null` | Restrict to specific batches, comma-delimited (e.g., `B01,B02`). |
| `--b2f_include_tile` | `[]` | Tile inclusion patterns. When set, auto-excludes all other tiles. |
| `--b2f_settings` | `[]` | Repeated `--settings` flags (e.g., `["R1AdapterTrim,true"]`). |
| `--b2f_no_projects` | `false` | Disable project directories (flat Samples/ layout). |
| `--b2f_args` | `null` | Additional custom arguments passed directly to bases2fastq. |

For the full parameter reference, see [docs/parameters.md](docs/parameters.md).

---

## Output Structure

```
{outdir}/bases2fastq/
├── Metrics.csv                     Run-level demux metrics
├── IndexAssignment.csv             Index assignment statistics
├── RunManifest.csv                 Run manifest (copy)
├── RunManifest.json                Run manifest (JSON)
├── RunParameters.json              Instrument parameters (copy)
├── RunStats.json                   Run statistics
├── UnassignedSequences.csv         Unassigned sequence report
├── Panel.json                      Assay panel configuration (copy)
├── *_QC.html                       QC report(s)
├── Samples/
│   └── {SampleName}/
│       ├── *.fastq.gz             Demultiplexed FASTQ files
│       ├── *_stats.json           Per-sample statistics
│       └── *_RunStats.json        Per-sample run statistics
├── info/
│   ├── Bases2Fastq.log            Bases2Fastq process log
│   └── RunManifestErrors.json     Manifest validation errors (if any)
└── run.log                        Full process stdout/stderr
```

---

## Configuration Profiles

| Profile | Description |
|---------|-------------|
| `docker` | Run with Docker containers |
| `test` | Simulated run — fast iteration |
| `local` | Local compute with reduced resources |
| `fusion` | Seqera Fusion file system |
| `tower` | Seqera Platform (Tower) |
| `notaskdir` | Flat publish directory (no task subdirs) |

---

## Container Images

| Tool | Image | Version Control |
|------|-------|-----------------|
| bases2fastq | `904220683607.dkr.ecr.us-west-2.amazonaws.com/bases2fastq-release` | `b2f_container_tag` (default: `2.4.0`) |

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/parameters.md](docs/parameters.md) | Complete parameter reference |
| [docs/usage.md](docs/usage.md) | Practical usage examples and configuration guides |
| [docs/specification.md](docs/specification.md) | Definitive pipeline specification |

External references:

- [Bases2Fastq Documentation](https://docs.elembio.io/docs/bases2fastq/introduction/) — detailed execution information
- [Run Manifest Documentation](https://docs.elembio.io/docs/run-manifest/seq-prepare-manifest/) — sample sheet configuration

---

## Development

### Developer Setup

Requires **Nextflow** (`>= 21.10.3`) on your `PATH`.

```bash
# Run with test profile
nextflow run . -profile test,docker

# Run nf-test suite
nf-test test
```

### Releasing a New Version

1. Update `CHANGELOG.md` with a new `## [x.y.z]` section describing the changes
2. Bump `version` in the `manifest` block of `nextflow.config`
3. Commit and push with tags: `git push && git push --tags`

---

## Authors

- Bryan R. Lajoie
- Rosita Bajari
- Andrew Altomare

## License

Use subject to license available at go.elembio.link/eula.
