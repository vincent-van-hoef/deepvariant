#!/usr/bin/env nextflow
/*
========================================================================================
                         nf-core/deepvariant
========================================================================================
 nf-core/deepvariant Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/nf-core/deepvariant
----------------------------------------------------------------------------------------
*/


def helpMessage() {
    log.info"""
    =========================================
    nf-core/deepvariant v${params.pipelineVersion}
    =========================================
    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run nf-core/deepvariant --genome hg19 --bam_folder "s3://deepvariant-data/test-bam/" -profile standard,docker

    Mandatory arguments:
      --bam_folder                  Path to folder containing BAM files (reads must have been aligned to specified reference file, see below)
      OR
      --bam                         Path to BAM file (reads must have been aligned to specified reference file, see below)

    References:                     If you wish to overwrite deafult reference of hg19.
      --genome                      Refernce genome: hg19 (default) | hg19chr20 (for testing) | h38 | grch37primary | hs37d5
      --genomes_base                Base directory location of genomes (default = "s3://deepvariant-data/genomes")
      OR
      --fasta                       Path to fasta reference
      --fai                         Path to fasta index generated using `samtools faidx`
      --fastagz                     Path to gzipped fasta
      --gzfai                       Path to index of gzipped fasta
      --gzi                         Path to bgzip index format (.gzi) produced by faidx
      *Pass all five files above to skip the fasta preprocessing step

      Options:
      -profile                      Configuration profile to use. Can use multiple (comma separated)
                                    Available: standard, conda, docker, singularity, awsbatch, test
      --exome                       For exome bam files
      --bed                         Path to bedfile
      --modelBase                   Base directory for location of model folder (default = "s3://deepvariant-data")
      --modelFolder                 Folder containing own DeepVariant trained data model
      --modelName                   Name of own DeepVariant trained data model
      --rgid                        Bam file read group line id incase its needed (default = 4)
      --rglb                        Bam file read group line library incase its needed (default = 'lib1')
      --rgpl                        Bam file read group line platform incase its needed (default = 'illumina')
      --rgpu                        Bam file read group line platform unit incase its needed (default = 'unit1')
      --rgsm                        Bam file read group line sample incase its needed (default = 20)

    Other options:
      --outdir                      The output directory where the results will be saved (default = results)
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.
      --help                        Bring up this help message

    AWSBatch options:
      --awsqueue                    The AWSBatch JobQueue that needs to be set when running on AWSBatch
      --awsregion                   The AWS Region for your AWS Batch job to run on
    """.stripIndent()
}

/*
 * SET UP CONFIGURATION VARIABLES
 */

// Show help emssage
if (params.help){
    helpMessage()
    exit 0
}

//set model for call variants either whole genome or exome
model= params.exome ? 'wes' : 'wgs'

//if user inputs fasta set their reference files otherwise use hg19 as default
if(params.fasta){
  fasta = params.fasta
  fai = params.fai ? params.fai : false
  fastagz = params.fai ? params.fastagz : false
  gzfai = params.fai ? params.gzfai : false
  gzi = params.fai ? params.gzi : false
  bed = params.bed
} else {
  params.genome = 'hg19'
}

//set genome options
if (params.genome){
  fasta = params.genome ? params.genomes[ params.genome ].fasta ?: false : false
  fai = params.genome ? params.genomes[ params.genome ].fai ?: false : false
  fastagz = params.genome ? params.genomes[ params.genome ].fastagz ?: false : false
  gzfai = params.genome ? params.genomes[ params.genome ].gzfai ?: false : false
  gzi = params.genome ? params.genomes[ params.genome ].gzi ?: false : false
  bed = params.genome ? params.genomes[ params.genome ].bed ?: false : false
}

(fastaCh, fastaCh1, fastaCh2, fastaCh3, fastaCh4) = Channel.fromPath(fasta).into(5)

bedCh = Channel
    .fromPath(bed)
    .ifEmpty { exit 1, "please specify --bed option (--bed bedfile)"}

if(fai){
faiCh = Channel
    .fromPath(fai)
    .ifEmpty{exit 1, "Fai file not found: ${params.fai}"}
}

if(fastagz){
fastaGzCh = Channel
    .fromPath(fastagz)
    .ifEmpty{exit 1, "Fastagz file not found: ${params.fastagz}"}
}

if(gzfai){
gzFaiCh = Channel
    .fromPath(gzfai)
    .ifEmpty{exit 1, "gzfai file not found: ${params.gzfai}"}
}

