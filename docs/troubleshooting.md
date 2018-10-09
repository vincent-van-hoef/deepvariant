# nf-core/deepvariant: Troubleshooting

## About preprocessing

DeepVariant, in order to run at its fastest, requires some indexed and compressed versions of both the reference genome and the BAM files. With DeepVariant in Nextflow, if you wish, you can only use as an input the fasta and the BAM file and let us do the work for you in a clean and standarized way (standard tools like [samtools](http://samtools.sourceforge.net/) are used for indexing and every step is run inside of a Docker container).

This is how the list of the needed input files looks like. If these are passed all as input parameters, the preprocessing steps will be skipped.

```
NA12878_S1.chr20.10_10p1mb.bam   NA12878_S1.chr20.10_10p1mb.bam.bai
ucsc.hg19.chr20.unittest.fasta   ucsc.hg19.chr20.unittest.fasta.fai
ucsc.hg19.chr20.unittest.fasta.gz  ucsc.hg19.chr20.unittest.fasta.gz.fai   ucsc.hg19.chr20.unittest.fasta.gz.gzi
```

If you do not have all of them, these are the file you can give as input to the Nextflow pipeline, and the rest will be automatically produced for you .

```
NA12878_S1.chr20.10_10p1b.bam
ucsc.hg19.chr20.unittest.fasta
```

## Input files not found

Use this to specify the location of your input folder containing BAM files

- `--bam_folder`

```
--bam_folder "/path/to/folder/where/bam/files/are"            REQUIRED
--getBai "true"                                               OPTIONAL  (default: "false")
```

- In case only some specific files inside the BAM folder should be used as input, a file prefix can be defined by:
  - `--bam_file_prefix`

```
--bam_file_prefix MYPREFIX
```

All the BAM files on which the variant calling should be performed should be all stored in the same folder. If you already have the index files (BAI) they should be stored in the same folder and called with the same prefix as the correspoding BAM file ( e.g. file.bam and file.bam.bai ).

**! TIP**
All the input files can be used in s3 buckets too and the s3://path/to/files/in/bucket can be used instead of a local path.

## Data organization

The pipeline can't take a list of multiple input files - it takes a glob expression. If your input files are scattered in different paths then we recommend that you generate a directory with symlinked files. If running in paired end mode please make sure that your files are sensibly named so that they can be properly paired. See the previous point.

## Extra resources and getting help

If you still have an issue with running the pipeline then feel free to contact us.
Have a look at the [pipeline website](https://github.com/nf-core/deepvariant) to find out how.

If you have problems that are related to Nextflow and not our pipeline then check out the [Nextflow gitter channel](https://gitter.im/nextflow-io/nextflow) or the [google group](https://groups.google.com/forum/#!forum/nextflow).
