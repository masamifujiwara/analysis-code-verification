# Prompt: find the sources of variation a text search cannot match

I am auditing the sources of run-to-run and between-machine variation in an
analysis pipeline. The audit has two passes. A text search over the codebase
covers the first pass, and it is run separately. **This prompt is the second
pass: read the code and find what a text search cannot match.**

Below are the scripts. Produce one CSV row per candidate source of variation
that a text search would miss.

## What counts as a source of variation

If the code is fixed and the data are fixed, anything that differs between two
runs came from outside both. Two families:

**Varies between runs on the same machine**

- a random draw where no seed is set, or where a seed is set once but the draw
  happens in a worker that does not inherit it
- parallel work whose results are combined in order of completion
- any quantity, seed, filename, or branch condition taken from the clock

**Fixed on one machine, different between machines**

- the locale, which governs how text sorts, how string comparisons resolve, and
  how numbers are parsed from text
- the order in which files come back when the code asks for the contents of a
  folder rather than naming the files it wants
- anything whose result depends on the number of cores, the linear algebra
  library, or a platform-specific default

Summation order in floating-point arithmetic can arise in either family,
depending on what caused the reordering.

## What the separate text search already covers

The first pass searches the codebase for these names:

```
sample  runif  rnorm  rbinom  rpois  rgamma  rmultinom
set.seed  Sys.time  Sys.Date  date  proc.time
list.files  dir  Sys.glob  sort  order  Sys.setlocale
```

plus the names exported by whatever package supplies parallelism in these
scripts. Edit this list if the search that was run differs; everything below
depends on it.

**Do not report a line that itself contains one of these names.** A text search
finds that line already, so a row describing it adds nothing and dilutes the
output. Where the effect of such a line is invisible at the place that matters,
report **that** place instead. If a helper function contains `sample()`, the
`sample()` line belongs to the search; the call to the helper, where nothing
indicates that a draw occurs, belongs to you.

If search results happen to be available, they can be pasted below the scripts,
but they are not required. The list above is what this pass is defined against.

## What to look for

These are the cases a name-based search cannot reach. They are the point of
this task.

- **A draw inside a helper the analysis wrote itself.** A function whose name
  gives no hint that it samples, bootstraps, jitters, permutes, initializes at
  random, or breaks a tie arbitrarily. Read what the function does, not what it
  is called. Report the call sites.
- **A function reached indirectly.** A function passed as an argument, stored in
  a list and called later, or invoked through `do.call`, `match.fun`, `get`,
  `apply`, `Map`, or a `switch`. The name of the thing actually called may
  appear nowhere as a call.
- **Parallelism switched on by an option rather than by a call.** A package that
  parallelizes when a global option, an environment variable, or a `cores` or
  `nthreads` argument is set, with no `mclapply` or `foreach` anywhere.
- **A package that draws or reorders internally.** An estimator that bootstraps,
  rarefies, resamples, or initializes at random inside a call the analysis makes
  once. Also any routine documented as returning results in an unspecified
  order.
- **Order dependence without a folder listing.** Rows paired positionally between
  two objects whose order is not guaranteed, a join whose output order is relied
  on, a `which.max` or a first-match lookup where ties are possible, a hash or
  environment iterated in its own order.
- **Locale reaching a result without a sort call.** Case-insensitive comparison,
  a regular expression using a character class whose meaning is locale-dependent,
  a factor whose level order comes from the data, numbers parsed from text with a
  decimal separator.
- **A seed set in a way that does not cover everything it appears to.** A seed
  set after the first draw, set inside a function so it does not persist, set per
  worker without a reproducible scheme, or reset partway through. Report the
  scope that is left uncovered, not the `set.seed` line.

## Columns

Return a CSV with a header row and these columns:

- **id**: a short unique label
- **script**: filename
- **anchor**: the line of code, copied verbatim, that the reader should look at.
  No line numbers. For a source inside a package, the anchor is the call the
  analysis makes.
- **family**: `same_machine` or `between_machine`, or `either` for a
  floating-point reordering that could be either
- **mechanism**: one sentence on what varies and why
- **why_search_missed**: one clause naming which case above this falls under.
  A row that cannot fill this column belongs to the text search, not to this
  pass, and should be dropped.
- **confidence**: `certain`, `likely`, or `check`. Use `certain` only where the
  code in front of you settles it. Use `check` for anything resting on how a
  package behaves internally.
- **verify_how**: for `likely` and `check` rows, the specific thing that would
  settle it: a named argument in the package documentation, a `sessionInfo()`
  field, a small experiment to run.
- **reaches_reported**: leave empty. This is answered from the analysis's own
  dataflow, not from reading.
- **notes**: anything else

## Rules

- **Do not assert what a package does internally.** You may be working from an
  older version, or from documentation that has changed. Anything about package
  internals is `check`, with the specific thing to look up in `verify_how`.
- **Read the function, not its name.** A helper called `prepare_grid` may sample;
  a helper called `bootstrap_ci` may be deterministic given its inputs.
- **Report the absence of a control as well as the presence of a mechanism.** A
  draw reached through a helper, with a seed set correctly at the top level, is
  still worth a row marked `certain` with the control named in `notes`, because
  the audit records what is controlled as well as what is not.
- **Do not judge whether a source matters.** Leave `reaches_reported` empty. A
  mechanism in code that feeds nothing reported is still a correct row.
- **Prefer omitting to guessing.** A short list of real candidates is worth more
  than a long list padded with plausible ones. An audit that looks complete and
  is not is worse than one that is visibly partial. **If you find nothing,
  return a header row and say so.** That is a legitimate result, and it is more
  useful than invented rows.

## After the CSV

Write two short lists.

**What you could not determine from the code alone**, with what you would need
to see: another script, a package version, the contents of a config file.

**Which scripts you read least carefully**, if any, and why: length, unfamiliar
idiom, generated code. The reader needs to know where your coverage is thin.
