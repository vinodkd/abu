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
Abu has two syntaxes - the original, and the ruby adapted one. As on date, the original is still a WIP, so presented here is the Max temperature example from Hadoop:The Definitive Guide written as a ruby abu script:

		job 'MaxTemperature' do
			read 'LongWritable','Text','/path/to/file.ext', ''
			execute 'max_temp','LongWritable','Text','Text', 'IntWritable'
			write 'Text', 'IntWritable', '/path/to/file.ext', ''
		end

		mapreduce 'max_temp' do
			map 'LongWritable','Text','Text', 'IntWritable', ''
			reduce 'Text', 'IntWritable','Text', 'IntWritable', ''
		end

In a bash environment, run the following after downloading Abu:

	    cd ruby
	    ./abu.sh script.abu /output/dir gen  # to generate java
	    ./abu.sh script.abu /output/dir viz  # to generate a graphviz diagram of your script: Note viz is still being written
	    ./abu.sh script.abu /output/dir gen viz  # to generate both

'gen' produces the following java file:

		import org.apache.hadoop.conf.Configuration;
		import org.apache.hadoop.fs.Path;
		import org.apache.hadoop.io.*;      // kludge; should be fixed in future with imports to types used in script.
		import org.apache.hadoop.mapreduce.Job;
		import org.apache.hadoop.mapreduce.Mapper;
		import org.apache.hadoop.mapreduce.Reducer;
		import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
		import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

		import java.io.IOException;

		public class Maxtemperature {

		static class Max_tempMapper extends Mapper<LongWritable,Text,Text,IntWritable> {
		    public void map(LongWritable key,Text value, Context context)   throws IOException, InterruptedException {
			// your code goes here
		    }
		}

		static class Max_tempReducer extends Reducer<Text,IntWritable,Text,IntWritable> {
		    public void reduce(Text key, Iterable<IntWritable> values, Context context)    throws IOException, InterruptedException {
			// your code goes here
		    }
		}

		    public static void main(String[] args) throws Exception {

			// your code goes here
			Job job = new Job();
			job.setJarByClass(Maxtemperature.class);

			FileInputFormat.addInputPath(job, new Path("/path/to/file.ext"));

				job.setMapperClass(Max_tempMapper.class);

				job.setReducerClass(Max_tempReducer.class);

			FileOutputFormat.setOutputPath(job, new Path("/path/to/file.ext"));
			job.setOutputKeyClass(Text.class);
			job.setOutputValueClass(IntWritable.class);

			System.exit(job.waitForCompletion(true) ? 0 : 1);
		    }
		}
.. which you can then add implementations to, and run in Hadoop.

Codebase Guide
==============
<table>
  <tr>
    <th>Directory</th><th align="left">Description</th>
  </tr>
  <tr>
    <td>doc</td><td> Core idea and design documents</td>
  </tr>
  <tr>
    <td>doc/Idea.txt</td><td> Original writeup of the idea</td>
  </tr>
  <tr>
    <td>doc/Design.txt</td><td> Demonstrates evolutoin of the design</td>
  </tr>
  <tr>
    <td>java</td><td> contains the source to the java parser for Abu. Very early stage</td>
  </tr>
  <tr>
    <td>ruby</td><td> contains the source to the ruby version of Abu.</td>
  </tr>
  <tr>
    <td>  - test</td><td> contains some test scripts in the ruby syntax.</td>
  </tr>
  <tr>
    <td>viz</td><td> contains trial runs of creating map reduce diagrams at varying detail manually. Will be used as templates for the viz generator.</td>
  </tr>
  </table>

About the name
==============
I first intended to name this tool Ankush - the sanskrit name for the tool that real mahouts use to control elephants, especially as it made sense to me - this was a tool to help me understand and control the hadoop elephant. Another thought was to name it using the Doug Cutting Method(TM) - by asking my kids for one. That backfired because I couldnt get anything coherent (or sufficiently cute) even out of my 3.5 yr old. 
So I started looking at elephants that kids knew about. Dumbo seemed somehow inappropriate, but [Abu the monkey-turned-elephant from Alladin seemed to fit. So there you go :)

#### Disclaimer
The picture of Abu is from http://disney.wikia.com/wiki/Aladdin. No copyright infringement is intended with its use here. If you own the image and want it taken down, please let me know.