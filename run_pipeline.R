# =============================================================================
# qc/run_pipeline.R
#
# Part A of the code verification protocol: a trustworthy run.
#
# Runs an analysis pipeline end to end, each script in its own R process, in a
# directory that starts empty, with warnings made loud. Records what ran, in
# what environment, how long it took, what it produced, and every warning and
# error, so that the numbers a manuscript reports can be tied to a documented
# execution rather than to someone's session.
#
# This is a general-purpose harness. It assumes only that your pipeline is a
# set of R scripts run in a fixed order. Everything project-specific is in the
# CONFIGURATION block below; nothing further down should need changing.
#
# -----------------------------------------------------------------------------
# ADAPTING THIS TO YOUR PROJECT
# -----------------------------------------------------------------------------
#
# 1. Decide your layout. This script assumes a project root containing a code
#    folder and a results folder, side by side:
#
#        project_root/
#        |-- <CODE_DIR>/      scripts + the data files they read
#        |-- <RESULTS_DIR>/   your real results; never touched by this script
#        `-- qc/
#            |-- run_pipeline.R
#            `-- runs/<label>/   one self-contained copy of the tree per run
#
#    If your scripts write somewhere else, set RESULTS_DIR to match. If they
#    write into the code folder itself, set RESULTS_DIR to the same value as
#    CODE_DIR; everything the run produced is still checksummed.
#
# 2. List your scripts in SCRIPTS, in the order they must run, and the data
#    files they read in DATA_FILES. Anything not listed is not copied into
#    the run folder, so a data file you forgot shows up as a file-not-found
#    error rather than quietly working because it happened to be sitting in
#    your project folder.
#
#    Keep any step that downloads data or queries a database OUT of SCRIPTS,
#    and put its saved output in DATA_FILES instead. Such a step cannot
#    produce the same output twice, which would make the repeat-run
#    comparison in step 6 below meaningless.
#
# 3. Set LAUNCH_METHOD to match how your scripts are written. See the note
#    beside the setting; the wrong value stops the first script immediately.
#
# 4. Optionally extend TRIAGE_PATTERNS with messages specific to your field.
#    The defaults cover missing functions, objects and files, R's partial
#    matching, and generic warnings and errors.
#
# 5. Run it. From a terminal, at the project root:
#        Rscript qc/run_pipeline.R --label A
#
#    From an R console (RStudio included), at the project root:
#        RUN_LABEL <- "A"; source("qc/run_pipeline.R")
#
#    In the background, for a long pipeline:
#        nohup Rscript qc/run_pipeline.R --label A > qc/run_A.console 2>&1 &
#
#    Options:
#      --label <name>   Run label; output goes to qc/runs/<label>/. Required.
#      --source <dir>   Override CODE_DIR for one run.
#      --continue       Keep going after a script fails. Default is to halt.
#
#    On Windows, Rscript is often not on the PATH. The console form above
#    avoids the problem: this script finds Rscript through R.home() and uses
#    the same R that is running it.
#
# 6. To test that outputs depend only on data and code, run a second label
#    and compare with the companion script:
#
#        Rscript qc/run_pipeline.R --label B
#        Rscript qc/compare_runs.R A B
#
#    Where a pipeline takes days to run, do not repeat it. Audit the sources
#    of variation instead (random draws, parallel scheduling, the clock, the
#    locale, file ordering) and repeat only the stochastic step, on one slice.
#
# -----------------------------------------------------------------------------
# WHAT IT LEAVES BEHIND, in qc/runs/<label>/qc_logs/
# -----------------------------------------------------------------------------
#
#   run_log.csv      script, exit status, minutes, start time
#   manifest.csv     every script, data file and output with its size and MD5
#   triage.csv       every warning and error, classified, with a blank
#                    disposition column for you to fill in
#   packages.csv     every package named in the scripts, with its version
#   environment.txt  R version, platform, Rscript path, start time
#   renv.lock        if renv is installed
#   <script>.out     stdout per script
#   <script>.err     stderr per script
#
# Fill in the disposition column of triage.csv with one of: expected (the code
# emits it deliberately), benign (a deprecation notice, a harmless partial
# match), or defect. Any hit in the fabricated-identifier classes is a defect
# by definition and this script exits non-zero.
#
# -----------------------------------------------------------------------------
# LICENSE AND CITATION
# -----------------------------------------------------------------------------
#
# Copyright (c) 2026 Masami Fujiwara, Department of Ecology and Conservation
# Biology, Texas A&M University.
#
# This work is licensed under the Creative Commons Attribution 4.0
# International License (CC BY 4.0). You are free to share and adapt it for any
# purpose, including commercially, provided you give appropriate credit,
# indicate whether changes were made, and link to the license:
#
#   https://creativecommons.org/licenses/by/4.0/
#
# The work is provided as is, without warranties or conditions of any kind. See
# Section 5 of the license for the full disclaimer of warranties and limitation
# of liability.
#
# CITATION. The license requires attribution. In published work, an ordinary
# citation satisfies it:
#
#   Fujiwara, M. (2026). A protocol for verifying ecological analysis code
#   developed with AI assistance. Zenodo. doi:10.5281/zenodo.XXXXXXX
#
# The DOI is minted when the repository is released and is recorded in
# CITATION.cff alongside these scripts; use the version there rather than the
# placeholder above.
# =============================================================================

