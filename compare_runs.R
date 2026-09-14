# =============================================================================
# qc/compare_runs.R
#
# Part A, the repeat test: run the pipeline twice and compare the outputs.
#
# This script reports what differs. It cannot say why, and it is not meant to
# be read on its own. The companion is the audit of the sources of variation:
# a list, written before the runs are compared, of every mechanism by which
# two executions of the same code on the same data could differ, with a note
# at each of whether it can reach a reported quantity. The audit says in
# advance which numbers should match exactly and which should move, and
# roughly by how much. Without it, a reseeded sampler and a file-ordering bug
# present here the same way: numbers that differ.
#
# Compares two runs produced by qc/run_pipeline.R. A file counts as identical
# when its MD5 matches. When the MD5 differs, the contents are loaded and
# compared after removing the two things that legitimately differ between two
# runs of correct code:
#
#   1. Date stamps in filenames. Pipelines often write results_20260901.RDS,
#      so files are paired on a name with any 8-digit date removed.
#   2. Time-typed values inside saved objects. Any POSIXct, Date or difftime
#      element, and any element whose name matches TIME_NAMES, is dropped
#      before comparison.
#
# Numbers are then compared at two levels. A difference below TOLERANCE is
# reported as WITHIN_TOLERANCE rather than as a failure: parallel workers and
# threaded BLAS libraries sum in whatever order they finish in, so the last
# bits of a floating-point result vary between runs of correct code. Anything
# larger usually points to unseeded randomness or to logic that reads the
# clock, but this script does not know that and does not claim it. What it
# gives you is the file, and the file names the script that wrote it. Which
# of the audited sources reached that script is the question to take back to
# the audit.
#
# Figures are compared by MD5 only and reported separately, because rendering
# libraries embed creation timestamps: a hash mismatch on a figure is expected
# and does not affect the verdict.
#
# THE VERDICT. Three outcomes, not pass and fail:
#
#   BYTE-IDENTICAL              every output matched exactly.
#   REPEATABLE WITHIN TOLERANCE some outputs differed only at floating-point
#                               scale. This is the expected result where the
#                               audit found a live reduction-order source, a
#                               parallel backend or a threaded BLAS. Where it
#                               found none, a drift here is a finding, not a
#                               pass: something varies that the audit missed.
#                               Confirm that no number you report moves at
#                               the precision you report it to, then say so
#                               in the methods.
#   DIFFERENCES NEED REVIEW     something differed by more than tolerance, or
#                               could not be checked. This script cannot tell
#                               whether such a difference matters; that
#                               judgement is yours, as with the disposition
#                               column in triage.csv. Dispose of each against
#                               the audit: a difference the audit predicted
#                               is a pass to be recorded, and one it did not
#                               predict is a finding, whatever its size.
#
# A difference that passes the tolerance but is larger than the audit led you
# to expect is also a finding. An estimate that moves in the second decimal
# between two machines has told you something about how well the optimum is
# identified, and that belongs in the paper whether or not it clears a cutoff.
#
# -----------------------------------------------------------------------------
# ADAPTING THIS TO YOUR PROJECT
# -----------------------------------------------------------------------------
#
# Usually nothing needs changing. The settings that might:
#
#   TOLERANCE   relative difference treated as floating-point noise.
#   TIME_NAMES  a regex matching element names your code uses for run
#               metadata (built_on, generated_on, and so on). Anything
#               matching is ignored when comparing object contents.
#   FIGURE_EXT  file extensions treated as figures.
#   TEXT_EXT    file extensions compared line by line.
#
# The first three are audit findings written as settings, and leaving them at
# their defaults adopts three conclusions you did not reach: that summation
# order is live and bounded by TOLERANCE, that everything clock-derived is
# named in TIME_NAMES, and that figure bytes carry render metadata and so
# need not match. Each is usually right. Each should appear in the audit as a
# line you wrote, not as a default you inherited.
#
# If your pipeline writes a format that is none of RDS, RData, a text type or
# a figure, this script cannot open it and reports HASH_DIFF, meaning "the
# bytes differ and I could not check whether that matters". That is not a
# pass. Rather than ignoring it, teach the script to read the format: add the
# extension to TEXT_EXT if it is readable as text, or add a branch to
# compare_contents(). An .xlsx branch is included as a worked example, since
# Excel embeds a creation timestamp and so never matches on hash.
#
# -----------------------------------------------------------------------------
# RUNNING IT
# -----------------------------------------------------------------------------
#
#   Rscript qc/compare_runs.R A B
#
#   or, from an R console at the project root:
#       RUN_A <- "A"; RUN_B <- "B"; source("qc/compare_runs.R")
#
# WHICH TWO RUNS. Both comparisons below are worth making, they answer
# different questions, and neither substitutes for the other. Run this script
# once for each pairing rather than choosing between them, and report the two
# separately.
#
#   Same machine, two labels. The environment is held fixed, so anything that
#   differs came from inside the runs: randomness, or logic that reads the
#   clock. This pairing is also the completeness check on the audit, since
#   two runs in one environment that disagree mean a live source was missed.
#
#   Different machines, one label on each. Here the environment is the thing
#   that varies, so this is the only pairing that can reach the locale, which
#   governs sorting, string comparison and number parsing, and the order in
#   which files are read when the code lists a directory rather than naming
#   its inputs. Both are stable on any one machine, so the pairing above
#   agrees with itself every time and says nothing about either. The cost is
#   that the BLAS, the package versions and the parallel backend all vary at
#   once, so a difference does not name its own cause. Read packages.csv and
#   environment.txt from the two runs first, since a version difference
#   explains a numeric one, and take the rest to the audit.
#
# Where only one pairing is affordable, put it on the second machine. The
# environment-dependent sources are the ones inspection is least likely to
# have settled and a same-machine repeat cannot reach at all, so that is
# where a single comparison buys the most. What is given up is the
# completeness check, and the manuscript should say so.
#
# Exit status 0 for BYTE-IDENTICAL or REPEATABLE WITHIN TOLERANCE, 1 for
# DIFFERENCES NEED REVIEW.
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

