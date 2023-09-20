# *******************************************************
# -----------------INSTRUCTIONS -------------------------
# *******************************************************
#
# This CodeToRun.R is provided as an example of how to run this study package.
# 
# Below you will find 3 sections: the 1st is for installing the study package and its dependencies, 
# the 2nd for running the package, the 3rd is for sharing the results with the study coordinator.
#
# In section 2 below, you will also need to update the code to use your site specific values. Please scroll
# down for specific instructions.
#
# 
# *******************************************************
# SECTION 1: Installing 
# *******************************************************
# 
# 1. See the instructions at https://ohdsi.github.io/Hades/rSetup.html for configuring your R environment, including Java and RStudio.
#
# 2. In RStudio, create a new project: File -> New Project... -> New Directory -> New Project. If asked if you want to use `renv` with the project, answer ‘no’.
#
# 3. Execute the following R code:

# Install the latest version of renv:
install.packages("renv")

# Download the lock file:
download.file("https://raw.githubusercontent.com/darwin-eu-dev/StudyDiagnostics/main/renv.lock", "renv.lock")

# Build the local library.
renv::init()
# Restore the library from the lockfile:
renv::restore()

# *******************************************************
# SECTION 2: Running the package -------------------------------------------------------------------------------
# *******************************************************
#
# Edit the variables below to the correct values for your environment:

library(StudyDiagnostics)

# Maximum number of cores to be used:
maxCores <- parallel::detectCores()

# Details for connecting to the server. See 
# http://ohdsi.github.io/DatabaseConnector/reference/createConnectionDetails.html for more details:
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "...",
                                                                server = "...",
                                                                user = "...",
                                                                password = "...",
                                                                port = 5432)

# For Oracle and BigQuery: define a schema that can be used to emulate temp tables. 
# You should have write access to this schema:
oracleTempSchema <- NULL

# A folder on the local file system to store results:
outputFolder <- "..."

# The database schema where the observational data in CDM is located. For SQL Server
# this should include both the database and schema, for example 'cdm.dbo'.
# You should have read access to this schema:
cdmDatabaseSchema <- "..."

# The database schema where the cohorts can be instantiated. For SQL Server
# this should include both the database and schema, for example 'cdm.dbo'.
# You should have write access to this schema:
cohortDatabaseSchema <- "..."

# The name of the table that will be created in the cohortDatabaseSchema:
cohortTable <- "..."

# Some meta-data about your database. The databaseId is a short (<= 20 characters)
# name for your database. The databaseName is the full name, and databaseDescription 
# provides a short (1 paragraph) description. These values will be displayed in the 
# Shiny results app for all to see.
databaseId <- "..."
databaseName <- "..."
databaseDescription <- "..." 

# This statement instatiates the cohorts, performs the diagnostics, and writes the results to
# a zip file containing CSV files. This will probaby take a long time to run:
StudyDiagnostics::executeStudyDiagnostics(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  vocabularyDatabaseSchema = cdmDatabaseSchema,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable = cohortTable,
  oracleTempSchema = oracleTempSchema,
  verifyDependencies = TRUE,
  outputFolde = outputFolderr,
  cohortIds = NULL,
  incrementalFolder = file.path(outputFolder, "incrementalFolder"),
  databaseId = databaseId,
  databaseName = databaseName,
  databaseDescription = databaseDescription
)

# (Optionally) to view the results locally:
CohortDiagnostics::createMergedResultsFile(
  dataFolder = file.path(outputFolder, "diagnosticsExport"),
  sqliteDbPath = file.path(outputFolder, "MergedCohortDiagnosticsData.sqlite")
)
CohortDiagnostics::launchDiagnosticsExplorer(sqliteDbPath = file.path(outputFolder, "MergedCohortDiagnosticsData.sqlite"))

# *******************************************************
# SECTION 3: Sharing the results -------------------------------------------------------------------------------
# *******************************************************
#
# Upload results to the DTZ.

# Please send the study-coordinator an e-mail when done.
