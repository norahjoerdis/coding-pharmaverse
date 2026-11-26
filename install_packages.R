# ------------------------------------------------------------------------------
# install_packages.R
# Installs the R packages used in this repository (run once, locally or on
# Posit Cloud).
# ------------------------------------------------------------------------------

# Set a CRAN mirror so the script also works non-interactively (Rscript)
repos <- getOption("repos")
if (is.null(repos) || !"CRAN" %in% names(repos) || repos[["CRAN"]] == "@CRAN@") {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
}

# Helpers for the VS Code R extension (language server, session watcher)
dev_pkgs <- c("languageserver", "jsonlite", "rlang")

pkgs <- c(
  # Pharmaverse
  "sdtm.oak", "admiral", "pharmaverseraw", "pharmaversesdtm", "pharmaverseadam",
  # Tidyverse / utilities
  "dplyr", "tidyr", "stringr", "lubridate", "readr",
  # Reporting
  "gtsummary", "gt", "ggplot2", "scales",
  # Export
  "haven"
)

pkgs <- c(pkgs, dev_pkgs)

missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing) > 0) install.packages(missing)

invisible(lapply(pkgs, packageVersion))
message("All packages available.")
