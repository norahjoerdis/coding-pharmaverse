# ==============================================================================
# Program : create_ae_summary_table.R
# Purpose : Summary table of treatment-emergent adverse events (TEAEs)
#           (FDA Table 10 style) with {gtsummary}
# Input   : pharmaverseadam::adae, pharmaverseadam::adsl
# Output  : question_3_tlg/output/ae_summary_table.html
# Log     : question_3_tlg/logs/01_create_ae_summary_table.log  (written by this script)
# Author  : NHM
# Date    : 25-11-2026
# ==============================================================================

# ---- 0. Setup ----------------------------------------------------------------
library(pharmaverseadam)
library(dplyr)
library(gtsummary)
library(gt)

out_dir <- "question_3_tlg/output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Logging: capture console output as evidence the script runs error-free -
log_dir  <- "question_3_tlg/logs"
log_file <- file.path(log_dir, "01_create_ae_summary_table.log")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
log_con  <- file(log_file, open = "wt")
sink(log_con, split = TRUE)       # stdout -> console + log
sink(log_con, type = "message")   # messages/warnings -> log

# ---- 1. Read data ------------------------------------------------------------
# unique(adsl$ACTARM) # unique(adae$ACTARM)
arm_levels = c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")

# ensuring that the later table columns are sorted by dosage
adsl <- pharmaverseadam::adsl %>%
  mutate(ACTARM = factor(ACTARM, levels = c(arm_levels, "Screen Failure")))
adae <- pharmaverseadam::adae %>%
  mutate(ACTARM = factor(ACTARM, levels = arm_levels))

# ---- 2. Prepare analysis data -----------------------------------------------
teae <- adae %>% 
  filter(TRTEMFL == "Y") %>% # Treatment-emergent AE
  tbl_hierarchical(
    variables = c(AESOC, AETERM),
    by = ACTARM,
    id = USUBJID,
    denominator = adsl,
    overall_row = TRUE,
    label = "..ard_hierarchical_overall.." ~ "Treatment-emergent AEs"
  ) %>%
  add_overall(last = TRUE) %>%
  sort_hierarchical()

# ---- 3. Save -----------------------------------------------------------------
teae %>%
  as_gt() %>%
  gt::gtsave(file.path(out_dir, "ae_summary_table.html"))

sessionInfo()

# ---- Close log ----------------------------------------------------------------
sink(type = "message")
sink()
close(log_con)