args <- commandArgs(trailingOnly = TRUE)
# Sourced rather than launched by Rscript: take the labels from RUN_A and
# RUN_B in the global environment.
if (!length(args) && exists("RUN_A", envir = globalenv()) && exists("RUN_B", envir = globalenv()))
  args <- c(get("RUN_A", envir = globalenv()), get("RUN_B", envir = globalenv()))
if (length(args) != 2L)
  stop("Two run labels are required.\n",
       "  From a terminal:  Rscript qc/compare_runs.R A B\n",
       "  From R:           RUN_A <- \"A\"; RUN_B <- \"B\"; source(\"qc/compare_runs.R\")")
lab <- args

# Relative difference below which two numbers are treated as equal. Parallel
# reduction order and threaded BLAS routinely produce differences at this
# scale in correct code. Set to 0 to require exact equality, which is the
# right setting for a pipeline the audit found to be fully deterministic:
# a quantity reported with no uncertainty must match exactly.
TOLERANCE <- 1e-8

# Element names holding run metadata rather than results: timestamps, timing
# measurements, and paths that depend on where the run happened. Extend for
# your own conventions; anything matching is ignored when comparing contents.
# Note that this filter is not applied to data frame columns, so a results
# column named "duration" or "elapsed" is still compared.
#
# Every name added here is a claim that the element is a record of the run
# rather than a result of it. The claim is easy to get wrong in the direction
# that hides a difference, so add names deliberately and list them in the
# audit alongside the clock-derived sources they correspond to.
TIME_NAMES <- paste0("^(built_on|generated_on|created|timestamp|run_date|run_time|",
                     "session|sessionInfo|date_run|time_run|",
                     "elapsed|elapsed_sec|elapsed_secs|elapsed_time|runtime|duration|",
                     "script_dir|results_dir|project_root|wd|working_dir|host|hostname)$")

FIGURE_EXT <- c("pdf", "tiff", "tif", "png", "svg", "jpg", "jpeg")

# Extensions compared line by line as text rather than by hash alone.
TEXT_EXT <- c("csv", "tsv", "txt", "out", "err", "log", "md", "json",
              "yml", "yaml", "tex", "R", "r")

# ---- 1) Load manifests -----------------------------------------------------

roots <- file.path("qc", "runs", lab)
for (r in roots) if (!dir.exists(r)) stop("Run folder not found: ", r)
man <- lapply(roots, function(r) {
  m <- read.csv(file.path(r, "qc_logs", "manifest.csv"), stringsAsFactors = FALSE)
  m$root <- r
  m
})
names(man) <- lab