# =============================================================================
# CONFIGURATION - the only block you need to edit
# =============================================================================

# Folder holding the pipeline scripts and the data files they read, relative
# to the project root.
CODE_DIR <- "01_Analysis"

# Folder the scripts write to, relative to the project root. Set equal to
# CODE_DIR if your scripts write beside themselves.
RESULTS_DIR <- "02_Results"

# The scripts to run, in the order they must run. Every script that is part
# of the pipeline goes here. Anything in CODE_DIR that is not listed is not
# run and not copied into the run folder.
SCRIPTS <- c(
  "b10_prepare.R",
  "b20_merge.R",
  "c10_model.R"
  # ... through to the last script
)

# Data files the pipeline reads but does not produce: raw data, lookup tables,
# the saved output of a step that is not part of this run. Paths are relative
# to CODE_DIR. These are copied into the run folder and checksummed.
# Optionally name each entry with whatever produced it; the name is recorded
# in the manifest and the run summary as the file's provenance.
DATA_FILES <- c(
  a10 = "Data.RData",
  a20 = "species_list.csv",
  a40 = "dispersal_guild_taxon_plus_traits.csv",
  a50 = "species_thermal_affiliation_w_codes.csv"
)

# Where each script starts. The child process working directory is set to
# this and SCRIPT_DIR is exported, so scripts that open files by name need no
# modification.
#   "code"  the folder holding the scripts (default)
#   "root"  the project root
#   any path, relative to the project root
WORKING_DIR <- "code"

# How each script is started. Which value you need depends on whether your
# scripts try to work out their own folder path, usually to call setwd() or
# to build a path to a data folder.
#
#   "direct"  Use this if your scripts search commandArgs() for "--file=".
#             Each script is run as: Rscript <script>
#
#   "source"  Use this if your scripts read sys.frames()[[1]]$ofile.
#             Each script is run through a one-line file that calls
#             source() on it, which is what makes $ofile available.
#
# R supplies only one of those two per method, never both, so the wrong
# choice stops a script on its first line. If that happens, switch the value.
# Scripts that don't work out their own path (they just open files by name,
# such as read.csv("species_list.csv")) run under either value.
#
# If you can edit the scripts, the most reliable arrangement is to have them
# read Sys.getenv("SCRIPT_DIR"), which is set for every script and is correct
# under either value.
LAUNCH_METHOD <- "direct"

