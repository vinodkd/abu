Abu Syntax Design 
==================
Sample scripts/ Original Ideas
-------------------------------

1. Simple job:

		job job1:
		    read    (k1:type,v1:type) from "/path/to/file.ext"  using DataReaderClassName
		    map     (k1:type,v1:type) to    (k2:type,v2:type)   using mapClassname 
		    reduce  (k2:type,v2:type) to    (k2:type,v2:type)   using redClassname
		    write   (k3:type,v3:type) to    "/path/to/file.ext"     using DataWriterClassName

2. Simple job with mapred abstracted out and named:

		job job1:
		    read    (k1:type,v1:type) from "/path/to/file.ext"  using DataReaderClassName
		    mr1 (k1:type,v1:type) to    (k3:type,v3:type)
		    write   (k3:type,v3:type) to    "/path/to/file.ext"     using DataWriterClassName

		mapreduce mr1:
		    map     (k1:type,v1:type) to    (k2:type,v2:type)   using mapClassname 
		    reduce  (k2:type,v2:type) to    (k2:type,v2:type)   using redClassname

3. Chained job:

		job job1:
		    read    (k1:type,v1:type) from "/path/to/file.ext"  using DataReaderClassName
		    mr1 (k1:type,v1:type) to    (k3:type,v3:type)
		    mr2 (k3:type,v3:type) to    (k5:type,v5:type)
		    write   (k5:type,v5:type) to    "/path/to/file.ext"     using DataWriterClassName
		// mr1 same as before
		mapreduce mr2:
		    map     (k3:type,v3:type) to    (k4:type,v4:type)   using mapClassname 
		    reduce  (k4:type,v4:type) to    (k5:type,v5:type)   using redClassname

4. mapred defn with optional reducer:

		mapreduce mr34:
		    map     (k3:type,v3:type) to    (k4:type,v4:type)   using mapClassname 

5. mapred defn with optional mapper:

		mapreduce mr43:
		    reduce  (k4:type,v4:type) to    (k5:type,v5:type)   using redClassname

6. Tuple definitions: 

   - Dont care value in tuple: (_, field2, field 3)
   - List of objects of a type: [type] or [var] where var of type 'type'