# Scripts and data must be identical or the runs are not comparable at all.
# An empty result here means the manifests do not use the expected role
# values, which would make this check pass without testing anything, so it is
# an error rather than a skip.
inp <- lapply(man, function(m) m[m$role %in% c("script", "data"), c("file", "md5")])
if (!nrow(inp[[1]]) || !nrow(inp[[2]]))
  stop("No script or data rows found in manifest.csv. Were these runs produced\n",
       "  by the current run_pipeline.R? Expected role values: script, data, output.")

# Row names survive subsetting, so compare the values with row names dropped;
# otherwise two manifests listing the same files in a different order are
# reported as different.
as_key <- function(d) {
  d <- d[order(d$file), c("file", "md5")]
  rownames(d) <- NULL
  d
}
if (!identical(as_key(inp[[1]]), as_key(inp[[2]]))) {
  cat("** Scripts or data files differ between runs. Not comparable.\n")
  print(merge(inp[[1]], inp[[2]], by = "file", all = TRUE, suffixes = paste0(".", lab)))
  if (!interactive()) quit(status = 1L)
  stop("Inputs differ; comparison abandoned.")
}

out <- lapply(man, function(m) m[m$role == "output", ])
if (!nrow(out[[1]]) && !nrow(out[[2]]))
  stop("Neither run recorded any output files. Nothing to compare.")

# ---- 2) Pair files on a normalised name ------------------------------------

norm_name <- function(f) gsub("_?(19|20)[0-9]{6}(?=\\.|_|$)", "", f, perl = TRUE)
for (i in seq_along(out)) out[[i]]$key <- norm_name(out[[i]]$file)

# Duplicate keys within one run mean two date-stamped copies of the same file
# ended up in one tree, which should be impossible in a clean run.
for (i in seq_along(out)) {
  d <- unique(out[[i]]$key[duplicated(out[[i]]$key)])
  if (length(d)) cat("** Run", lab[i], "has multiple files for:", paste(d, collapse = ", "), "\n")
}

pairs <- merge(out[[1]][, c("key", "file", "md5")],
               out[[2]][, c("key", "file", "md5")],
               by = "key", all = TRUE, suffixes = c(".A", ".B"))
pairs$ext <- tolower(tools::file_ext(pairs$key))
pairs$is_figure <- pairs$ext %in% FIGURE_EXT

# ---- 3) Content comparison for hash mismatches -----------------------------

# Recursively remove time-typed elements and elements with metadata names.
# Also drops the "provenance" attribute if present, and nulls environments
# (model objects carry them) because identical() compares environments by
# address. The name filter is skipped for data frames so that a results
# column named "duration" or "session" is not silently discarded.
#
# Note: lapply() drops the class attribute of an S3 list, so a stripped
# object is a plain list. That happens on both sides, so comparisons remain
# valid, but a note returned by all.equal() may refer to list positions
# rather than to the slot names of the original class.
strip_time <- function(x) {
  if (inherits(x, c("POSIXt", "Date", "difftime"))) return(NULL)
  if (is.environment(x)) return(NULL)
  attr(x, "provenance") <- NULL
  if (is.list(x)) {
    nm <- names(x)
    if (!is.null(nm) && !is.data.frame(x))
      x <- x[!grepl(TIME_NAMES, nm, ignore.case = TRUE)]
    return(lapply(x, strip_time))
  }
  x
}

# Two-level numeric comparison. Returns equal = TRUE with drift = TRUE when
# the objects agree only once TOLERANCE is allowed.
compare_values <- function(a, b) {
  if (isTRUE(all.equal(a, b, tolerance = 0))) return(list(equal = TRUE, drift = FALSE))
  near <- all.equal(a, b, tolerance = TOLERANCE)
  if (isTRUE(near)) return(list(equal = TRUE, drift = TRUE))
  list(equal = FALSE, drift = FALSE, note = paste(as.character(near), collapse = " | "))
}

