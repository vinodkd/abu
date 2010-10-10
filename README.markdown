Abu: A scripting language for Hadoop
=====================================
Abu is a language that helps in writing Hadoop map reduce jobs by extracting out the essence of the map reduce logic into a DSL.
Scripts written in the abu DSL can then be:
    - "compiled" into standard java boilerplate to be run on hadoop (sans the actual method implementations)
    - visualized using Graphviz
    
Abu achieves both goals by generating text - java in the case of "compile" and graphviz source files (in dot format) in the case of "visualize"; so its less of a true DSL, and more of a code generator. However, it helps to think of it in terms of a scripting language as the expectation is that you'd spend most of your "map reduce logic and flow planning" time in abu rather than in java boilerplate land.

Abu does require you to know about Hadoop, and actually is intended as a learning tool for Hadoop; not a replacement. It in fact started as a personal attempt at grokking map reduce at a high level while learning Hadoop. Abu is not turing complete and doesnt allow definition of the actual map and reduce functions themselves - just their interface contracts and how they combine with each other. Abu output will therefore contain skeletons of the map and reduce functions, and you will still have to fill them in.

Having said that, its conceivable that some point in the future it does allow such definition, specifically via the (J)Ruby syntax.How this will actually work - TBD

Goals:
======
- no boilerplate, just the core logic
- still looks like map reduce, ie, not high level like Pig
- can generate boilerplate on request
- generate dot format output so that it can be easily visualized
- analyses i/o and ensures correctness at dsl level

- repl? dont know yet

Running Abu
===========
In a bash environment, run the following after downloading Abu:
    cd ruby
    ./abu.sh <<script.abu>> <<output dir>> gen  # to generate java
    ./abu.sh <<script.abu>> <<output dir>> viz  # to generate a graphviz diagram of your script
    ./abu.sh <<script.abu>> <<output dir>> gen viz  # to generate both

Developer Guide
===============
Codebase Contents
-----------------
	doc	- Core idea and design documents
	java	- contains the source to the java parser for Abu. Very early stage
	ruby	- contains the source to the ruby version of Abu.
	  - test	- contains some test scripts in the ruby syntax.
	viz	- contains trial runs of creating map reduce diagrams at varying detail manually. Will be used as templates for the viz generator.



