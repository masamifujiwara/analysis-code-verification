# A protocol for verifying ecological analysis code developed with AI assistance

<!-- After the first Zenodo release, paste the DOI badge here. -->

Masami Fujiwara
Department of Ecology and Conservation Biology, Texas A&M University

Analysis code is increasingly written with the assistance of large language
models. This creates a reporting problem: authors need to describe what they
did to assure the code's correctness, and reviewers need something they can
assess. "The code was reviewed by the authors" is neither specific nor
checkable.

This repository holds a protocol for verifying such code and for reporting that
verification, together with the scripts and prompts used to carry it out. It
assumes an analysis pipeline of the kind common in ecology, epidemiology, and
the environmental sciences: a series of scripts that read data, compute derived
quantities, fit models, and produce the tables and figures a manuscript
reports.

The protocol has two parts. **Part A** establishes that the reported numbers
came from a documented run and do not depend on the session, the machine, or
the moment they were produced. **Part B** enumerates every transformation the
pipeline performs on the way to a reported number and checks each one.

Nothing here is specific to AI-assisted code. The failure classes it addresses
occur in code written without AI assistance; what AI changes is their rate and
their location, not their kind.

## Contents

**The protocol**

| File | |
| --- | --- |
| `QA_Protocol.pdf` | The protocol. Start here. |
| `QA_Protocol.md` | Source for the PDF, in plain Markdown. |
| `metadata.yaml` | Title-page and typesetting settings for the build. |
| `build.sh` | Builds the PDF from the two files above. |

**Part A: scripts for a trustworthy run**

| File | |
| --- | --- |
| `run_pipeline.R` | Runs a pipeline end to end in a clean tree, recording the environment, every warning, and a checksum for every file produced. |
| `compare_runs.R` | Compares two such runs and reports what differs. |

**Prompts**

| File | |
| --- | --- |
| `node_table_prompt.md` | Drafts the Part B node table from an analysis script. |
| `variation_audit_prompt.md` | Finds sources of run-to-run variation that a text search cannot match (Part A, step 3). |

Both prompts produce material that must be read against the code before it is
used. See Sections 3.3 and 4.4 of the protocol for what may be delegated and
what may not.

## Quick start

Read the PDF first. To apply Part A to your own pipeline:

```sh
# 1. Edit the CONFIGURATION block at the top of run_pipeline.R:
#    the code folder, the results folder, the scripts in run order,
#    and the data files they read.

# 2. From the project root, run the pipeline twice.
Rscript qc/run_pipeline.R --label A
Rscript qc/run_pipeline.R --label B

# 3. Compare the two runs.
Rscript qc/compare_runs.R A B
```

Then repeat step 2 on a second machine and compare again. Sections 3.4 and 3.6
of the protocol explain why both comparisons are needed and what to do when
only one is affordable.

To rebuild the PDF you need `pandoc` and a LaTeX installation:

```sh
./build.sh
```

## Citing this work

This repository is archived on Zenodo, which mints a DOI for each release.
Please cite the deposit:

> Fujiwara, M. 2026. A protocol for verifying ecological analysis code developed
> with AI assistance. Zenodo. https://doi.org/10.5281/zenodo.XXXXXXX

Use the concept DOI, which resolves to the most recent version, unless you need
to identify a particular release. `CITATION.cff` carries the same information in
machine-readable form; GitHub's "Cite this repository" button and Zenodo both
read it.

## License

Everything in this repository, the document and the scripts alike, is licensed
under the [Creative Commons Attribution 4.0 International
License](https://creativecommons.org/licenses/by/4.0/) (CC BY 4.0).

You are free to share and adapt this material for any purpose, including
commercially, provided you give appropriate credit, indicate whether changes
were made, and link to the license. In published work, an ordinary citation
gives appropriate credit.

## AI disclosure

The protocol document was drafted with assistance from Claude Fable 5 and
revised with Claude Opus 5 between August and September 2026. The two R scripts
and both prompts were produced the same way. The models drafted and revised
text under the author's direction; every claim and every recommendation is the
author's, and the author is responsible for all of them. Section 0 of the
protocol states this in full.
