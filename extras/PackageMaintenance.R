# Create manual -----------------------------------------------------------------------------
shell("rm extras/StudyDiagnostics.pdf")
shell("R CMD Rd2pdf ./ --output=extras/StudyDiagnostics.pdf")

