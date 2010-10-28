Abu: A scripting language for Hadoop
=====================================
<img src="http://github.com/vinodkd/abu/raw/master/doc/abu.jpg" align="left" width="250" height="250"/> Abu is a language that helps in writing Hadoop map reduce jobs by extracting out the essence of the map reduce logic into a DSL.
Scripts written in the abu DSL can then be:

- "compiled" into standard java boilerplate to be run on hadoop (sans the actual method implementations)
- visualized using Graphviz
    
Abu achieves both goals by generating text - java in the case of "compile" and graphviz source files (in dot format) in the case of "visualize"; so its less of a true DSL, and more of a code generator. However, it helps to think of it in terms of a scripting language as the expectation is that you'd spend most of your "map reduce logic and flow planning" time in abu rather than in java boilerplate land.

Abu does require you to know about Hadoop, and actually is intended as a learning tool for Hadoop. It in fact started as a personal attempt at grokking map reduce at a high level while learning Hadoop. Abu is not turing complete and doesnt allow definition of the actual map and reduce functions themselves - just their interface contracts and how they combine with each other. Abu output will therefore contain skeletons of the map and reduce functions, and you will still have to fill them in.

Having said that, its conceivable that some point in the future it does allow such definition, specifically via the (J)Ruby syntax.How this will actually work is  WIP.

Goals:
======
- no boilerplate, just the core logic
- still looks like map reduce, ie, not high level like Pig
- can generate boilerplate on request
- generate dot format output so that it can be easily visualized
- analyses i/o and ensures correctness at dsl level


Using Abu
===========
See [the user guide](abu/blob/master/doc/guide.md)

Roadmap
=======
See [the roadmap](abu/blob/master/doc/roadmap.md)

Developers Guide
=================
   - See [the codebase contents guide](abu/blob/master/CONTENTS.md), and 
   - Read [Abu's Design] (abu/blob/master/doc/roadmap.md)
   - ...but for the most part, use the source :)

About the name
==============
I first intended to name this tool Ankush - the sanskrit name for the tool that real mahouts use to control elephants, especially as it made sense to me - this was a tool to help me understand and control the hadoop elephant. Another thought was to name it using the Doug Cutting Method(TM) - by asking my kids for one. That backfired because I couldnt get anything coherent (or sufficiently cute) even out of my 3.5 yr old. 
So I started looking at elephants that kids knew about. Dumbo seemed somehow inappropriate, but [Abu the monkey-turned-elephant from Alladin seemed to fit. So there you go :)

#### Disclaimer
The picture of Abu is from http://disney.wikia.com/wiki/Aladdin. No copyright infringement is intended with its use here. If you own the image and want it taken down, please let me know.