#! /usr/bin/env nextflow

println "\nI want to BLAST $params.query to $params.dbDir/$params.dbName using $params.threads CPUs and output it to $params.outDir/$params.outFileName"


def helpMessage() {
  log.info """
    Usage:
    The typical command for running the pipeline is as follows:
    nextflow run main.nf --query QUERY.fasta --dbDir "blastDatabaseDirectory" --dbName "blastPrefixName"

    Mandatory arguments:
      --query                        Query fasta file of sequences you wish to BLAST
      --dbDir                        BLAST database directory (full path required)
      --dbName                       Prefix name of the BLAST database

    Optional arguments:
    --outDir                       Output directory to place final BLAST output
    --outfmt                       Output format ['6']
    --options                      Additional options for BLAST command [-evalue 1e-3]
    --outFileName                  Prefix name for BLAST output [input.blastout]
    --threads                      Number of CPUs to use during blast job [16]
    --chunkSize                    Number of fasta records to use when splitting the query fasta file
    --app                          BLAST program to use [blastn;blastp,tblastn,blastx]
    --help                         This usage statement.
    """
}

// Show help message
if (params.help) {
  helpMessage()
  exit 0
}

Channel
  .fromPath(params.query)
  .splitFasta(by: params.chunkSize, file:true)
  .set { queryFile_ch }

// This channel will grab the folder path and set it into a channel named dbDir_ch
Channel.fromPath(params.dbDir)
  .set { dbDir_ch }

// this channel will grab the text from params.dbName.  Notice it is just from and not fromPath.  nextflow will complain if you try to grab a path from a bit of text.
Channel.from(params.dbName)
  .set { dbName_ch }

process runBlast {
  container = 'ncbi/blast'
  publishDir "${params.outDir}/blastout"

  input:
  path(queryFile) from queryFile_ch
  path(dbDir) from dbDir_ch.val
  val(dbName) from dbName_ch.val

  output:
  publishDir "${params.outDir}/blastout"
  path(params.outFileName) into blast_output_ch


// the script section requires that we change the $params.dbDir and $params.dbName to correspond to the input from channel which we have aptly named dbDir and dbName.  Since they are inside triple quotes we need to include the dollar sign
  script:
  """
  ${params.app} -num_threads ${params.threads} -db ${dbDir}/${dbName} -query ${queryFile} -outfmt ${params.outfmt} ${params.options} -out ${params.outFileName}
  """
}

blast_output_ch
  .collectFile(name: 'blast_output_combined.txt', storeDir: params.outDir)