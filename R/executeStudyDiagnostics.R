# Copyright 2023 DARWIN EU®
#
# This file is part of StudyDiagnostics
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Execute the cohort diagnostics
#'
#' @details
#' This function executes the cohort diagnostics.
#'
#' @param connectionDetails                   An object of type \code{connectionDetails} as created
#'                                            using the
#'                                            \code{\link[DatabaseConnector]{createConnectionDetails}}
#'                                            function in the DatabaseConnector package.
#' @param cdmDatabaseSchema                   Schema name where your patient-level data in OMOP CDM
#'                                            format resides. Note that for SQL Server, this should
#'                                            include both the database and schema name, for example
#'                                            'cdm_data.dbo'.
#' @param cohortDatabaseSchema                Schema name where intermediate data can be stored. You
#'                                            will need to have write privileges in this schema. Note
#'                                            that for SQL Server, this should include both the
#'                                            database and schema name, for example 'cdm_data.dbo'.
#' @param cohortsFolder                       Name of local folder where cohorts are located; make 
#'                                            sure to use forward slashes (/). Preferably, do not use a 
#'                                            folder on a network drive since this greatly impacts 
#'                                            performance.
#' @param vocabularyDatabaseSchema            Schema name where your OMOP vocabulary data resides. This
#'                                            is commonly the same as cdmDatabaseSchema. Note that for
#'                                            SQL Server, this should include both the database and
#'                                            schema name, for example 'vocabulary.dbo'.
#' @param cohortTable                         The name of the table that will be created in the work
#'                                            database schema. This table will hold the exposure and
#'                                            outcome cohorts used in this study.
#' @param tempEmulationSchema                 Some database platforms like Oracle and Impala do not
#'                                            truly support temp tables. To emulate temp tables,
#'                                            provide a schema with write privileges where temp tables
#'                                            can be created.
#' @param verifyDependencies                  Check whether correct package versions are installed?
#' @param outputFolder                        Name of local folder to place results; make sure to use
#'                                            forward slashes (/). Do not use a folder on a network
#'                                            drive since this greatly impacts performance.
#' @param databaseId                          A short string for identifying the database (e.g.
#'                                            'Synpuf').
#' @param cohortIds                           An optional parameter to filter the cohortIds in OHDSI Phenotype library to run.
#'                                            By Default all cohorts will be run.
#' @param databaseName                        The full name of the database (e.g. 'Medicare Claims
#'                                            Synthetic Public Use Files (SynPUFs)').
#' @param databaseDescription                 A short description (several sentences) of the database.
#' @param incrementalFolder                   Name of local folder to hold the logs for incremental
#'                                            run; make sure to use forward slashes (/). Do not use a
#'                                            folder on a network drive since this greatly impacts
#'                                            performance.
#' @param extraLog                            Do you want to add anything extra into the log?
#'
#' @export
executeStudyDiagnostics <- function(connectionDetails,
                                    cdmDatabaseSchema,
                                    vocabularyDatabaseSchema = cdmDatabaseSchema,
                                    cohortDatabaseSchema = cdmDatabaseSchema,
                                    cohortsFolder = cohortsFolder,
                                    cohortTable = "cohort",
                                    tempEmulationSchema = getOption("sqlRenderTempEmulationSchema"),
                                    verifyDependencies = TRUE,
                                    cohortIds = NULL,
                                    exportFolder = exportFolder,
                                    incrementalFolder = file.path(outputFolder, "incrementalFolder"),
                                    databaseId = databaseId,
                                    databaseName = databaseId,
                                    databaseDescription = databaseId,
                                    extraLog = NULL,
                                    incremental = FALSE) {

  if (!file.exists(outputFolder)) {
    dir.create(outputFolder, recursive = TRUE)
  }

  ParallelLogger::addDefaultFileLogger(file.path(outputFolder, "log.txt"))
  ParallelLogger::addDefaultErrorReportLogger(file.path(outputFolder, "errorReportR.txt"))
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_FILE_LOGGER", silent = TRUE))
  on.exit(
    ParallelLogger::unregisterLogger("DEFAULT_ERRORREPORT_LOGGER", silent = TRUE),
    add = TRUE
  )

  if (verifyDependencies) {
    ParallelLogger::logInfo("Checking whether correct package versions are installed")
    verifyDependencies()
  }

  if (!is.null(extraLog)) {
    ParallelLogger::logInfo(extraLog)
  }

  ParallelLogger::logInfo("Creating cohorts")

  cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = cohortTable)

  # Next create the tables on the database
  CohortGenerator::createCohortTables(
    connectionDetails = connectionDetails,
    cohortTableNames = cohortTableNames,
    cohortDatabaseSchema = cohortDatabaseSchema,
    incremental = incremental
  )

  # get cohort definitions from study package
  cohortDefinitionSet <- CohortGenerator::createEmptyCohortDefinitionSet()
  
  # Filling the cohort
  cohortJsonFiles <- list.files(path = cohortsFolder, full.names = TRUE)
  for (i in 1:length(cohortJsonFiles)) {
    cohortJsonFileName <- cohortJsonFiles[i]
    cohortName <- tools::file_path_sans_ext(basename(cohortJsonFileName))
    cohortJson <- readChar(cohortJsonFileName, file.info(cohortJsonFileName)$size)
    cohortExpression <- CirceR::cohortExpressionFromJson(cohortJson)
    cohortSql <- CirceR::buildCohortQuery(cohortExpression, options = CirceR::createGenerateOptions(generateStats = FALSE))
    cohortDefinitionSet <- rbind(cohortDefinitionSet, data.frame(cohortId = as.double(i),
                                                                 cohortName = cohortName,
                                                                 json = cohortJson,
                                                                 sql = cohortSql,
                                                                 stringsAsFactors = FALSE))
  }

  if (!is.null(cohortIds)) {
    cohortDefinitionSet <- cohortDefinitionSet %>%
      dplyr::filter(cohortDefinitionSet$cohortId %in% c(cohortIds))
  }

  # Generate the cohort set
  CohortGenerator::generateCohortSet(
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTableNames = cohortTableNames,
    cohortDefinitionSet = cohortDefinitionSet,
    incrementalFolder = incrementalFolder,
    incremental = incremental
  )

  # export stats table to local
  CohortGenerator::exportCohortStatsTables(
    connectionDetails = connectionDetails,
    connection = NULL,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTableNames = cohortTableNames,
    cohortStatisticsFolder = outputFolder,
    incremental = incremental
  )

  # run cohort diagnostics
  CohortDiagnostics::executeDiagnostics(
    cohortDefinitionSet = cohortDefinitionSet,
    exportFolder = exportFolder,
    databaseId = databaseId,
    cohortDatabaseSchema = cohortDatabaseSchema,
    databaseName = databaseName,
    databaseDescription = databaseDescription,
    connectionDetails = connectionDetails,
    connection = NULL,
    cdmDatabaseSchema = cdmDatabaseSchema,
    tempEmulationSchema = getOption("sqlRenderTempEmulationSchema"),
    cohortTable = "cohort",
    cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTable),
    conceptCountsTable = "#concept_counts",
    vocabularyDatabaseSchema = cdmDatabaseSchema,
    cohortIds = NULL,
    cdmVersion = 5,
    runInclusionStatistics = TRUE,
    runIncludedSourceConcepts = TRUE,
    runOrphanConcepts = TRUE,
    runTimeSeries = TRUE,
    runVisitContext = FALSE,
    runBreakdownIndexEvents = TRUE,
    runIncidenceRate = FALSE,
    runCohortRelationship = TRUE,
    runTemporalCohortCharacterization = TRUE,
    temporalCovariateSettings = getDefaultCovariateSettings(),
    minCellCount = 5,
    minCharacterizationMean = 0.01,
    irWashoutPeriod = 0,
    incremental = FALSE,
    incrementalFolder = file.path(exportFolder, "incremental"),
    useExternalConceptCountsTable = FALSE
  )
}