# Patterns harvested from the logs into the triage table. The first block is
# the fabricated-identifier family and is a defect by definition: these cannot
# occur in code that is doing what its author intended. The second is R's
# partial-matching family, where a truncated argument or column name silently
# resolved to something the author may not have meant. The third is everything
# else warranting a disposition. Add domain-specific patterns as needed.
TRIAGE_PATTERNS <- c(
  fabricated_function  = "could not find function",
  fabricated_argument  = "unused argument",
  fabricated_object    = "object '[^']*' not found",
  fabricated_file      = "cannot open|No such file|does not exist",
  fabricated_package   = "there is no package called",
  partial_match        = "partial (argument )?match",
  error                = "^Error|Error in |Error:",
  warning              = "^Warning|Warning message|Warning in "
)

# Contents of the .Rprofile written into the run's code folder. Rscript reads
# .Rprofile from the working directory at startup, so every script inherits
# these. warn = 1 prints each warning where it happens rather than collecting
# them silently; the three partial-match options are the R-specific check
# against an argument or column name that resolved by prefix.
RPROFILE <- c(
  "# Written by qc/run_pipeline.R for one verification run.",
  "options(",
  "  warn                  = 1,     # print each warning as it happens",
  "  warnPartialMatchArgs  = TRUE,  # f(x, tr = 0.1) matching trim = ",
  "  warnPartialMatchDollar = TRUE, # df$col matching df$column",
  "  warnPartialMatchAttr  = TRUE,",
  "  scipen                = 0",
  ")"
)

# =============================================================================
# END OF CONFIGURATION - nothing below should need editing
# =============================================================================

# ---- 1) Arguments ----------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
get_opt <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i)) return(default)
  if (i == length(args) || startsWith(args[i + 1L], "--")) return(TRUE)
  args[i + 1L]
}
label      <- get_opt("--label")
source_dir <- get_opt("--source", CODE_DIR)
keep_going <- isTRUE(get_opt("--continue", FALSE))

# Sourced rather than launched by Rscript: no command line, so take the
# settings from variables in the global environment instead.
if (!length(args)) {
  if (exists("RUN_LABEL", envir = globalenv()))  label      <- get("RUN_LABEL", envir = globalenv())
  if (exists("RUN_SOURCE", envir = globalenv())) source_dir <- get("RUN_SOURCE", envir = globalenv())
}
if (is.null(label) || isTRUE(label))
  stop("A run label is required.\n",
       "  From a terminal:  Rscript qc/run_pipeline.R --label A\n",
       "  From R:           RUN_LABEL <- \"A\"; source(\"qc/run_pipeline.R\")\n",
       "  Working directory must be the project root (the folder containing ",
       CODE_DIR, ").")
if (!dir.exists(source_dir))
  stop("Source folder not found: ", normalizePath(source_dir, mustWork = FALSE))
source_dir <- normalizePath(source_dir)

t_start <- Sys.time()
cat("Verification run", label, "| started", format(t_start), "\n")

# ---- 2) Check the listed scripts and data files are present -----------------

if (!length(SCRIPTS))
  stop("SCRIPTS is empty. List the scripts to run, in run order.")
if (!length(DATA_FILES))
  stop("DATA_FILES is empty. List the data files your pipeline reads but does\n",
       "  not produce, or the run folder will not contain them.")

listed <- c(SCRIPTS, DATA_FILES)
absent <- listed[!file.exists(file.path(source_dir, listed))]
if (length(absent))
  stop("Listed in the configuration but not found in ", source_dir, ":\n  ",
       paste(absent, collapse = "\n  "))

scripts <- SCRIPTS
cat(length(scripts), "scripts to run, from", scripts[1], "to",
    scripts[length(scripts)], "\n")

