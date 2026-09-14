#!/bin/sh
# Build the PDF. Requires pandoc and a LaTeX installation.
pandoc QA_Protocol.md \
  --metadata-file=metadata.yaml \
  --toc --toc-depth=2 \
  -o QA_Protocol.pdf
