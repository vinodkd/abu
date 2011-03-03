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

### Round 4:

Post the CHUG presentation, I'm revisiting the script syntax to see how:
   
   - the syntax can be made more concise (DRY-er) by removing repetitions, eg, k2,v2 from a map should be the same as k3, v3 for the subsequent reduce. Why mention it again?
   - remove some of the need for quotes	- nominally done
   - another minor annoyance: abu currently makes up the names of the keys and values for you; it could use the names you provide.The original syntax has provision for this, but the implementation doesnt use it.
   - can exec be removed, and the name of the mr job directly be used? need to see if possible to implement.But it would be nice if so. - nominally done
   - existing map reduce jobs can be represented in abu as a migration path - nominally done.
   - provide java "trapdoors" at any point in the script

Here goes solutions for these requirements:

#### Remove repetitions:

Each abu command that takes KV-pairs could potentially assume the input as the output from the previous step. So something like

        read "LongWritable","Text","/path/to/file.ext", "DataReaderClassName"
        exec "mr1","LongWritable","Text","Text", "IntWritable"

Could be written as:

        read "LongWritable","Text","/path/to/file.ext", "DataReaderClassName"
        exec "mr1","Text", "IntWritable"	# code assumes input from read step is what's being fed into mr1
        
#### Removing need for quotes: 
Most of the quoted strings could be replaced by ruby symbols quite easily, like so:

     job :job1 do
         read :LongWritable,:Text,"/path/to/file.ext", "DataReaderClassName" 	# class names probably dont directly map to symbols unless quoted methinks
         mr1 :Text, :IntWritable

#### Allowing user-supplied variable names to be output: 
This should allow steps like the following to be generated correctly with variable names from the script, and shown on the visualization.

	read "k1:LongWritable","v1:Text","/path/to/file.ext", "DataReaderClassName"

   This, of course means that symbols cannot be used when variable names are required.

#### Remove exec: 
This is pretty straightforward to understand; implement might not be so. But here goes the syntax anyways.

     job :job1 do
         read :LongWritable,:Text,"/path/to/file.ext", DataReaderClassName" 	# class names probably dont directly map to symbols unless quoted methinks
         mr1 :Text, :IntWritable	#abu presumably figures out that this yet-unknown command is actually a mapreduce job defined later
         write "/path/to/file.ext"

         mapreduce :mr1 :LongWritable,:Text,:Text, :IntWritable		# not sure if this is valid ruby syntax. i do need to parameterize the inputs to the job.
             map :Text, :IntWritable, "Mapper"	# again mapper classname may not map to a symbol name.
             reduce :Text, :IntWritable "reducer"
         end
     end
     
#### Representing existing jobs in abu: 
In coming up with a command to represent jobs that exist already, I am in a quandry as to how to scope it.

   - How deep should the integration be? Should abu inspect the job, and figure out the ins and outs, or should it merely start a new shell and exec it hoping things work out?
   - Hadoop jobs come in many flavors - plain old java, streaming, pig, hive - to name a few. So  Should I go narrow and have one command per type of existing job, or should I have an umbrella command? That is, should it be something like:

	    jar "jarname",:k1,:v1,:k2,:v2
	    streaming "cmdline",:k1,:v1,:k2,:v2
	    pig <<pig specific launch spec>>,:k1,:v1,:k2,:v2
	    hive <<hive specific launch spec>>,:k1,:v1,:k2,:v2
    
   Or, something like:
	
	    external_job [jar|stream|pig|hive|other] <<launch spec>>,:k1,:v1,:k2,:v2

   Note: the kv pairs will be required as Abu probably will not be able to divine them from just the name of the external job
	
   The former is unattractive as there's no common thread tying them together conceptually while Abu will internally treat them as such; and the latter is unattractive as I might have to still tell Abu the type of the job!

   So for now I've settled on a generic "hadoop" command name, which will merely spawn a new process and exec whatever command you provide, using the key value spec provided to validate the presence of that job within the overall flow. Like so:
	
	    hadoop "cmd line",:k1,:v1,:k2,:v2
	    
   All connecting of the outputs from the previous step to this one, and the outputs of this step to the next abu step are assumed to be handled by the user. Presumably the hadoop step will be surround by a write/read pair, or the outputs are readily available via HDFS - abu pretends it will work out :)
   
   I've created another project - Magic Carpet - to work on the deep integration aspect. Specifically it should allow for hadoop jar jobs to be converted directly into abu scripts.
	
