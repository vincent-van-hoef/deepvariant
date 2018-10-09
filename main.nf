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

    nextflow run main.nf --hg19 --bam_folder "s3://deepvariant-data/test-bam/" -profile standard,docker

    Mandatory arguments:
      --bam_folder                  Path to folder containing BAM files (reads must be aligned to specified reference file, see below)

    References:                     If you wish to overwrite deafult reference of hg19.
      --hg19                        Default for if reads were aligned against hg19 reference genome to produce input bam file(s)
      --hg19chr20                   To peform DeepVariant on chr20 only for testing purposes
      --h38                         Use if reads were aligned against GRCh38 reference genome to produce input bam file(s)
      --grch37primary               Use if reads were aligned against GRCh37 primary reference genome to produce input bam file(s)
      --hs37d5                      Use if reads were aligned against hs37d5 reference genome to produce input bam file(s)
      OR
      --fasta                       Path to fasta reference
      --fai                         Path to fasta index generated using `samtools faidx`
      --fastagz                     Path to gzipped fasta
      --gzfai                       Path to index of gzipped fasta
      --gzi                         Path to bgzip index format (.gzi) produced by faidx
      *Pass all five files above to skip preprocessing step

      Options:
      -profile                      Configuration profile to use. Can use multiple (comma separated)
                                    Available: standard, conda, docker, singularity, awsbatch, test
      --exome                       For exome bam files
      --bed                         Path to bedfile
      --j                           Number of cores used by machine for makeExamples (default = 2)
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

/*--------------------------------------------------
  Model folder
  Content: trained model.
  For exact information refer to documentation.
  Can be substitued with own model folder.
---------------------------------------------------*/
params.modelFolder="s3://deepvariant-data/models"
params.modelName="model.ckpt";
params.exome="";
if(params.exome){
  model=file("s3://deepvariant-data/models/exome");
}
else{
  model=file("${params.modelFolder}");
}


/*--------------------------------------------------
  Using the BED file
---------------------------------------------------*/
params.bed=""
if(params.exome){
  assert (params.bed != true) && (params.bed != null) : "please specify --bed option (--bed bedfile)"
  bedfile=file("${params.bed}")
}

/*--------------------------------------------------
  Cores of the machine --> used for process makeExamples
  default:2
---------------------------------------------------*/
int cores = Runtime.getRuntime().availableProcessors();
params.j=cores
numberShardsMinusOne=params.j-1;

/*--------------------------------------------------
  Fasta related input files

  You can use the flag --hg19 for using the hg19 version of the Genome.
  You can use the flag --h38 for using the GRCh38.p10 version of the Genome.

  They can be passed manually, through the parameter:
  	params.fasta="/my/path/to/file";
  And if already at user's disposal:
	params.fai="/my/path/to/file";
	params.fastagz="/my/path/to/file";
	params.gzfai="/my/path/to/file";
	params.gzi="/my/path/to/file";

---------------------------------------------------*/

params.hg19="true";
params.h38="";
params.test="";
params.hg19chr20="";
params.grch37primary="";
params.hs37d5="";

params.fasta="nofasta";
params.fai="nofai";
params.fastagz="nofastagz";
params.gzfai="nogzfai";
params.gzi="nogzi";

if(!("nofasta").equals(params.fasta)){
  fasta=file(params.fasta)
  fai=file(params.fai);
  fastagz=file(params.fastagz);
  gzfai=file(params.gzfai);
  gzi=file(params.gzi);
}
else if(params.h38 ){
  fasta=file("s3://deepvariant-data/genomes/h38/GRCh38.p10.genome.fa");
  fai=file("s3://deepvariant-data/genomes/h38/GRCh38.p10.genome.fa.fai");
  fastagz=file("s3://deepvariant-data/genomes/h38/GRCh38.p10.genome.fa.gz");
  gzfai=file("s3://deepvariant-data/genomes/h38/GRCh38.p10.genome.fa.gz.fai");
  gzi=file("s3://deepvariant-data/genomes/h38/GRCh38.p10.genome.fa.gz.gzi");
}
else if(params.hs37d5){
  fasta=file("s3://deepvariant-data/genomes/hs37d5/hs37d5.fa");
  fai=file("s3://deepvariant-data/genomes/hs37d5/hs37d5.fa.fai");
  fastagz=file("s3://deepvariant-data/genomes/hs37d5/hs37d5.fa.gz");
  gzfai=file("s3://deepvariant-data/genomes/hs37d5/hs37d5.fa.gz.fai");
  gzi=file("s3://deepvariant-data/genomes/hs37d5/hs37d5.fa.gz.gzi");
}
else if(params.grch37primary){
  fasta=file("s3://deepvariant-data/genomes/GRCh37.dna.primary/Homo_sapiens.GRCh37.dna.primary_assembly.fa");
  fai=file("s3://deepvariant-data/genomes/GRCh37.dna.primary/Homo_sapiens.GRCh37.dna.primary_assembly.fa.fai");
  fastagz=file("s3://deepvariant-data/genomes/GRCh37.dna.primary/Homo_sapiens.GRCh37.dna.primary_assembly.fa.gz");
  gzfai=file("s3://deepvariant-data/genomes/GRCh37.dna.primary/Homo_sapiens.GRCh37.dna.primary_assembly.fa.gz.fai");
  gzi=file("s3://deepvariant-data/genomes/GRCh37.dna.primary/Homo_sapiens.GRCh37.dna.primary_assembly.fa.gz.gzi");
}
else if(params.hg19chr20 ){
  fasta=file("s3://deepvariant-data/genomes/hg19chr20/chr20.fa");
  fai=file("s3://deepvariant-data/genomes/hg19chr20/chr20.fa.fai");
  fastagz=file("s3://deepvariant-data/genomes/hg19chr20/chr20.fa.gz");
  gzfai=file("s3://deepvariant-data/genomes/hg19chr20/chr20.fa.gz.fai");
  gzi=file("s3://deepvariant-data/genomes/hg19chr20/chr20.fa.gz.gzi");
}
else if(params.hg19 ){
  fasta=file("s3://deepvariant-data/genomes/hg19/hg19.fa");
  fai=file("s3://deepvariant-data/genomes/hg19/hg19.fa.fai");
  fastagz=file("s3://deepvariant-data/genomes/hg19/hg19.fa.gz");
  gzfai=file("s3://deepvariant-data/genomes/hg19/hg19.fa.gz.fai");
  gzi=file("s3://deepvariant-data/genomes/hg19/hg19.fa.gz.gzi");
}

