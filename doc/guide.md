Using Abu
===========
Getting Started
Tutorial
Abu Syntax
Generating Code
Generating Visualization(s)

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