Mapping the concept to parseable syntax
---------------------------------------
### Round 1:
    job1:
        in: 
        mr1
        mr2
        out:

    mr1:
        map: [k1 # v1] -> [k2 # v2] using mapperclass 
        reduce: [k2 # {v2}] -> [k3 # v3] using reducerClass

    mr2:
        in:
        map:
        reduce:
        out:

This was expected to be easy to output into dot files (as its mostly a line oriented format), but in practice couldnt actually be converted easily due as subgraphs were needed to generate anything good looking on graphviz.

### Round 2:

This is the format that the java parser is expected to be able to understand.
    job job1:
        read    (k1:type,v1:type) from "/path/to/file.ext"  using DataReaderClassName
        mr1 (k1:type,v1:type) to    (k3:type,v3:type)
        write   (k3:type,v3:type) to    "/path/to/file.ext"     using DataWriterClassName

    mapreduce mr1:
        map     (k1:type,v1:type) to    (k2:type,v2:type)   using mapClassname 
        reduce  (k2:type,v2:type) to    (k2:type,v2:type)   using redClassname

#### Grammar for this syntax:

    job:= ["job"|"run"|"flow"] spc <jobname> ":" nl tab <set spec>* nl tab <input spec> nl tab [<mapreddef>| <mapredref>]+ nl tab <output spec>
    jobname:= <identifier>
    set spec:= "set" <name> "=" <value>
    input spec:= "in" spc <pathspec> "as" <tuplespec> using "fqcnspec"
    mapredspec:= "mapreduce" <identifier> ":" nl tab <mapredcombospec>+
    mapredref:= <identifier>
    output spec:= "out" spc <pathspec> using "fqcnspec"

### Round 3:

I spent some time working on the java parser, and one day realized that it might be easier to generate a the first version of Abu using Ruby than Java, so settled on a simpler-to-parse-with-ruby syntax. Its structurally similar to round 2 syntax, but with additions required for the ruby parser to work with it.

    job "job1" do
        read "LongWritable","Text","/path/to/file.ext", "DataReaderClassName"
        exec "mr1","LongWritable","Text","Text", "IntWritable"
        write "Text", "IntWritable", "/path/to/file.ext", "DataWriterClassName"

        mapreduce "mr1" do
            map "LongWritable","Text","Text", "IntWritable", "Mapper"
            reduce "k2","v2", "k3","v3", "reducer"
        end
    end

The good part about this was that it enabled me to do the code generation part easier than java, and therefore prove out the idea. It also opened up the possiblity of making Abu into a true scripting language for hadoop, ie being able to write the map and reduce functions themselves in jruby, and therefore making them runnable in hadoop directly. This is just an idea at this point, however; and needs fleshing out. Whats really promising is the presence of the jrubyc compiler that could be used to produce Java code from the JRuby MR source.

The intention at this point is to continue both java and (j)ruby development in parallel in the expectation that:
   - The java version will provide the most natural syntax, and the least external dependencies and therefore will be attractive on its own
   - The jruby version will be easy to prove out, and might be the winner assuming the jruby+java compile will allow for a standalone solution of its own

Gaps in Design so far:
---------------------
   - Syntax doesnt follow DRY. Since the read statment already defines the input key-value pair, the subsequent map,reduce or mapreduce executions wouldnt need this specified again.

Implementation Design
=====================

Overall Algorithm:
-----------------
### Parse:

1. Parse the input file into a parse tree
2. In parallel, maintain a table of mapreduce jobs references so that they can be mapped to their definitions. The table should have the following structure: (mapredname, refFound?,defnFound?)
3. After the parse process, check the ref table.
    a. If there's any name with a refFound and no defnFound, throw an error as this is a mapred job without a definition
    b. If there's any name with a defnFound and no refFound, throw a warning that a job is unused.
4. <<Insert logic to check if the chaining of keys and values match up here>>. We dont support includes yet.

### Generate:
Enable choosing the version of hadoop to generate.

### Visualize
TBD

Ruby Specifics
--------------
- Class Abu:
   - parse       : private method that takes the dsl and "understands" it
   - generate    : method that generates java code from the dsl that was parsed
   - visualize   : method that generates graphviz dot format output from the dsl that was parsed.
   - run     : future method that will allow actual running of the script as is
- Module Templates: contains templating logic
      - allow file references
      - allow partials
- Template files: erb files that contain the templates themselves

Redesign thoughts:

- Have each abu command "know" how to parse, gen and viz itself. That way the main class can plug behavior.in
   - issue: some generation tasks, esp viz, might require non-local behavior, or a combo of local and non-local. We will still need some template at the top level. 
- Create an AbuGrammar that ensures grammar is maintained; right now pretty easy to create scripts that will pass parse but be wrong

Note to self: The "parser" can be made a validating one - in then sense of 'read' can show up only under 'job' - by making each parent 'method' a class on its own, and making the valid methods instance_eval'd (or class_eval'd) in that class
    
Java Specifics
--------------
- Class Abu       : main runner
   - generate    : method that generates java code from the DSL that was input
   - visualize   : method that generates graphviz dot format output from the dsl that was input
- Class AbuParser     : Parboiled-based PEG parser for Round 2 syntax
- Class JavaGenerator : Generator for Java classes
- Class DotGenerator  : Generator for dot output

JRuby Specifics:
----------------
The idea is to have a hadoop script described completely in (j)ruby synatax - including bodies of map and reduce, runnable like so:

    bin/hadoop abu.jar -script xyz.abu --inputs /path/to/input --output /path/to/output #should cause the generic handler in abu.jar to be kicked off

this should then:
   
   - create a job conf based on the script's structure
       - use jobcontrol
       - in the tool.run, run abu.parse to get the ast, and loop through the ast to create the jobs (this should be doable in jruby itself)
       - kick off the jobcontrol.run from jruby (or java), and have it call the ruby map/reduce functions as defined below.
   - define the map and reduce via jruby and execute them: this can be done by defining a primordial mapper and reducer that takes the script as a param, executes its map or reduce, and translates its output (to/from writeable & readable) 
    
 