if(gzi){
gziCh = Channel
    .fromPath(gzi)
    .ifEmpty{exit 1, "gzi file not found: ${params.gzi}"}
}
/*--------------------------------------------------
  Bam related input files
---------------------------------------------------*/
if(params.bam_folder) {
  Channel
      .fromPath("${params.bam_folder}/${params.bam_file_prefix}*.bam")
      .ifEmpty { exit 1, "${params.bam_folder}/${params.bam_file_prefix}*.bam not found"}
      .map{ file -> tuple(file.name, file) }
      .set{bamChannel}
} else if(params.bam) {
  Channel
      .fromPath(params.bam)
      .ifEmpty { exit 1, "${params.bam} not found"}
      .map{ file -> tuple(file.name, file) }
      .set{bamChannel}
} else {
  exit 1, "please specify --bam OR --bam_folder"
}

/*--------------------------------------------------
  For workflow summary
---------------------------------------------------*/
// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}

// Check workDir/outdir paths to be S3 buckets if running on AWSBatch
// related: https://github.com/nextflow-io/nextflow/issues/813
if( workflow.profile == 'awsbatch') {
    if(!workflow.workDir.startsWith('s3:') || !params.outdir.startsWith('s3:')) exit 1, "Workdir or Outdir not on S3 - specify S3 Buckets for each to run on AWSBatch!"
}


// Header log info
log.info """=======================================================
                                          ,--./,-.
          ___     __   __   __   ___     /,-._.--~\'
    |\\ | |__  __ /  ` /  \\ |__) |__         }  {
    | \\| |       \\__, \\__/ |  \\ |___     \\`-._,-`-,
                                          `._,._,\'
nf-core/deepvariant v${params.pipelineVersion}"
======================================================="""
def summary = [:]
summary['Pipeline Name']    = 'nf-core/deepvariant'
summary['Pipeline Version'] = params.pipelineVersion
if(params.bam_folder) summary['Bam folder'] = params.bam_folder
if(params.bam) summary['Bam file']          = params.bam
summary['Bed file']                         = params.bed
if(params.genome) summary['Reference genome']    = params.genome
if(params.fasta) summary['Fasta Ref']            = params.fasta
if(params.fai) summary['Fasta Index']            = params.fai
if(params.fastagz) summary['Fasta gzipped ']     = params.fastagz
if(params.gzfai) summary['Fasta gzipped Index']  = params.gzfai
if(params.gzi) summary['Fasta bgzip Index']      = params.gzi
if(params.rgid != 4) summary['BAM Read Group ID']         = params.rgid
if(params.rglb != 'lib1') summary['BAM Read Group Library']         = params.rglb
if(params.rgpl != 'illumina') summary['BAM Read Group Platform']    = params.rgpl
if(params.rgpu != 'unit1') summary['BAM Read Group Platform Unit']  = params.rgpu
if(params.rgsm != 20) summary['BAM Read Group Sample']              = params.rgsm
summary['Max Memory']       = params.max_memory
summary['Max CPUs']         = params.max_cpus
summary['Max Time']         = params.max_time
summary['Model']            = model
summary['Output dir']       = params.outdir
summary['Working dir']      = workflow.workDir
summary['Container Engine'] = workflow.containerEngine
if(workflow.containerEngine) summary['Container'] = workflow.container
summary['Current home']     = "$HOME"
summary['Current user']     = "$USER"
summary['Current path']     = "$PWD"
summary['Working dir']      = workflow.workDir
summary['Output dir']       = params.outdir
summary['Script dir']       = workflow.projectDir
summary['Config Profile']   = workflow.profile
if(workflow.profile == 'awsbatch'){
   summary['AWS Region'] = params.awsregion
   summary['AWS Queue'] = params.awsqueue
}
if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="


def create_workflow_summary(summary) {

    def yaml_file = workDir.resolve('workflow_summary_mqc.yaml')
    yaml_file.text  = """
    id: 'nf-core-deepvariant-summary'
    description: " - this information is collected when the pipeline is started."
    section_name: 'nf-core/deepvariant Workflow Summary'
    section_href: 'https://github.com/nf-core/deepvariant'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
        </dl>
    """.stripIndent()

   return yaml_file
}


/********************************************************************
  process preprocessFASTA
  Collects all the files related to the reference genome, like
  .fai,.gz ...
  If the user gives them as an input, they are used
  If not they are produced in this process given only the fasta file.
********************************************************************/

