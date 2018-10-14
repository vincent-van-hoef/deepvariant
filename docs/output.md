# nf-core/deepvariant: Output

This document describes the processes and output produced by the pipeline.

Main steps:
- preprocessing of fasta/reference files (fai, fastagz, gzfai & gzi) 
    - These steps can be skipped if the the `--genome` options is used or the fai, fastagz, gzfai & gzi files are supplied
- preprocessing of BAM files
    - Also can be skipped if BAM files contain necessary read group line
- make examples
    - consumes reads and the reference genome to create TensorFlow examples for evaluation with deep learning models
- call variant
    - consumes TFRecord file(s) of tf.Examples protos created by make_examples and a deep learning model checkpoint and evaluates the model on each example in the input TFRecord.
- post processing
    - reads all of the output TFRecord files from call_variants, sorts them, combines multi-allelic records, and writes out a VCF file

For further reading and documentation about deepvariant see [google/deepvariant](https://github.com/google/deepvariant)

## VCF

The output from DeepVariant is a variant call file or [vcf v4.2](https://samtools.github.io/hts-specs/VCFv4.2.pdf)

**Output directory: `results`** (by default)

- `pipeline_info`
  - produced by nextflow
- `{bamSampleName}.vcf`
  - output vcf file produced by deepvariant
