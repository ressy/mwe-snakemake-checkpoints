# Minimal Working Example - Snakemake Checkpoints

I had a much harder time than I expected wrapping my head around how
[Snakemake](https://snakemake.readthedocs.io/) implements its checkpoint
system, so I added notes to make it clearer to me.  The [Snakefile](Snakefile)
here is derived from 
[the clustering example in the documentation](https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#data-dependent-conditional-execution).
See the docstrings in the Snakefile for notes.

The DAG looks different depending on what files are available; before running
anything, Snakemake knows the aggregate rule depends on clustering in some way
but not specifically how.

![DAG Before][DAG Before]

After clustering runs the aggregate rule knows what input files it needs from
the intermediate rule, but *doesn't* actually reference the clustering
checkpoint.  The files are just taken as initial inputs as though they were
supplied at the start.

![DAG After][DAG After]

[DAG Before]: dag_before.svg
[DAG After]: dag_after.svg
