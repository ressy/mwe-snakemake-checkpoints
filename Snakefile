"""
Checkpoints!

Adapted from:
https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#data-dependent-conditional-execution
"""

# Adding these in so it doesn't get confused if you try manually requesting
# specific files, for example, "snakemake post/a/1.txt" will now complain about
# a missing input instead of looking for a sample named "a/1.txt"
wildcard_constraints:
    sample="[a-z]+",
    i="[0-9]+"

rule all:
    """A target rule to define the desired final output.
    
    The checkpoint magic happens independently for both a and b.
    """
    input:
        "aggregated/a.txt",
        "aggregated/b.txt"

def aggregate_input(wildcards):
    """Define inputs for aggregate rule, from actual outputs of checkpoint.

    This uses the directory output of the clustering checkpoint to determine
    the actual files present in that directory, and then requests files from
    *another* directory (see the intermediate rule) as inputs.  Note that the
    checkpoint logic does not handle this itself in any way.  It just tracks
    when the rule has been run (via the
    snakemake.exceptions.IncompleteCheckpointException) and re-evaluates the
    DAG afterwards to figure out what existing files can be matched to what
    requested inputs.

    According to the actual flow of files, per sample it goes:
    clustering -> intermediate -> aggregate
    clustering/{sample}/{i}.txt -> post/{sample}/{i}.txt -> aggregated/{sample}.txt

    For sample a:
    clustering/a/1.txt -> post/a/1.txt ----> aggregated/a.txt
    clustering/a/2.txt -> post/a/2.txt --'
    clustering/a/3.txt -> post/a/3.txt --'

    Without the checkpoint directive, the aggregate rule would ask for the
    files under post/a/ as input, and the intermediate rule could offer them as
    outputs, but have no idea where to find its own inputs in turn.
    """
    # output here is a list of outputs, which in our case is just a single
    # directory, "clustering/a" for sample a
    checkpoint_output = checkpoints.clustering.get(**wildcards).output[0]
    # Just a format string, "clustering/a/{i}.txt"
    pattern = os.path.join(checkpoint_output, "{i}.txt")
    # Extract the values for i, so we'll get back [1, 2, 3]
    # Just a snakemake convenience function for pattern-matching
    # https://snakemake.readthedocs.io/en/stable/project_info/faq.html#how-do-i-run-my-rule-on-all-files-of-a-certain-directory
    i=glob_wildcards(pattern).i
    return expand("post/{sample}/{i}.txt",
           sample=wildcards.sample,
           i=i)

rule aggregate:
    """An aggregation over all produced clusters.
    
    The input function's use of the get method from the checkpoint object
    triggers the special behavior.
    """
    output:
        "aggregated/{sample}.txt"
    input:
        aggregate_input
    shell:
        "cat {input} > {output}"

rule intermediate:
    """An intermediate rule.
    
    This rule uses the files created by the clustering checkpoint, but the
    output from that checkpoint is technically the directory.  Does snakemake
    know these two are wired together in the DAG?  I don't think so.
    Visualizing with --dag before running produces a graph that just says
    clustering -> aggregate -> all.  Calling with --dag after produces a graph
    that starts from this intermediate rule and shows each individual file, but
    no hint as to where they came from.

    Why this rule at all, and not just clustering -> aggregate?  In that
    situation we could just stick with the directory-as-output idea and not
    worry about going per-file.  But if we want Snakemake to handle tasks
    specific to the separate files while managing the surrounding DAG,
    we need the checkpoint feature.
    """
    output: "post/{sample}/{i}.txt"
    input: "clustering/{sample}/{i}.txt"
    shell: "cp {input} {output}"

checkpoint clustering:
    """The checkpoint that shall trigger re-evaluation of the DAG.
    
    I modified this so we see a different number of output files depending on
    the sample, just to drive home the point.
    """
    output: clusters=directory("clustering/{sample}")
    input: "samples/{sample}.txt"
    shell:
        """
            mkdir clustering/{wildcards.sample}
            if [[ {wildcards.sample} == "a" ]]; then
                for i in 1 2 3; do echo $i > clustering/{wildcards.sample}/$i.txt; done
            else
                for i in 1 2; do echo $i > clustering/{wildcards.sample}/$i.txt; done
            fi
        """

rule clean:
    shell: "rm -rf clustering/ post/ aggregated/"
