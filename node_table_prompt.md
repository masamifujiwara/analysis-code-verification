# Prompt: build a node table from an analysis script

I am building a node table for code verification. Read the attached script or scripts and produce one CSV row per node.

## What a node is

A node is a point in the pipeline where a quantity changes meaning, not where a variable changes value. A rename or a reshape is not a node. A node is one of:

- an aggregation, join, or filter that changes what one row represents
- a call into a statistical package
- arithmetic combining two derived quantities
- a filter that changes which population is described

Three rules settle repeated code:

- Two steps performing the same operation, on the same inputs, with the same settings are one node. Record in `operation` that the computation is duplicated, since nothing keeps two copies in agreement.
- The same code applied to different inputs is two nodes, because the inputs are what is being checked.
- A function definition called from several places is one node; each call site is an additional node, because what is passed in differs.

## The region a node occupies

Every node occupies a contiguous region of the file, delimited by a first and a last line copied verbatim from the source. The region is what a reviewer will read.

A region may contain statements that are not themselves nodes: a reshape, a rename, an intermediate object that only carries a result to the next line. Those are absorbed into the node whose decision they serve, and the region is what makes the absorption visible.

- The region runs from `start_anchor` to `end_anchor` inclusive and must be contiguous. It may contain blank lines, comments, and statements that are not nodes.
- Regions must not overlap, and rows must be listed in source order.
- A statement that falls outside every region is a claim that it belongs to no node. Make sure that claim is one you intend.
- Do not substitute a shorter region just to obtain a prettier end line.

## Columns

- **id**: script.quantity, stable and unique
- **script**: filename
- **section**: the existing section header the node falls under. Leave empty if the script has no section headers.
- **start_anchor**: the first line of the node's region, copied exactly. Never a line number.
- **start_context**: a distinctive line above `start_anchor`; fill in only when `start_anchor` alone is not unique in the file
- **end_anchor**: the last line of the node's region, copied exactly. Equal to `start_anchor` when the node is one line.
- **end_context**: a distinctive line above `end_anchor`; fill in only when `end_anchor` alone is not unique in the file
- **inputs**: semicolon-separated node ids consumed, or `INPUT:<filename>` for a file read from disk. Where a node consumes something produced by a script that was not supplied, record the file it reads as `INPUT:<filename>` rather than inventing an id.
- **grain_in, grain_out**: what one row means on each side, e.g. gear x bay x season x year x species. For a node that reads a file from disk, `grain_in` describes the file as stored.
- **units_in, units_out**: counts, individuals, an index, a proportion, a ratio, and so on
- **operation**: one sentence: what it does and why
- **settings**: the decisions embedded in it: thresholds, target levels, bounds, tie-breaks, seeds, arguments that change what is computed
- **na_behavior**: what happens when the operation cannot produce a value, and whether the causes are distinguishable downstream. If a function returns a missing value for several different reasons that collapse into one NA, say so explicitly.
- **checked, verdict, notes**: leave all three empty

## Anchor rules

The anchors are how a person and a script find this node in the file later, so they have to survive editing and be findable mechanically. These rules apply to `start_anchor` and `end_anchor` alike.

- Copy the line from the source verbatim, including its indentation and its trailing comma or pipe. Do not retype it, do not tidy the spacing, and do not translate `%>%` to `|>` or add or remove `dplyr::`.
- An anchor is one complete line of code. It contains no line numbers, no file paths, and no `#` comment text.
- **If the region's first line carries a trailing comment**, move down to the first line below it that carries none and use that as `start_anchor`, then record the region's true first statement in `operation`. If the region's last line carries a trailing comment, move up in the same way. This is the only case in which an anchor is not the literal first or last line of the region.
- Each anchor must be unique within its file, or else be paired with a context line that makes the pair unique. Short generic lines (`group_by(gear, YEAR) |>`, `summarise(n = sum(n), .groups = "drop")`, `mat <- do.call(rbind, res)`) usually are not unique. Before choosing one, check whether the same text appears elsewhere in the file.
- A context line must itself appear above its anchor and must be distinctive, usually the assignment that opens the block.
- `end_anchor` will often be a closing line such as `)` or `.groups = "drop")`, which is rarely unique. That is expected: keep it and fill `end_context` with the region's `start_anchor` or another distinctive line above it.
- Prefer lines unlikely to be reformatted. An assignment with a named function call is stable; a long line a formatter might wrap is not.
- Avoid lines containing double quotes where you can, since the CSV must escape them and a hand-edited table is easy to break. Where unavoidable, escape them properly for CSV.

## Rules for the descriptive columns

- Describe what the code does, not what it should do. Where the code and its comments disagree, say so in `operation` rather than choosing one.
- Where a region absorbs a statement that is not itself a node, say in `operation` why it was absorbed, in one clause. A reshape, a rename, or an object that only carries a result forward is absorbed; a threshold, a join, or an aggregation is not.
- Where you cannot tell what a quantity means from the code alone, write the question in `operation` rather than guessing.
- Where the same operation on the same inputs occurs at several places, and is therefore one node, the anchors delimit the first occurrence and the first line of each additional occurrence is quoted verbatim inside `operation`. If an additional occurrence is in a different file, name the file with it.

## Granularity

A script of about 800 lines typically yields 10 to 20 nodes. If you are producing many more, the granularity is too fine: merge neighbours and let the regions grow. If you are producing many fewer, regions are absorbing decisions that should be visible as settings of their own. The count is a check on the enumeration, not a target.

## Output format

Return a single CSV. First row is the header, in the column order listed above. Comma-delimited, with fields containing commas, double quotes, or newlines quoted and internal double quotes doubled. No commentary before or after the CSV.

## Before you finish

Check each anchor against the source by searching the file text for the exact string, not by eye. Confirm that:

- every `start_anchor` and `end_anchor` string occurs in the file it names
- each is unique in that file, or has a context line that makes the pair unique
- each `end_anchor` occurs at or after its `start_anchor`
- no two regions overlap
- every id in `inputs` is either an id in this table or an `INPUT:` reference

After the CSV, list any anchor you could not make unique and any check above that failed. Do not silently adjust a region to make a check pass.
