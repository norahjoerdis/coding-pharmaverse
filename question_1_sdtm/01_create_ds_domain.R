# ==============================================================================
# Program : create_ds_domain.R
# Purpose : Create the SDTM Disposition (DS) domain from raw data with {sdtm.oak}
# Input   : pharmaverseraw::ds_raw
#           Study controlled terminology (study_ct)
#           eCRF mock-up and programming details (see "General Notes")
# Output  : question_1_sdtm/output/ds.(rds|csv|xpt)
# Log     : question_1_sdtm/logs/01_create_ds_domain.log  (written by this script)
# Author  : NHM
# Date    : 24-11-2026
# Notes   : Based on the AE example at https://pharmaverse.github.io/examples/
#           Reference: SDTMIG v3.4, DS domain
# ==============================================================================

# ---- 0. Setup ----------------------------------------------------------------
# use library() instead of require() so that the script stops here if not available
library(sdtm.oak)
library(pharmaverseraw)
library(pharmaversesdtm)   # dm needed for DSSTDY (RFSTDTC)
library(dplyr)

out_dir <- "question_1_sdtm/output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Logging: capture console output as evidence the script runs error-free -
# sink() must be opened here (before any output is produced) so the log file
# contains the full run. It is closed again at the very end of the script.
log_dir  <- "question_1_sdtm/logs"
log_file <- file.path(log_dir, "01_create_ds_domain.log")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
log_con  <- file(log_file, open = "wt")
sink(log_con, split = TRUE)       # stdout -> console + log
sink(log_con, type = "message")   # messages/warnings -> log

# ---- 1. Read raw data --------------------------------------------------------
ds_raw <- pharmaverseraw::ds_raw
dm     <- pharmaversesdtm::dm

# Check how the dataframe looks like
# View(ds_raw) 
# colnames(ds_raw)

# ---- 2. Study controlled terminology ----------------------------------------
# Option A: read study CT from the pharmaverse examples repo.
# Option B: if the URL cannot be reached, use the fallback copied from instructions.pdf.
study_ct <- tryCatch(
  read.csv(
    "https://raw.githubusercontent.com/pharmaverse/examples/main/metadata/sdtm_ct.csv",
    stringsAsFactors = FALSE
  ),
  error = function(e) {
    message("Could not download study CT, using inline fallback: ", conditionMessage(e))
    data.frame(
      stringsAsFactors = FALSE,
      codelist_code = rep("C66727", 10),
      term_code = c("C41331", "C25250", "C28554", "C48226", "C48227",
                    "C48250", "C142185", "C49628", "C49632", "C49634"),
      term_value = c("ADVERSE EVENT", "COMPLETED", "DEATH", "LACK OF EFFICACY",
                     "LOST TO FOLLOW-UP", "PHYSICIAN DECISION", "PROTOCOL VIOLATION",
                     "SCREEN FAILURE", "STUDY TERMINATED BY SPONSOR",
                     "WITHDRAWAL BY SUBJECT"),
      collected_value = c("Adverse Event", "Complete", "Dead", "Lack of Efficacy",
                          "Lost To Follow-Up", "Physician Decision",
                          "Protocol Violation", "Trial Screen Failure",
                          "Study Terminated By Sponsor", "Withdrawal by Subject"),
      term_preferred_term = c("AE", "Completed", "Died", NA, NA, NA, "Violation",
                              "Failure to Meet Inclusion/Exclusion Criteria", NA,
                              "Dropout"),
      term_synonyms = c("ADVERSE EVENT", "COMPLETE", "Death", NA, NA, NA, NA, NA,
                        NA, "Discontinued Participation")
    )
  }
)

# ---- 3. Create oak_id_vars ---------------------------------------------------
ds_raw <- ds_raw %>%
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
    )

# ---- 4. Map topic variable (DSTERM) -----------------------------------------
ds <- assign_no_ct(
  raw_dat = ds_raw, 
  raw_var = "IT.DSTERM", 
  tgt_var = "DSTERM",
  id_vars = oak_id_vars()
  )

