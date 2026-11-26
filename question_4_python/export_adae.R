# ==============================================================================
# Program : export_adae.R
# Purpose : Export pharmaversesdtm::ae to CSV as the input for Question 4
# Output  : question_4_python/data/adae.csv
# Log     : question_4_python/logs/export_adae.log  (written by this script)
# ==============================================================================

library(pharmaversesdtm)

out_dir <- "question_4_python/data"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Logging: capture console output as evidence the script runs error-free -
log_dir  <- "question_4_python/logs"
log_file <- file.path(log_dir, "export_adae.log")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
log_con  <- file(log_file, open = "wt")
sink(log_con, split = TRUE)       # stdout -> console + log
sink(log_con, type = "message")   # messages/warnings -> log

write.csv(pharmaversesdtm::ae, file.path(out_dir, "adae.csv"),
          row.names = FALSE, na = "")

message("Wrote ", nrow(pharmaversesdtm::ae), " rows to ", file.path(out_dir, "adae.csv"))

sessionInfo()

# ---- Close log ----------------------------------------------------------------
sink(type = "message")
sink()
close(log_con)