compare_contents <- function(fa, fb, ext) {
  tryCatch({
    
    if (ext == "rds") {
      v <- compare_values(strip_time(readRDS(fa)), strip_time(readRDS(fb)))
      return(list(equal = v$equal, drift = v$drift,
                  note = if (!v$equal) v$note
                  else if (v$drift) sprintf("agrees within %g; floating-point scale", TOLERANCE)
                  else "identical after removing time stamps"))
      
    } else if (ext %in% c("rdata", "rda")) {
      ea <- new.env(); eb <- new.env()
      load(fa, envir = ea); load(fb, envir = eb)
      na <- sort(ls(ea)); nb <- sort(ls(eb))
      if (!identical(na, nb))
        return(list(equal = FALSE, drift = FALSE, note = "different object sets"))
      diffs <- character(); drifted <- character()
      for (o in na) {
        v <- compare_values(strip_time(get(o, ea)), strip_time(get(o, eb)))
        if (!v$equal) diffs <- c(diffs, o) else if (v$drift) drifted <- c(drifted, o)
      }
      if (length(diffs))
        return(list(equal = FALSE, drift = FALSE,
                    note = paste("objects differ:", paste(diffs, collapse = ", "))))
      if (length(drifted))
        return(list(equal = TRUE, drift = TRUE,
                    note = paste("agree within tolerance:", paste(drifted, collapse = ", "))))
      return(list(equal = TRUE, drift = FALSE,
                  note = "identical after removing time stamps"))
      
    } else if (ext %in% TEXT_EXT) {
      a <- readLines(fa, warn = FALSE); b <- readLines(fb, warn = FALSE)
      if (identical(a, b))
        return(list(equal = TRUE, drift = FALSE, note = "identical text"))
      if (length(a) != length(b))
        return(list(equal = FALSE, drift = FALSE, note = "different line counts"))
      # Equal length, so the comparison below cannot recycle.
      n <- which(a != b)
      if (!length(n))
        return(list(equal = TRUE, drift = FALSE, note = "differ in encoding only"))
      # A numeric table may differ only in trailing digits. Reread as data and
      # compare with tolerance before calling it a difference.
      if (ext %in% c("csv", "tsv")) {
        sep <- if (ext == "tsv") "\t" else ","
        da <- read.csv(fa, sep = sep, stringsAsFactors = FALSE)
        db <- read.csv(fb, sep = sep, stringsAsFactors = FALSE)
        v  <- compare_values(da, db)
        if (v$equal)
          return(list(equal = TRUE, drift = v$drift,
                      note = if (v$drift)
                        sprintf("%d line(s) differ, but values agree within %g",
                                length(n), TOLERANCE)
                      else "values equal; text formatting differs"))
        return(list(equal = FALSE, drift = FALSE,
                    note = sprintf("%d line(s) differ; first at line %d", length(n), n[1])))
      }
      return(list(equal = FALSE, drift = FALSE,
                  note = sprintf("%d line(s) differ; first at line %d", length(n), n[1])))
      
    } else if (ext == "xlsx" && requireNamespace("readxl", quietly = TRUE)) {
      # Worked example of teaching this script a binary format. Excel embeds a
      # creation timestamp, so the hash never matches; the sheet contents do.
      rd <- function(f) lapply(readxl::excel_sheets(f),
                               function(s) as.data.frame(readxl::read_excel(f, sheet = s)))
      v <- compare_values(rd(fa), rd(fb))
      return(list(equal = v$equal, drift = v$drift,
                  note = if (!v$equal) v$note
                  else if (v$drift) sprintf("sheets agree within %g", TOLERANCE)
                  else "sheet contents identical; file metadata differs"))
      
    } else {
      return(list(equal = NA, drift = FALSE,
                  note = paste0("cannot read .", ext, "; bytes differ, contents not checked")))
    }
    
  }, error = function(e)
    list(equal = FALSE, drift = FALSE,
         note = paste("compare failed:", conditionMessage(e))))
}

pairs$status <- NA_character_
pairs$note   <- NA_character_

for (i in seq_len(nrow(pairs))) {
  p <- pairs[i, ]
  if (is.na(p$file.A) || is.na(p$file.B)) {
    pairs$status[i] <- "MISSING"
    pairs$note[i]   <- paste("present only in run", if (is.na(p$file.A)) lab[2] else lab[1])
    next
  }
  if (identical(p$md5.A, p$md5.B)) {
    pairs$status[i] <- "IDENTICAL"; pairs$note[i] <- "md5 match"
    next
  }
  if (p$is_figure) {
    pairs$status[i] <- "FIGURE_DIFF"
    pairs$note[i]   <- "hash differs; figures carry render metadata"
    next
  }
  r <- compare_contents(file.path(roots[1], p$file.A), file.path(roots[2], p$file.B), p$ext)
  pairs$status[i] <- if (isTRUE(r$drift))      "WITHIN_TOLERANCE"
  else if (isTRUE(r$equal)) "IDENTICAL"
  else if (is.na(r$equal))  "HASH_DIFF"
  else                      "DIFFERENT"
  pairs$note[i] <- r$note
}