# An R file sitting in the code folder that nobody listed is either a step
# left out on purpose or one forgotten. Report it either way, before anything
# runs, so the omission is a decision rather than an accident.
unlisted <- setdiff(list.files(source_dir, pattern = "\\.R$"), scripts)
if (length(unlisted))
  cat("Present but not listed in SCRIPTS, so not run:\n  ",
      paste(unlisted, collapse = ", "), "\n")

# ---- 3) Build the run tree -------------------------------------------------

run_root     <- file.path("qc", "runs", label)
analysis_dir <- file.path(run_root, CODE_DIR)
results_dir  <- file.path(run_root, RESULTS_DIR)
log_dir      <- file.path(run_root, "qc_logs")

if (dir.exists(run_root))
  stop("Run folder already exists: ", run_root,
       "\n  A verification run requires an empty tree, so that no file from an\n",
       "  earlier attempt can be read by mistake. Choose a new --label, or:\n",
       "    unlink(\"", run_root, "\", recursive = TRUE)")
for (d in unique(c(analysis_dir, results_dir, log_dir))) dir.create(d, recursive = TRUE)

run_root     <- normalizePath(run_root)
analysis_dir <- normalizePath(analysis_dir)
results_dir  <- normalizePath(results_dir)
log_dir      <- normalizePath(log_dir)

# Copy and checksum the scripts. Only the listed ones, so nothing in the tree
# can be re-run or overwritten by accident. The hashes matter: a comparison of
# two runs is only meaningful if both are known to have run the same code.
ok <- file.copy(file.path(source_dir, scripts), analysis_dir)
if (!all(ok)) stop("Failed to copy: ", paste(scripts[!ok], collapse = ", "))
script_manifest <- data.frame(
  role        = "script",
  file        = scripts,
  produced_by = "author",
  bytes       = file.size(file.path(analysis_dir, scripts)),
  md5         = unname(tools::md5sum(file.path(analysis_dir, scripts))),
  stringsAsFactors = FALSE
)

# Copy and checksum the data files.
ok <- file.copy(file.path(source_dir, DATA_FILES), analysis_dir)
if (!all(ok)) stop("Failed to copy data files: ",
                   paste(DATA_FILES[!ok], collapse = ", "))
data_manifest <- data.frame(
  role        = "data",
  file        = unname(DATA_FILES),
  produced_by = if (is.null(names(DATA_FILES))) "" else names(DATA_FILES),
  bytes       = file.size(file.path(analysis_dir, DATA_FILES)),
  md5         = unname(tools::md5sum(file.path(analysis_dir, DATA_FILES))),
  stringsAsFactors = FALSE
)
input_manifest <- rbind(script_manifest, data_manifest)

# Snapshot of what is in the tree before anything runs. Anything present
# afterwards but not here was produced by the run. compare_runs.R uses this to
# separate inputs from outputs.
pre_files <- list.files(run_root, recursive = TRUE, full.names = TRUE)

writeLines(RPROFILE, file.path(analysis_dir, ".Rprofile"))

# ---- 4) Environment record -------------------------------------------------

# Package versions for every package the scripts name, found by scanning the
# code for library(), require(), requireNamespace() and pkg:: calls.
code <- unlist(lapply(file.path(analysis_dir, scripts), readLines, warn = FALSE))
# The lookbehind stops a user function such as e10_require("...") from being
# read as require("..."). Comments are removed first so a package named only
# in a comment is not demanded.
code <- sub("#.*$", "", code)
pkg_calls <- regmatches(code, gregexpr(
  "(?<![A-Za-z0-9_.])(?:library|require|requireNamespace)\\(\\s*[\"']?([A-Za-z][A-Za-z0-9.]*)|(?<![A-Za-z0-9_.])([A-Za-z][A-Za-z0-9.]*)::",
  code, perl = TRUE))
pkgs <- unique(gsub("(?:library|require|requireNamespace)\\(\\s*[\"']?|::", "",
                    unlist(pkg_calls), perl = TRUE))