#### java inclusion: 
Java code can be logically included at quite a few places in the generated code:

* In place of the java classname anywhere the syntax accepts classnames. This is an easy fix.
* In the scope of of overall job, ie global to both the inner map and reduce classes, which further be refined as:
  * in the class scope
  * in main()'s scope
* in the scope of the individual map and reduce classes, with the same refinement possible.

   So one idea I had was a syntax like so:

      java :LOCATION %q{
        // java code here
      }

   where location can be:

   - :at_class => code in heredoc will be put at the top of the class generated.For job, this will be at the top of the overall class, for map/reduce classes it will be at the top of the corresponding class
   - :at_main => code in heredoc will be put at the top of the current container's main function. for job this will be the top of main(), for map/reduce this will be top of the generated map or reduce method.
   - :here => code in heredoc will be put at the point where it appears. If it appears in the main job, it will be put into that place in main(). If it appears in a mr job, it will appear as code at that point in the key method (map or reduce). Need to see how this will play out. At least for code in main(), this should be the default, and therefore shouldnt typically need location specified.
   - :after => Not sure if this will be ever needed, but code in heredoc will be put at the bottom of the current container's main function. For job, this will be the bottom of main(), for map/reduce this will be the bottom of the generated map or reduce method.

   The other idea is to omit the location param and figure out the location from context. That is, If the java command is:
   - the first one in a job block, then it does the same thing as :at_class
   - the second one in a job block, then it does the same thing as :at_main
   - any subsequent blocks are considered :here specified, so will behave as such
   - for map and reduce blocks, there will be java_at_main and java_at_class attributes instead
   - the last java command in the block will be treated as if :after specified. Will need special code to prevent the last java command from being treated as a :here block.
	   
##### Implementation notes:

   - I could start with the first implementation, and refine it to the second.
   - When implementing the implicit locations, I could probably have an intermediate step where all the java commands are tagged with location internally, and with two-pass logic, replace the last :here command with :after.
   
Here is one abu script that includes all the syntax changes from above:
    
    job :job1 do
    	java :at_class %q-{
    		static int ACONST = 42;
    	}
    	java :at_main %q-{
    		System.out.println("Starting hadoop job...");
    	}
        read :LongWritable,:Text,"/path/to/file.ext", DataReaderClassName" 	# class names probably dont directly map to symbols unless quoted methinks
        java %q-{
        	log.debug("done reading file");
        }
        mr1 :Text, :IntWritable
        hadoop "hadoop jar plain-hadoop-job.jar --input input.txt --output output.txt" :LongWritable,:Text,:LongWritable,:Text,
        				# for gen: this should actually chain jobs, not call the jar's main.
        				# for viz: it should basically parse the job, and represent it. maybe viz should just leave it as a black box.
        write "/path/to/file.ext", :java => %q{
        	// writer code goes here
        }

        mapreduce :mr1 :LongWritable,:Text,:Text, :IntWritable,
            :java_at_class %q-{
            	// this is at class level
            	static int CONST=9999;
            },
            :java_at_main %q-{
            	System.out.println("Starting map");
            }
            map :Text, :IntWritable, "Mapper"	# again mapper classname may not map to a symbol name.
            reduce :Text, :IntWritable "reducer"
        end
    end
   

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

- Have each abu command "know" how to parse, gen and viz itself. That way the main class can plug behavior.in as needed.
   - issue: some generation tasks, esp viz, might require non-local behavior, or a combo of local and non-local. We will still need some template at the top level. 
- Create an AbuGrammar that ensures grammar is maintained; right now pretty easy to create scripts that will pass parse but be wrong
	Tech solution: The "parser" can be made a validating one (a la XMLGrammar example in The Ruby Prog Lang book pg 287 or thereabouts)- in then sense of 'read' can show up only under 'job' - by making each parent 'method' a class on its own, and making the valid methods instance_eval'd (or class_eval'd) in that class
    
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
    
 