else{
  System.out.println(" --fasta \"/path/to/your/genome\"  params is required and was not found! ");
  System.out.println(" or you can use standard genome versions by typing --hg19 or --h38 ");
  System.exit(0);
}



/*--------------------------------------------------
  Bam related input files
---------------------------------------------------*/

params.getBai="false";

if(params.test){
    params.bam_folder="$baseDir/testdata"
}

assert (params.bam_folder != true) && (params.bam_folder != null) : "please specify --bam_folder option (--bam_folder bamfolder)"


params.bam_file_prefix="*"

if( !("false").equals(params.getBai)){
  Channel.fromFilePairs("${params.bam_folder}/${params.bam_file_prefix}*.{bam,bam.bai}").set{bamChannel}
}else{
  Channel.fromPath("${params.bam_folder}/${params.bam_file_prefix}*.bam").map{ file -> tuple(file.name, file) }.set{bamChannel}
}

/*--------------------------------------------------
  Output directory & email
---------------------------------------------------*/
params.outdir = "./results";
params.email = false

/*--------------------------------------------------
  Params for the Read Group Line to be added just in
  case its needed.
  If not given, default values are used.
---------------------------------------------------*/
params.rgid=4;
params.rglb="lib1";
params.rgpl="illumina";
params.rgpu="unit1";
params.rgsm=20;

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
summary['Bam folder']       = params.bam_folder
if(params.hg19) summary['Reference genome']           = "hg19"
if(params.h38) summary['Reference genome']            = "h38"
if(params.grch37primary) summary['Reference genome']  = "grch37primary"
if(params.hs37d5) summary['Reference genome']         = "hs37d5"
if(params.fasta != 'nofasta') summary['Fasta Ref']            = params.fasta
if(params.fai != 'nofai') summary['Fasta Index']              = params.fai
if(params.fastagz != 'nofastagz') summary['Fasta gzipped ']   = params.fastagz
if(params.gzfai != 'nogzfai') summary['Fasta gzipped Index']  = params.gzfai
if(params.gzi != 'nogzi') summary['Fasta bgzip Index']        = params.gzi
if(params.rgid != 4) summary['BAM Read Group ID']            = params.rgid
if(params.rglb != 'lib1') summary['BAM Read Group Library']         = params.rglb
if(params.rgpl != 'illumina') summary['BAM Read Group Platform']    = params.rgpl
if(params.rgpu != 'unit1') summary['BAM Read Group Platform Unit']  = params.rgpu
if(params.rgsm != 20) summary['BAM Read Group Sample']              = params.rgsm
summary['Max Memory']       = params.max_memory
summary['Max CPUs']         = params.max_cpus
summary['Max Time']         = params.max_time
summary['Number of cores for makeExamples'] = params.j
summary['DeepVariant trained data model folder'] = params.modelFolder
summary['DeepVariant trained data model name'] = params.modelName
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


