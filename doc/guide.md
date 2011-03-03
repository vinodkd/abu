Using Abu
===========
Getting Started
---------------
### Download and install Abu

Tutorial
---------------
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
        ./abu script.abu /output/dir gen  # to generate java
        ./abu script.abu /output/dir viz  # to generate a graphviz diagram of your script: Note viz is still being written
        ./abu script.abu /output/dir gen viz  # to generate both

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

Similarly running

Abu Syntax
----------
Abu scripts consist of two types of statements: jobs and steps. [Note: current code uses 'block's for 'job's, and the terms can be used interchangeably]

A *job* is essentially a function definition. It has a name, some arguments and a body. Job Blocks are used for the main job, and definitions of mapreduce jobs that the main one calls. The following types of jobs are defined in Abu:
   - job: which stands for the main hadoop job to be invoked. There can be only one per script.
   - mapreduce: which stands for any grouping of map and reduce steps.
The general syntax for jobs are:
	
	[job|mapreduce] :job_name do
		<<steps....>>
	end

A *step* is, obviously, one of the steps within a job.The following steps are defined in Abu:

   - read	: which allows reading of data into the job (allowed only within 'job')
   - write	: which allows writing of data from the job (allowed only within 'job')
   - <name>	: where <name> is the name of a defined mapreduce job, and represents invocation of that job (allowed only within 'job')
   - exec <name>: which is the same as above, except explicitly called out as an execution (allowed only within 'job')
   - map	: which allows a map operation to be defined for execution (allowed in both job and mapreduce)
   - reduce	: which allows a reduce operation to be defined for execution (allowed in both job and mapreduce)
   - hadoop	: which allows invoking existing hadoop jobs from within Abu.
   - java	: which allows embedding java code into Abu scripts
   
  The syntax for each is defined below:
  * read: 
  	read 
   
Generating Code
---------------
Generating Visualization(s)
---------------------------