pkgs <- setdiff(sort(pkgs), c("base", "stats", "utils", "graphics", "grDevices",
                              "methods", "tools", "parallel", "grid"))
pkg_table <- data.frame(
  package   = pkgs,
  installed = vapply(pkgs, function(p) suppressMessages(suppressWarnings(
    requireNamespace(p, quietly = TRUE))), logical(1)),
  stringsAsFactors = FALSE
)
pkg_table$version <- ifelse(
  pkg_table$installed,
  vapply(pkgs, function(p) tryCatch(as.character(packageVersion(p)),
                                    error = function(e) NA_character_), character(1)),
  NA_character_)
write.csv(pkg_table, file.path(log_dir, "packages.csv"), row.names = FALSE)
# Packages reached only through requireNamespace(pkg, quietly = TRUE) are
# optional by construction: the calling code already handles their absence.
optional <- unique(unlist(regmatches(code, gregexpr(
  "requireNamespace\\(\\s*[\"']([A-Za-z][A-Za-z0-9.]*)", code, perl = TRUE))))
optional <- gsub("requireNamespace\\(\\s*[\"']", "", optional, perl = TRUE)
hard_missing <- pkg_table$package[!pkg_table$installed & !pkg_table$package %in% optional]
soft_missing <- pkg_table$package[!pkg_table$installed &  pkg_table$package %in% optional]
if (length(soft_missing))
  cat("[note] Optional packages not installed (reached only through",
      "requireNamespace):\n       ", paste(soft_missing, collapse = ", "), "\n")
if (length(hard_missing))
  stop("Packages named in the scripts but not installed:\n  ",
       paste(hard_missing, collapse = ", "),
       "\n  Install them, then run again.")

# renv lockfile if renv is available. Not required; packages.csv is the
# fallback record.
if (requireNamespace("renv", quietly = TRUE)) {
  tryCatch({
    renv::snapshot(project = analysis_dir,
                   lockfile = file.path(log_dir, "renv.lock"),
                   prompt = FALSE, force = TRUE)
  }, error = function(e) cat("renv::snapshot failed:", conditionMessage(e), "\n"))
}

# Always the Rscript that belongs to the R running this script, so the child
# processes use the same R version and library even when R's bin folder is not
# on the PATH (the usual case on Windows).
RSCRIPT <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
if (!file.exists(RSCRIPT)) stop("Rscript not found at ", RSCRIPT)

writeLines(c(paste("R:", R.version.string),
             paste("Platform:", R.version$platform),
             paste("Rscript:", RSCRIPT),
             paste("Child working directory:", WORKING_DIR),
             paste("Launch method:", LAUNCH_METHOD),
             paste("Run started:", format(t_start))),
           file.path(log_dir, "environment.txt"))

# ---- 5) Run each script in its own process ----------------------------------

# SCRIPT_DIR is an env var scripts may use to find their own folder. Set in
# this process; child processes inherit it, which works on every platform
# (system2's env argument does not). RESULTS_DIR is exported for the same
# reason.
Sys.setenv(SCRIPT_DIR = analysis_dir, RESULTS_DIR = results_dir)

# Child processes start here. Scripts that open files by name depend on this,
# so it is recorded in environment.txt.
child_wd <- switch(WORKING_DIR,
                   code = analysis_dir,
                   root = run_root,
                   normalizePath(file.path(run_root, WORKING_DIR), mustWork = FALSE))
if (!dir.exists(child_wd))
  stop("WORKING_DIR does not resolve to a folder in the run tree: ", child_wd)
cat("[dir] Working directory:", child_wd, "| launch method:", LAUNCH_METHOD, "\n")

old_wd <- setwd(child_wd)
# No on.exit() here: at the top level of a source()d file it fires as soon as
# the expression is evaluated, which would reset the directory before the loop
# runs. The loop restores old_wd in a tryCatch(finally = ) instead.

run_log <- vector("list", length(scripts))
halted  <- FALSE