# ---- 4) Cross-check the run logs and triage counts -------------------------

logs <- lapply(roots, function(r) read.csv(file.path(r, "qc_logs", "run_log.csv"), stringsAsFactors = FALSE))
tri  <- lapply(roots, function(r) read.csv(file.path(r, "qc_logs", "triage.csv"), stringsAsFactors = FALSE))
same_scripts <- identical(logs[[1]]$script, logs[[2]]$script)
same_status  <- same_scripts && identical(logs[[1]]$status, logs[[2]]$status)
tri_counts   <- lapply(tri, function(t) if (nrow(t)) tapply(t$n, t$class, sum) else integer())
same_triage  <- identical(tri_counts[[1]], tri_counts[[2]])

# ---- 5) Report -------------------------------------------------------------

out_path <- file.path("qc", "runs", sprintf("compare_%s_%s.csv", lab[1], lab[2]))
write.csv(pairs[order(pairs$status, pairs$key),
                c("key", "file.A", "file.B", "status", "note")],
          out_path, row.names = FALSE)

tab <- table(factor(pairs$status,
                    levels = c("IDENTICAL", "WITHIN_TOLERANCE", "FIGURE_DIFF",
                               "HASH_DIFF", "DIFFERENT", "MISSING")))
cat("\n============================================================\n")
cat(sprintf("Compare runs %s vs %s: %d output files paired\n", lab[1], lab[2], nrow(pairs)))
print(tab)
cat(sprintf("\nScripts and exit statuses identical: %s\n", same_status))
cat(sprintf("Triage class counts identical:       %s\n", same_triage))
if (!same_triage) {
  cat("  Run", lab[1], ":\n"); print(tri_counts[[1]])
  cat("  Run", lab[2], ":\n"); print(tri_counts[[2]])
}

bad   <- pairs[pairs$status %in% c("DIFFERENT", "MISSING", "HASH_DIFF"), ]
drift <- pairs[pairs$status == "WITHIN_TOLERANCE", ]

if (nrow(drift)) {
  cat("\nAgree within tolerance but not byte-identical:\n")
  for (i in seq_len(nrow(drift)))
    cat(sprintf("  %-52s %s\n", drift$key[i], drift$note[i]))
  cat("\nThis is the expected result for a pipeline using parallel workers or\n",
      "a threaded BLAS: summation order varies between runs, so the last bits\n",
      "of a result differ. Check that no number you report moves at the\n",
      "precision you report it to, then state in the methods that the\n",
      "pipeline was run twice and the outputs agreed within floating-point\n",
      "tolerance.\n")
}

if (nrow(bad)) {
  cat("\nDifferences needing review:\n")
  for (i in seq_len(nrow(bad)))
    cat(sprintf("  %-16s %-52s %s\n", bad$status[i], bad$key[i], bad$note[i]))
  cat("\nFor DIFFERENT and MISSING, the script that wrote the file is the one\n",
      "to inspect, for either unseeded randomness (a parallel map with a\n",
      "per-worker seed but no global set.seed(); a sample() or r*() call with\n",
      "no seed) or logic that reads the clock.\n")
  if (any(bad$status == "HASH_DIFF"))
    cat("\nHASH_DIFF means this script could not open the file, so it does not\n",
        "know whether the difference matters. Add the extension to TEXT_EXT if\n",
        "it is readable as text, or add a branch to compare_contents(); see the\n",
        "xlsx branch for a worked example.\n")
}

cat("Full table:", out_path, "\n")
cat("============================================================\n")

# Three outcomes, not pass and fail. A difference larger than tolerance is not
# declared a failure, because this script cannot tell whether it matters; it
# is flagged for the same kind of human disposition as a triage entry.
review <- nrow(bad) > 0L || !same_status
verdict <- if (review) {
  "DIFFERENCES NEED REVIEW"
} else if (nrow(drift)) {
  "REPEATABLE WITHIN TOLERANCE"
} else {
  "BYTE-IDENTICAL"
}
cat("REPEAT TEST:", verdict, "\n")
if (!interactive()) quit(status = if (review) 1L else 0L)
invisible(verdict)