if(!fai) {
  process preprocessFAI {
      publishDir "$baseDir/sampleDerivatives"

      input:
      file(fasta) from fastaCh1

      output:
      file("${fasta}.fai") into faiCh

      script:
      """
      samtools faidx $fasta
      """
  }
} else {
  fa_fai = Channel.from()
}

if(!fastagz) {
  process preprocessFASTGZ {
      publishDir "$baseDir/sampleDerivatives"

      input:
      file(fasta) from fastaCh2

      output:
      file("*.gz") into (tmpFastaGzCh, fastaGzCh)

      script:
      """
      bgzip -c ${fasta} > ${fasta}.gz
      """
  }
}

if(!gzfai) {
  process preprocessGZFAI {
    publishDir "$baseDir/sampleDerivatives"

    input:
    file(fasta) from fastaCh3
    file(fastagz) from tmpFastaGzCh

    output:
    file("*.gz.fai") into gzFaiCh

    script:
    """
    samtools faidx $fastagz
    """
  }
}

if(!gzi){
  process preprocessGZI {
    publishDir "$baseDir/sampleDerivatives"

    input:
    file(fasta) from fastaCh4

    output:
    file("*.gz.gzi") into gziCh

    script:
    """
    bgzip -c -i ${fasta} > ${fasta}.gz
    """
  }
}

fastaChannel = Channel.from(fastaCh).mix(faiCh, fastaGzCh, gzFaiCh, gziCh).collect()

/********************************************************************
  process preprocessBAM
  If the user gives the index files for the bam files as an input, they are used
  If not they are produced in this process given only the fasta file.
  Moreover this takes care of the read group line too.
********************************************************************/


process preprocessBAM{


  tag "${bam[0]}"
  publishDir "$baseDir/sampleDerivatives"

  input:
  set val(prefix), file(bam) from bamChannel

  output:
  set file("ready/${bam[0]}"), file("ready/${bam[0]}.bai") into completeChannel

  script:
  """
  mkdir ready
  [[ `samtools view -H ${bam[0]} | grep '@RG' | wc -l`   > 0 ]] && { mv $bam ready;}|| { picard AddOrReplaceReadGroups \
  I=${bam[0]} \
  O=ready/${bam[0]} \
  RGID=${params.rgid} \
  RGLB=${params.rglb} \
  RGPL=${params.rgpl} \
  RGPU=${params.rgpu} \
  RGSM=${params.rgsm};}
  cd ready ;samtools index ${bam[0]};
  """
}


//make tupule of reference files using fasta file as identifier
fastaChannel.map{file -> tuple (1,file[0],file[1],file[2],file[3],file[4], file[5])}
            .set{all_fa};

completeChannel.map { file -> tuple(1,file[0],file[1]) }
               .set{all_bam};

all_fa.cross(all_bam)
      .set{all_fa_bam};

      /********************************************************************
        process makeExamples
        Getting bam files and converting them to images ( named examples )

	Can be parallelized through the params.n_shards
	( if params.n_shards >= 1 parallelization happens automatically)
      ********************************************************************/

  process makeExamples{

    tag "${bam[1]}"

    input:
    set file(fasta), file(bam) from all_fa_bam
    file(bed) from bedCh

    output:
    set file("${fasta[1]}"),file("${fasta[1]}.fai"),file("${fasta[1]}.gz"),file("${fasta[1]}.gz.fai"), file("${fasta[1]}.gz.gzi"),val("${bam[1]}"), file("shardedExamples") into examples

    script:
    """
    mkdir logs
    mkdir shardedExamples
    dv_make_examples.py \
    --cores ${task.cpus} \
    --sample ${bam[1]} \
    --ref ${fasta[1]}.gz \
    --reads ${bam[1]} \
    --regions ${bed} \
    --logdir logs \
    --examples shardedExamples
    """
  }
/********************************************************************
  process call_variants
  Doing the variant calling based on the ML trained model.
********************************************************************/

process call_variants{

  tag "${bam}"

  input:
  set file(fasta),file("${fasta}.fai"),file("${fasta}.gz"),file("${fasta}.gz.fai"), file("${fasta}.gz.gzi"),val(bam), file("shardedExamples") from examples
  file 'dv2/models' from model

  output:
  set file(fasta),file("${fasta}.fai"),file("${fasta}.gz"),file("${fasta}.gz.fai"), file("${fasta}.gz.gzi"), val(bam), file('call_variants_output.tfrecord') into called_variants

  script:
  """
  dv_call_variants.py \
    --cores ${task.cpus} \
    --sample ${bam} \
    --outfile call_variants_output.tfrecord \
    --examples shardedExamples \
    --model ${model}
  """
}