# ---- 5. Map qualifiers --------------------------------------------------------
# VISITNUM, VISIT (transfer mappings)
# DSCAT, DSDECOD, DSTERM (logical mappings)

ds <- ds %>%
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISITNUM",
    ct_spec = study_ct,
    ct_clst = "VISITNUM",
    id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISIT",
    ct_spec = study_ct,
    ct_clst = "VISIT",
    id_vars = oak_id_vars()
  ) %>%
  hardcode_ct(
    raw_dat = condition_add(ds_raw, IT.DSDECOD == "Randomized"),
    tgt_val = "PROTOCOL MILESTONE",
    raw_var = "IT.DSDECOD",
    tgt_var = "DSCAT",
    ct_spec = study_ct,
    ct_clst = "C74558",     
    id_vars = oak_id_vars()
  ) %>%
  hardcode_ct(
    raw_dat = condition_add(ds_raw, IT.DSDECOD != "Randomized" | is.na(IT.DSDECOD)),
    tgt_val = "DISPOSITION EVENT",
    raw_var = "IT.DSDECOD",
    tgt_var = "DSCAT",
    ct_spec = study_ct,
    ct_clst = "C74558",        
    id_vars = oak_id_vars()
  ) %>%
  hardcode_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP)),
    tgt_val = "OTHER EVENT",
    raw_var = "OTHERSP",
    tgt_var = "DSCAT",
    ct_spec = study_ct,
    ct_clst = "C74558",        
    id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP)),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSDECOD",
    ct_spec = study_ct,
    ct_clst = "C66727",
    id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP)),
    raw_var = "OTHERSP",
    tgt_var = "DSDECOD",
    ct_spec = study_ct,
    ct_clst = "C66727",
    id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP)),
    raw_var = "IT.DSTERM",
    tgt_var = "DSTERM",
    ct_spec = study_ct,
    ct_clst = "C66727",
    id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP)),
    raw_var = "OTHERSP",
    tgt_var = "DSTERM",
    ct_spec = study_ct,
    ct_clst = "C66727",
    id_vars = oak_id_vars()
  ) 

# ---- 6. Map timing variables -------------------------------------------------
# DSDTC collection date, DSSTDTC - start date of the disposition event

ds <- ds %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSTDAT", # assumed typo in PDF? "IT.DSSDAT" not in ds_raw
    tgt_var = "DSSTDTC",
    raw_fmt = c("mm-dd-yyyy"),
    id_vars = oak_id_vars()
  ) %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = c("DSDTCOL", "DSTMCOL"),
    tgt_var = "DSDTC",
    raw_fmt = c("mm-dd-yyyy", "HH:MM"), # what if is.na(DSTMCOL) ?
    raw_unk = c("UN", "UNK"),
    id_vars = oak_id_vars()
  )

# ---- 7. Derive standard SDTM variables --------------------------------------
ds <- ds %>%
  dplyr::mutate(
    STUDYID = ds_raw$STUDY,
    DOMAIN  = "DS",
    USUBJID = paste0("01-", ds_raw$PATNUM) # in line with AE example
  ) %>%
  derive_seq(
    tgt_var = "DSSEQ", 
    rec_vars = c("USUBJID", "DSSTDTC", "DSTERM")) %>%
  derive_study_day(
    sdtm_in = ., 
    dm_domain = dm, 
    tgdt = "DSSTDTC",
    refdt = "RFSTDTC", 
    study_day_var = "DSSTDY"
  )

# ---- 8. Final variable selection and order ----------------------------------
ds <- ds %>% 
  select("STUDYID", "DOMAIN", "USUBJID", "DSSEQ", "DSTERM", "DSDECOD",
         "DSCAT", "VISITNUM", "VISIT", "DSDTC", "DSSTDTC", "DSSTDY") %>% 
  arrange(USUBJID, DSSEQ)

# ---- 9. Save ----------------------------------------------------------------
saveRDS(ds, file.path(out_dir, "ds.rds"))
write.csv(ds, file.path(out_dir, "ds.csv"), row.names = FALSE, na = "")

sessionInfo()

# ---- Close log ----------------------------------------------------------------
sink(type = "message")
sink()
close(log_con)