process preprocessFASTA{

  publishDir "$baseDir/sampleDerivatives"


  input:
  file fasta from fasta
  file fai from fai
  file fastagz from fastagz
  file gzfai from gzfai
  file gzi from gzi
  output:
  set file(fasta),file("${fasta}.fai"),file("${fasta}.gz"),file("${fasta}.gz.fai"), file("${fasta}.gz.gzi") into fastaChannel
  script:
  """
  [[ "${params.fai}"=="nofai" ]] &&  samtools faidx $fasta || echo " fai file of user is used, not created"
  [[ "${params.fastagz}"=="nofastagz" ]]  && bgzip -c ${fasta} > ${fasta}.gz || echo "fasta.gz file of user is used, not created "
  [[ "${params.gzi}"=="nogzi" ]] && bgzip -c -i ${fasta} > ${fasta}.gz || echo "gzi file of user is used, not created"
  [[ "${params.gzfai}"=="nogzfai" ]] && samtools faidx "${fasta}.gz" || echo "gz.fai file of user is used, not created"
  """

}


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
  [[ `samtools view -H ${bam[0]} | grep '@RG' | wc -l`   > 0 ]] && { mv $bam ready;}|| { java -jar /picard.jar AddOrReplaceReadGroups \
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



fastaChannel.map{file -> tuple (1,file[0],file[1],file[2],file[3],file[4])}
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

if(params.bed){
  process makeExamples_with_bed{

      tag "${bam[1]}"
    cpus params.j

    input:
      set file(fasta), file(bam) from all_fa_bam
      file bedfile from bedfile
    output:
      set file("${fasta[1]}"),file("${fasta[1]}.fai"),file("${fasta[1]}.gz"),file("${fasta[1]}.gz.fai"), file("${fasta[1]}.gz.gzi"),val("${bam[1]}"), file("shardedExamples") into examples
    shell:
    '''
      mkdir shardedExamples
      time seq 0 !{numberShardsMinusOne} | \
      parallel --eta --halt 2 \
        python /opt/conda/pkgs/deepvariant-0.7.0-py27h5d9141f_0/share/deepvariant-0.7.0-0/binaries/DeepVariant/0.7.0/DeepVariant-0.7.0+cl-208818123/make_examples.zip \
        --mode calling \
        --ref !{fasta[1]}.gz\
        --reads !{bam[1]} \
        --examples shardedExamples/examples.tfrecord@!{params.j}.gz\
        --regions !{bedfile} \
        --task {}
    '''
  }
}
else{
  process makeExamples{

    tag "${bam[1]}"
    cpus params.j

    input:
      set file(fasta), file(bam) from all_fa_bam
    output:
      set file("${fasta[1]}"),file("${fasta[1]}.fai"),file("${fasta[1]}.gz"),file("${fasta[1]}.gz.fai"), file("${fasta[1]}.gz.gzi"),val("${bam[1]}"), file("shardedExamples") into examples
    shell:
    '''
      mkdir shardedExamples
      time seq 0 !{numberShardsMinusOne} | \
      parallel --eta --halt 2 \
        python /opt/conda/pkgs/deepvariant-0.7.0-py27h5d9141f_0/share/deepvariant-0.7.0-0/binaries/DeepVariant/0.7.0/DeepVariant-0.7.0+cl-208818123/make_examples.zip \
        --mode calling \
        --ref !{fasta[1]}.gz\
        --reads !{bam[1]} \
        --examples shardedExamples/examples.tfrecord@!{params.j}.gz\
        --task {}
    '''
  }
}
/********************************************************************
  process call_variants
  Doing the variant calling based on the ML trained model.
********************************************************************/



process call_variants{


  tag "${bam}"
  cpus params.j

  input:
  set file(fasta),file("${fasta}.fai"),file("${fasta}.gz"),file("${fasta}.gz.fai"), file("${fasta}.gz.gzi"),val(bam), file("shardedExamples") from examples
  file 'dv2/models' from model
  output:
  set file(fasta),file("${fasta}.fai"),file("${fasta}.gz"),file("${fasta}.gz.fai"), file("${fasta}.gz.gzi"), val(bam), file('call_variants_output.tfrecord') into called_variants
  script:
  """
  python /opt/conda/pkgs/deepvariant-0.7.0-py27h5d9141f_0/share/deepvariant-0.7.0-0/binaries/DeepVariant/0.7.0/DeepVariant-0.7.0+cl-208818123/call_variants.zip \
    --outfile call_variants_output.tfrecord \
    --examples shardedExamples/examples.tfrecord@${params.j}.gz \
    --checkpoint dv2/models/${params.modelName} \
    --num_readers ${params.j}
  """
}



/********************************************************************
  process call_variants
  Trasforming the variant calling output (tfrecord file) into a standard vcf file.
********************************************************************/

process postprocess_variants{


  tag "$bam"
  cpus params.j

  publishDir params.outdir, mode: 'copy'
  input:
  set file(fasta),file("${fasta}.fai"),file("${fasta}.gz"),file("${fasta}.gz.fai"), file("${fasta}.gz.gzi"), val(bam),file('call_variants_output.tfrecord') from called_variants
  output:
   set val(bam),file("${bam}.vcf") into postout
  script:
  """
    python /opt/conda/pkgs/deepvariant-0.7.0-py27h5d9141f_0/share/deepvariant-0.7.0-0/binaries/DeepVariant/0.7.0/DeepVariant-0.7.0+cl-208818123/postprocess_variants.zip \
    --ref "${fasta}.gz" \
    --infile call_variants_output.tfrecord \
    --outfile "${bam}.vcf"
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
