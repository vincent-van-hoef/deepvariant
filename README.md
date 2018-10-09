![deepvariant](https://raw.githubusercontent.com/nf-core/deepvariant/master/docs/images/deepvariant_logo.png)

# nf-core/deepvariant

**UNDER DEVELOPMENT: Deep Variant as a Nextflow pipeline**

[![Build Status](https://travis-ci.org/nf-core/deepvariant.svg?branch=master)](https://travis-ci.org/nf-core/deepvariant)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A50.32.0-brightgreen.svg)](https://www.nextflow.io/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](http://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/nfcore/deepvariant.svg)](https://hub.docker.com/r/nfcore/deepvariant)
![Singularity Container available](https://img.shields.io/badge/singularity-available-7E4C74.svg)

A Nextflow pipeline for running the [Google DeepVariant variant caller](https://github.com/google/deepvariant).

## What is DeepVariant and why in Nextflow?

The Google Brain Team in December 2017 released a [Variant Caller](https://www.ebi.ac.uk/training/online/course/human-genetic-variation-i-introduction/variant-identification-and-analysis/what-variant) based on DeepLearning: DeepVariant.

In practice, DeepVariant first builds images based on the BAM file, then it uses a DeepLearning image recognition approach to obtain the variants and eventually it converts the output of the prediction in the standard VCF format.

DeepVariant as a Nextflow pipeline provides several advantages to the users. It handles automatically, through **preprocessing steps**, the creation of some extra needed indexed and compressed files which are a necessary input for DeepVariant, and which should normally manually be produced by the users.
Variant Calling can be performed at the same time on **multiple BAM files** and thanks to the internal parallelization of Nextflow no resources are wasted.
Nextflow's support of Docker allows to produce the results in a computational reproducible and clean way by running every step inside of a **Docker container**.
Moreover, you can easily run DeepVariant as a Nextflow pipeline in the **cloud** through the Lifebit platform and let it do the hard work of configuring, scheduling and deploying for you.

For more detailed information about DeepVariant please refer to:
https://github.com/google/deepvariant
https://research.googleblog.com/2017/12/deepvariant-highly-accurate-genomes.html

## Quick Start

**Warning DeepVariant can be very computationally intensive to run**
A typical run on **whole genome data** looks like this:

```
git clone https://github.com/lifebit-ai/DeepVariant
cd DeepVariant
nextflow run main.nf --hg19 --bam_folder testdata
```

In this case variants are called on the two bam files contained in the lifebit-test-data/bam s3 bucket. The hg19 version of the reference genome is used.
Two vcf files are produced and can be found in the folder "results"

A typical run on **whole exome data** looks like this:

```
git clone https://github.com/lifebit-ai/DeepVariant
cd DeepVariant
nextflow run main.nf --exome --hg19 --bam_folder myBamFolder --bed myBedFile"
```

## Documentation

The nf-core/deepvariant documentation is split into the following files:

1. [Installation](docs/installation.md)
2. [Running the pipeline](docs/usage.md)
3. Pipeline configuration
   - [Adding your own system](docs/configuration/adding_your_own.md)
   - [Reference genomes](docs/configuration/reference_genomes.md)
4. [Output and how to interpret the results](docs/output.md)
5. [Troubleshooting](docs/troubleshooting.md)
6. [More about DeepVariant](docs/about.md)

## More about the pipeline

As shown in the following picture, the worklow both contains **preprocessing steps** ( light blue ones ) and proper **variant calling steps** ( darker blue ones ).

Some input files ar optional and if not given, they will be automatically created for the user during the preprocessing steps. If these are given, the preprocessing steps are skipped. For more information about preprocessing, please refer to the "INPUT PARAMETERS" section.

The worklow **accepts one reference genome and multiple BAM files as input**. The variant calling for the several input BAM files will be processed completely indipendently and will produce indipendent VCF result files. The advantage of this approach is that the variant calling of the different BAM files can be parallelized internally by Nextflow and take advantage of all the cores of the machine in order to get the results at the fastest.

<p align="center">
  <img src="https://github.com/lifebit-ai/DeepVariant/blob/master/pics/pic_workflow.jpg">
</p>

## Credits

This pipeline was originally developed by [Lifebit](https://lifebit.ai/?utm_campaign=documentation&utm_source=github&utm_medium=web) to ease and reduce cost for variant calling analyses. You can test the pipeline through Lifebit's Platform: [Deploit](https://deploit.lifebit.ai/app/home). This allows you to run Deepvariant over cloud in a matter of a couple of clicks: and for single users our service is completely free! Read more about DeepVariant in Nextflow in this [Blog post](https://blog.lifebit.ai/post/deepvariant/?utm_campaign=documentation&utm_source=github&utm_medium=web)

Many thanks to nf-core and those who have helped out along the way too, including (but not limited to): @ewels, @apeltzer & @MaxUlysse