tryCatch({
  for (i in seq_along(scripts)) {
    s   <- scripts[i]
    out <- file.path(log_dir, paste0(s, ".out"))
    err <- file.path(log_dir, paste0(s, ".err"))
    
    # --no-save --no-restore: nothing carried in, nothing carried out. The
    # .Rprofile in analysis_dir is still read (that would need --vanilla to
    # skip). Full path, so the script is found regardless of the child working
    # directory. Under "source" a one-line wrapper is written and run instead,
    # which gives the script a call frame and therefore
    # sys.frames()[[1]]$ofile. A wrapper file rather than -e avoids shell
    # quoting problems with paths containing spaces.
    target <- gsub("\\\\", "/", file.path(analysis_dir, s))
    if (identical(LAUNCH_METHOD, "source")) {
      wrapper <- file.path(log_dir, paste0(".launch_", s))
      writeLines(sprintf('source("%s")', target), wrapper)
      cmd_args <- c("--no-save", "--no-restore", shQuote(wrapper))
    } else {
      cmd_args <- c("--no-save", "--no-restore", shQuote(target))
    }
    
    cat(sprintf("[%2d/%2d] %-36s ", i, length(scripts), s))
    t0 <- Sys.time()
    status <- system2(RSCRIPT, cmd_args, stdout = out, stderr = err, wait = TRUE)
    mins <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 2)
    cat(sprintf("status %d  %6.2f min\n", status, mins))
    
    run_log[[i]] <- data.frame(
      order = i, script = s, status = status, minutes = mins,
      started = format(t0), stringsAsFactors = FALSE)
    
    if (status != 0L) {
      cat("  ** non-zero exit. Last lines of stderr:\n")
      cat(paste0("  | ", tail(readLines(err, warn = FALSE), 12)), sep = "\n")
      if (!keep_going) { halted <- TRUE; break }
    }
  }
}, finally = setwd(old_wd))

run_log <- do.call(rbind, run_log)
write.csv(run_log, file.path(log_dir, "run_log.csv"), row.names = FALSE)

# ---- 6) Output manifest ----------------------------------------------------

post_files <- list.files(run_root, recursive = TRUE, full.names = TRUE)
new_files  <- setdiff(post_files, pre_files)
# Logs are records of the run, not outputs of it. Compare on a normalised
# path: on Windows list.files() returns forward slashes while normalizePath()
# returns backslashes, so a raw startsWith() never matches and every log file
# is recorded as an output.
norm_path  <- function(x) gsub("\\\\", "/", x)
new_files  <- new_files[!startsWith(norm_path(new_files), norm_path(log_dir))]

output_manifest <- data.frame(
  role        = rep("output", length(new_files)),
  file        = substring(new_files, nchar(run_root) + 2L),   # path relative to run_root
  produced_by = rep("run", length(new_files)),
  bytes       = file.size(new_files),
  md5         = unname(tools::md5sum(new_files)),
  stringsAsFactors = FALSE
)
input_manifest$file <- file.path(CODE_DIR, input_manifest$file)
manifest <- rbind(input_manifest, output_manifest)
write.csv(manifest, file.path(log_dir, "manifest.csv"), row.names = FALSE)

# The largest data output is usually the consolidated results object, and its
# hash is a convenient single identifier for the run to cite in a manuscript.
# Figures are excluded: they are large and their bytes depend on the renderer.
data_out <- output_manifest[!tolower(tools::file_ext(output_manifest$file)) %in%
                              c("pdf", "tiff", "tif", "png", "svg", "jpg", "jpeg"), ]
main_out <- if (nrow(data_out)) data_out$file[which.max(data_out$bytes)] else NA_character_
main_md5 <- if (nrow(data_out)) data_out$md5[which.max(data_out$bytes)]  else NA_character_

# ---- 7) Triage table from the logs -----------------------------------------

