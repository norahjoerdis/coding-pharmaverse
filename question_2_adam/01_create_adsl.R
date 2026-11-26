# ==============================================================================
# Program : create_adsl.R
# Purpose : Create the ADaM Subject-Level dataset (ADSL) with {admiral}
# Input   : pharmaversesdtm::dm, vs, ex, ds, ae
# Output  : question_2_adam/output/adsl.(rds|csv|xpt)
# Log     : question_2_adam/logs/question_2.log  (written by this script)
# Author  : NHM
# Date    : 24-11-2026
# Notes   : Based on https://pharmaverse.github.io/admiral/cran-release/articles/adsl.html
#           Extra variables: AGEGR9/AGEGR9N, TRTSDTM/TRTSTMF, ITTFL, LSTAVLDT
# ==============================================================================

# ---- 0. Setup ----------------------------------------------------------------
library(admiral)
library(pharmaversesdtm)
library(dplyr)
library(lubridate)
library(stringr)

out_dir <- "question_2_adam/output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Logging: capture console output as evidence the script runs error-free -
log_dir  <- "question_2_adam/logs"
log_file <- file.path(log_dir, "question_2.log")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
log_con  <- file(log_file, open = "wt")
sink(log_con, split = TRUE)       # stdout -> console + log
sink(log_con, type = "message")   # messages/warnings -> log

# ---- 1. Read SDTM data -------------------------------------------------------
dm <- pharmaversesdtm::dm
vs <- pharmaversesdtm::vs
ex <- pharmaversesdtm::ex
ds <- pharmaversesdtm::ds
ae <- pharmaversesdtm::ae

# Convert SAS-style blanks ("") to NA
dm <- convert_blanks_to_na(dm)
vs <- convert_blanks_to_na(vs)
ex <- convert_blanks_to_na(ex)
ds <- convert_blanks_to_na(ds)
ae <- convert_blanks_to_na(ae)

# ---- 2. Start ADSL from DM ---------------------------------------------------
adsl <- dm %>%
  select(-DOMAIN)

# ---- 3. AGEGR9 / AGEGR9N -----------------------------------------------------

adsl <- adsl %>%
  mutate(
    AGEGR1 = case_when(
      AGE < 18 ~ "<18",
      between(AGE, 18, 50) ~ "18-50",
      AGE > 50 ~ ">50",
      TRUE ~ NA_character_
    ),
    AGEGR1N = case_when(
      AGE < 18 ~ 1,
      between(AGE, 18, 50) ~ 2,
      AGE > 50 ~ 3,
      TRUE ~ NA_real_
    )
  )

# ---- 4. TRTSDTM / TRTSTMF ----------------------------------------------------

# create helper dataframe which holds the first/last exposure observation
ex_ext <- ex %>%
  filter(EXDOSE > 0 | (EXDOSE == 0 & str_detect(str_to_upper(EXTRT), "PLACEBO"))) %>%
  derive_vars_dtm(
    dtc = EXSTDTC,
    new_vars_prefix = "EXST",
    time_imputation = "first",
    ignore_seconds_flag = TRUE
  ) %>%
  derive_vars_dtm(
    dtc = EXENDTC,
    new_vars_prefix = "EXEN",
    time_imputation = "last",
    ignore_seconds_flag = TRUE
  )

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = !is.na(EXENDTM),
    new_vars = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF),
    order = exprs(EXENDTM, EXSEQ),
    mode = "last",
    by_vars = exprs(STUDYID, USUBJID)
  )

# ---- 5. ITTFL ----------------------------------------------------------------

adsl <- adsl %>%
  mutate(ITTFL = if_else(!is.na(ARM), "Y", "N"))

# ---- 6. LSTAVLDT -------------------------------------------------------------
# Spec: max of
#   (1) last complete VS date with a valid result
#       (VSSTRESN and VSSTRESC not both missing) and VSDTC date part not missing
#   (2) last complete AE onset date (AESTDTC date part)
#   (3) last complete disposition date (DSSTDTC date part)
#   (4) last valid-dose treatment date (ADSL.TRTEDTM date part)

adsl <- adsl %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      event( # last complete VS date with valid result
        dataset_name = "vs",
        order = exprs(VSDTC, VSSEQ),
        condition = (!is.na(VSSTRESN) | !is.na(VSSTRESC)) & !is.na(convert_dtc_to_dt(VSDTC)),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(VSDTC, highest_imputation = "n"),
          seq = VSSEQ
        ),
      ),
      event( # last complete AE onset date (AESTDTC)
        dataset_name = "ae",
        order = exprs(AESTDTC, AESEQ),
        condition = !is.na(convert_dtc_to_dt(AESTDTC)),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(AESTDTC),
          seq = AESEQ
        ),
      ),
      event( # last complete disposition date (DSSTDTC)
        dataset_name = "ds",
        order = exprs(DSSTDTC, DSSEQ),
        condition = !is.na(convert_dtc_to_dt(DSSTDTC)),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(DSSTDTC),
          seq = DSSEQ
        )
      ),
      event( # last valid dose treatment date (TRTEDTM)
        dataset_name = "adsl",
        condition = !is.na(TRTEDTM),
        set_values_to = exprs(
          LSTALVDT = lubridate::date(TRTEDTM),
          seq = 0
        )
      )
    ),
    source_datasets = list(vs = vs, ae = ae, ds = ds, adsl = adsl),
    tmp_event_nr_var = event_nr,
    order = exprs(LSTALVDT, seq, event_nr),
    mode = "last",
    new_vars = exprs(LSTALVDT)
  )

# ---- 7. Save -----------------------------------------------------------------
saveRDS(adsl, file.path(out_dir, "adsl.rds"))
write.csv(adsl, file.path(out_dir, "adsl.csv"), row.names = FALSE, na = "")

sessionInfo()

# ---- Close log ----------------------------------------------------------------
sink(type = "message")
sink()
close(log_con)
