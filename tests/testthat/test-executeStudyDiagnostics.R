library(testthat)
testthat::test_that("Testing verify dependencies", {
  folder <- tempfile()
  dir.create(folder, recursive = TRUE)
  
  expect_error({StudyDiagnostics::executeStudyDiagnostics(
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = "main",
    vocabularyDatabaseSchema = "main",
    cohortDatabaseSchema = "main",
    cohortTable = "c",
    outputFolder = folder
  )})

  unlink(x = folder, recursive = TRUE, force = TRUE)
})
