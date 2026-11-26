# ==============================================================================
# Program : create_visualizations.R
# Purpose : AE visualisations with {ggplot2}
#           Plot 1 - AE severity distribution by treatment (AESEV x ACTARM)
#           Plot 2 - Top 10 most frequent AEs (AETERM) with 95% CI
# Input   : pharmaverseadam::adae, pharmaverseadam::adsl
# Output  : question_3_tlg/output/plot1_ae_severity_by_treatment.png
#           question_3_tlg/output/plot2_top10_ae_incidence_ci.png
# Log     : question_3_tlg/logs/02_create_visualizations.log  (written by this script)
# Author  : NHM
# Date    : 25-11-2026
# ==============================================================================

# ---- 0. Setup ----------------------------------------------------------------
library(pharmaverseadam)
library(dplyr)
library(ggplot2)
library(scales)

out_dir <- "question_3_tlg/output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Logging: capture console output as evidence the script runs error-free -
log_dir  <- "question_3_tlg/logs"
log_file <- file.path(log_dir, "02_create_visualizations.log")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
log_con  <- file(log_file, open = "wt")
sink(log_con, split = TRUE)       # stdout -> console + log
sink(log_con, type = "message")   # messages/warnings -> log

# ---- 1. Read data ------------------------------------------------------------
adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae %>%
  mutate(ACTARM = factor(ACTARM, 
                         levels = c("Placebo", 
                                    "Xanomeline Low Dose", 
                                    "Xanomeline High Dose")))

# ---- 2. Plot 1: AE severity distribution by treatment -----------------------
sev_data <- adae %>%
  count(ACTARM, AESEV) %>%
  mutate(AESEV = factor(AESEV, levels = c("MILD", "MODERATE", "SEVERE")))

p1 <- ggplot(sev_data, aes(x = ACTARM, y = n, fill = AESEV)) +
  geom_col(position = position_stack(reverse = TRUE)) +
  scale_x_discrete(
    labels = function(x) sub(" (Low|High)", "\n\\1", x)
  ) + # linebreaks for better distinction between treatments
  scale_fill_manual(
    values = c(
      "MILD"     = "#2B8CBE", 
      "MODERATE" = "#FDB863",  
      "SEVERE"   = "#D7301F"   
    )
  ) +
  labs(title = "AE severity distribution by treatment",
       x = "Treatment Arm", y = "Count of AEs", fill = "Severity") +
  theme_minimal()

ggsave(file.path(out_dir, "plot1_ae_severity_by_treatment.png"),
       p1, width = 8, height = 6, dpi = 300)

# ---- 3. Plot 2: Top 10 most frequent AEs with 95% CI ------------------------
#   - N = number of subjects (denominator, e.g. all ADSL subjects or safety population)
#   - n = number of unique subjects with each AETERM
#   - incidence = n / N, 95% CI with Clopper-Pearson (binom.test) or Wilson
#   - keep the top 10 by n and order the axis by incidence
n_total <- adae %>%
  distinct(USUBJID, AETERM) %>%
  summarise(n_subjects = n_distinct(USUBJID)) %>%
  pull()
top10 <- adae %>%
  distinct(USUBJID, AETERM) %>%
  count(AETERM, name = "n") %>%
  slice_max(n, n = 10, with_ties = FALSE) %>%
  rowwise() %>%
  mutate(
    pct   = n / n_total,
    lower = binom.test(n, n_total)$conf.int[1],
    upper = binom.test(n, n_total)$conf.int[2]
  ) %>%
  ungroup()

p2 <- ggplot(top10, aes(x = pct*100, y = reorder(AETERM, pct))) +
  geom_errorbar(aes(xmin = lower*100, xmax = upper*100), height = 0.4, orientation = "y") +
  geom_point(size = 3, color = "#1B4F72") +
  geom_text(aes(x = 2, label = sprintf("%.1f%%", pct*100)), size = 3) +
  scale_x_continuous(labels = label_percent(scale = 1)) +
  labs(title = "Top 10 Most Frequent Adverse Events",
       subtitle = paste0("n = ", n_total, " subjects; 95% Clopper-Pearson CIs"),
       x = "Percentage of Patients (%)", y = NULL) +
  theme_minimal()

ggsave(file.path(out_dir, "plot2_top10_ae_incidence_ci.png"),
       p2, width = 8, height = 6, dpi = 300)

sessionInfo()

# ---- Close log ----------------------------------------------------------------
sink(type = "message")
sink()
close(log_con)