triage <- list()
for (s in run_log$script) {
  for (ext in c(".err", ".out")) {
    f <- file.path(log_dir, paste0(s, ext))
    if (!file.exists(f)) next
    lines <- readLines(f, warn = FALSE)
    # With warn = 1, R prints "Warning in <call> :" and the message on the next
    # indented line. Join continuation lines so each record is one line.
    if (length(lines) > 1L) {
      cont <- grepl("^\\s+\\S", lines) & c(FALSE, grepl("Warning|Error", head(lines, -1L)))
      for (k in rev(which(cont))) {
        lines[k - 1L] <- paste(lines[k - 1L], trimws(lines[k]))
        lines <- lines[-k]
      }
    }
    for (p in names(TRIAGE_PATTERNS)) {
      hits <- lines[grepl(TRIAGE_PATTERNS[[p]], lines, perl = TRUE)]
      if (!length(hits)) next
      tab <- table(hits)
      triage[[length(triage) + 1L]] <- data.frame(
        script = s, stream = sub("^\\.", "", ext), class = p,
        message = names(tab), n = as.integer(tab),
        disposition = "",   # to be filled by the reviewer: expected / benign / defect
        stringsAsFactors = FALSE)
    }
  }
}
triage <- if (length(triage)) do.call(rbind, triage) else
  data.frame(script = character(), stream = character(), class = character(),
             message = character(), n = integer(), disposition = character())
# A line matching a specific class also matches the generic "warning" or
# "error" class. Keep the specific one.
if (nrow(triage)) {
  key     <- paste(triage$script, triage$stream, triage$message)
  generic <- triage$class %in% c("warning", "error")
  triage  <- triage[!(generic & key %in% key[!generic]), ]
}
write.csv(triage, file.path(log_dir, "triage.csv"), row.names = FALSE)

# ---- 8) Summary ------------------------------------------------------------

n_fab <- sum(triage$n[grepl("^fabricated", triage$class)])
n_pm  <- sum(triage$n[triage$class == "partial_match"])
n_oth <- sum(triage$n[triage$class %in% c("warning", "error")])

cat("\n============================================================\n")
cat("Verification run", label, if (halted) "HALTED" else "COMPLETE",
    "|", format(round(difftime(Sys.time(), t_start, units = "mins"), 1)), "\n")
cat(sprintf("Scripts run: %d of %d | non-zero exits: %d\n",
            nrow(run_log), length(scripts), sum(run_log$status != 0L)))
cat("Data files (copied in, not produced by this run):\n")
cat(sprintf("  %-52s %s  %s\n", data_manifest$file, data_manifest$produced_by,
            data_manifest$md5), sep = "")
cat(sprintf("Outputs written: %d files\n", nrow(output_manifest)))
if (!is.na(main_md5))
  cat(sprintf("Largest output: %s  MD5 %s\n", main_out, main_md5))
cat(sprintf("Triage: %d fabricated-identifier hits, %d partial-match hits, %d other warnings/errors\n",
            n_fab, n_pm, n_oth))
if (n_fab > 0)
  cat("** Fabricated-identifier hits are defects by definition; this run has not passed.\n")
cat("Records in", log_dir, ":\n",
    "  run_log.csv  manifest.csv  triage.csv  packages.csv  environment.txt",
    if (file.exists(file.path(log_dir, "renv.lock"))) " renv.lock" else "", "\n")
cat("Next: fill the disposition column in triage.csv. To test that outputs\n",
    "depend only on data and code, run a second label and compare:\n",
    "  Rscript qc/run_pipeline.R --label <other>\n",
    "  Rscript qc/compare_runs.R", label, "<other>\n")
cat("============================================================\n")

# Exit status matters for a terminal launch; in a sourced session quit() would
# close the user's R session, so just report.
run_ok <- !(halted || n_fab > 0 || any(run_log$status != 0L))
if (!interactive()) quit(status = if (run_ok) 0L else 1L)
invisible(run_ok)