/********************************************************************
  process call_variants
  Trasforming the variant calling output (tfrecord file) into a standard vcf file.
********************************************************************/

process postprocess_variants{

  tag "$bam"

  publishDir params.outdir, mode: 'copy'

  input:
  set file(fasta),file("${fasta}.fai"),file("${fasta}.gz"),file("${fasta}.gz.fai"), file("${fasta}.gz.gzi"), val(bam),file('call_variants_output.tfrecord') from called_variants

  output:
   set val(bam),file("${bam}.vcf") into postout

  script:
  """
  dv_postprocess_variants.py \
  --ref "${fasta}.gz" \
  --infile call_variants_output.tfrecord \
  --outfile "${bam}.vcf"
  """
}

/*
 * Parse software version numbers
 */
process get_software_versions {

    output:
    file 'software_versions_mqc.yaml' into software_versions_yaml

    script:
    """
    echo $workflow.manifest.version &> v_nf_deepvariant.txt
    echo $workflow.nextflow.version &> v_nextflow.txt
    python --version &> v_python.txt
    pip --version &> v_pip.txt
    samtools --version &> v_samtools.txt
    lbzip2 --version &> v_lbzip2.txt
    bzip2 --version &> v_bzip2.txt
    scrape_software_versions.py &> software_versions_mqc.yaml
    """
}

workflow.onComplete {
  // Set up the e-mail variables
  def subject = "[nf-core/deepvariant] Successful: $workflow.runName"
  if(!workflow.success){
    subject = "[nf-core/deepvariant] FAILED: $workflow.runName"
  }
  def email_fields = [:]
  email_fields['version'] = params.pipelineVersion
  email_fields['runName'] = custom_runName ?: workflow.runName
  email_fields['success'] = workflow.success
  email_fields['dateComplete'] = workflow.complete
  email_fields['duration'] = workflow.duration
  email_fields['exitStatus'] = workflow.exitStatus
  email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
  email_fields['errorReport'] = (workflow.errorReport ?: 'None')
  email_fields['commandLine'] = workflow.commandLine
  email_fields['projectDir'] = workflow.projectDir
  email_fields['summary'] = summary
  email_fields['summary']['Date Started'] = workflow.start
  email_fields['summary']['Date Completed'] = workflow.complete
  email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
  email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
  if(workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
  if(workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
  if(workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
  email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
  email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
  email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

  // Render the TXT template
  def engine = new groovy.text.GStringTemplateEngine()
  def tf = new File("$baseDir/assets/email_template.txt")
  def txt_template = engine.createTemplate(tf).make(email_fields)
  def email_txt = txt_template.toString()

  // Render the HTML template
  def hf = new File("$baseDir/assets/email_template.html")
  def html_template = engine.createTemplate(hf).make(email_fields)
  def email_html = html_template.toString()

  // Render the sendmail template
  def smail_fields = [ email: params.email, subject: subject, email_txt: email_txt, email_html: email_html, baseDir: "$baseDir" ]
  def sf = new File("$baseDir/assets/sendmail_template.txt")
  def sendmail_template = engine.createTemplate(sf).make(smail_fields)
  def sendmail_html = sendmail_template.toString()

  // Send the HTML e-mail
  if (params.email) {
      try {
        if( params.plaintext_email ){ throw GroovyException('Send plaintext e-mail, not HTML') }
        // Try to send HTML e-mail using sendmail
        [ 'sendmail', '-t' ].execute() << sendmail_html
        log.info "[nf-core/deepvariant] Sent summary e-mail to $params.email (sendmail)"
      } catch (all) {
        // Catch failures and try with plaintext
        [ 'mail', '-s', subject, params.email ].execute() << email_txt
        log.info "[nf-core/deepvariant] Sent summary e-mail to $params.email (mail)"
      }
  }

  // Write summary e-mail HTML to a file
  def output_d = new File( "${params.outdir}/Documentation/" )
  if( !output_d.exists() ) {
    output_d.mkdirs()
  }
  def output_hf = new File( output_d, "pipeline_report.html" )
  output_hf.withWriter { w -> w << email_html }
  def output_tf = new File( output_d, "pipeline_report.txt" )
  output_tf.withWriter { w -> w << email_txt }

  log.info "[nf-core/deepvariant] Pipeline Complete! You can find your results in $baseDir/${params.outdir}"
}
