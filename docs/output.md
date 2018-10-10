# nf-core/deepvariant: Output

This document describes the output produced by the pipeline.

## VCF

The output from DeepVariant is a variant call file or vcf

For further reading and documentation about deepvariant see [google/deepvariant](https://github.com/google/deepvariant)

**Output directory: `results`** (by default)

- `pipeline_info`
  - produced by nextflow
- `{bamSampleName}.vcf`
  - output vcf file produced by deepvariant
