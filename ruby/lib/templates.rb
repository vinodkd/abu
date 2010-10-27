require 'erb'

module Templates
        
    TEMPLATES = {
            :JOB_IMPORTS => %q|
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.*;      // kludge; should be fixed in future with imports to types used in script.
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

import java.io.IOException;
|,
            :JOB_TOP => 'public class <%=@the_job.name.capitalize%> {
    ',
            :MR_MAP => %q|
    static class <%=name.capitalize%>Mapper extends Mapper<<%=step.k1%>,<%=step.v1%>,<%=step.k2%>,<%step.v2%>> {
        public void map(<%=step.k1%> key,<%=step.v1%> value, Context context)   throws IOException, InterruptedException {
            // your code goes here
        }
    }|,
            :MR_REDUCE => %q|
    static class <%=name.capitalize%>Reducer extends Reducer<<%=step.k2%>,<%=step.v2%>,<%=step.k3%>,<%step.v3%>> {
        public void reduce(<%=step.k2%> key, Iterable<<%=step.v2%>> values, Context context)    throws IOException, InterruptedException {
            // your code goes here
        }
    }|,
            :JOB_MAIN_TOP => %q|
        public static void main(String[] args) throws Exception {

            // your code goes here
            Job job = new Job();
            job.setJarByClass(<%=@the_job.name.capitalize%>.class);|,
            :JOB_READ => %q|
            FileInputFormat.addInputPath(job, new Path("<%=step.path%>"));|,
            :JOB_MAP => %q|
            job.setMapperClass(<%=mrdef.name.capitalize%>Mapper.class);|,
            :JOB_REDUCE => %q|
            job.setReducerClass(<%=mrdef.name.capitalize%>Reducer.class);|,
            :JOB_WRITE => %q|   
            FileOutputFormat.setOutputPath(job, new Path("<%=step.path%>"));
            job.setOutputKeyClass(<%=step.k3%>.class);
            job.setOutputValueClass<%=step.v3%>.class);|,

            :JOB_MAIN_BOTTOM => %q|
            System.exit(job.waitForCompletion(true) ? 0 : 1);
        }|,
            :JOB_BOTTOM => '}',

            :VIZ_JOB_TOP => %q|digraph G{
        node[shape=box style=rounded]
        //compound=true
        rankdir=TB
        //outputMode=nodesfirst
    |,
            :VIZ_JOB_BOTTOM => %q|
        label=\"Script:#{args[0].capitalize}\"
        labelloc=t
    }
    |,
            :VIZ_BLOCK_TOP => %q/
        subgraph cluster_#{args[0]}_SG{
            #{args[0]}_anchor [style=invis shape=point]
            headport=e/,

            :VIZ_BLOCK_BOTTOM => %q/
            labelloc=t
            label=\"#{args[1]} : #{args[0]}\"
        }

     /,
            # requires jobname before the read values
            # had to change the heredoc sigil to / from | as its used in the dot format.
            :VIZ_READ => %q/
            subgraph #{args[0]}_read_SG{
                rank=same
                #{args[0]}_read[shape=Mrecord, label=\"{#{args[3]}|{#{args[1]}|#{args[2]}}}\"]
            #{
            if args[4]!=''
                args[0] + '_' +args[4] + ' [shape=component]'
                args[0] + '_read -> ' + args[0] + '_' + args[4] + '[label=\"using\"]'
            end}
            }
    /,
            :VIZ_EXECUTE => %q/
            subgraph #{args[0]}_#{args[1]}_execute_SG{
                rank=same
                #{args[0]}_execute_#{args[1]} [label=\"Execute #{args[1]}\"]
                #{args[0]}_execute_anchor_#{args[1]} [style=invis shape=point]

                #{args[0]}_execute_anchor_#{args[1]} -> #{args[1]}_anchor[lhead=cluster_#{args[1]}_SG style=dashed arrowhead=box arrowtail=dot headport=e]
            }

    /,
            :VIZ_WRITE => %q/
            subgraph #{args[0]}_write_SG{
                rank=same
                #{args[0]}_write[shape=Mrecord, label=\"{{#{args[1]}|#{args[2]}}|#{args[3]}}\"]
            #{
            if args[4]!=''
                args[0] + '_' + args[4] + '[shape=component]'
                args[0] + '_write -> '+ args[0] + '_' + args[4] + '[label=\"using\"]'
            end}
            }
    /,
            :VIZ_MAP => %q/
            subgraph cluster_#{args[0]}_map_SG{
                #{args[0]}_map_input [shape=Mrecord label=\"#{args[1]}|#{args[2]}\"]
                #{args[0]}_map [label=\"map   \", shape=plaintext]
                #{args[0]}_map_output [shape=Mrecord label=\"<outp> #{args[3]}|#{args[4]}\"]
                #{if args[5]!=''
                args[5] + ' [shape=component]'
                '{rank=same;' + args[0] +'_map;' + args[5]+ '}'
                end}

                #{args[0]}_map_input -> #{args[0]}_map [style=invis] 
                #{args[0]}_map -> #{args[0]}_map_output[style=invis]
                #{args[0] + '_map -> ' + args[5] if args[5]!=''}
            }
    /,
            :VIZ_REDUCE => %q/
            subgraph cluster_#{args[0]}_reduce_SG{
                #{args[0]}_reduce_input [shape=Mrecord label=\"#{args[1]}|#{args[2]}\"]
                #{args[0]}_reduce [label=\"reduce\", shape=plaintext]
                #{args[0]}_reduce_output [shape=Mrecord label=\"<outp> #{args[3]}|#{args[4]}\"]
                #{if args[5]!=''
                args[5] + ' [shape=component]'
                '{rank=same;' + args[0] + '_reduce;' + args[5] + '}'
                end}

                #{args[0]}_reduce_input -> #{args[0]}_reduce [style=invis] 
                #{args[0]}_reduce -> #{args[0]}_reduce_output[style=invis]
                #{args[0] + '_reduce -> ' + args[5]  if args[5]!=''}
            }
    /,
            :VIZ_LINK => %q/
            #{args[0]} -> #{args[1]}[lhead=#{args[2]] 
    /,
            :VIZ_READ_HEAD => '#{args[0]}_read',
            :VIZ_READ_TAIL => '#{args[0]}_read',
            :VIZ_READ_SUBGRAPH => '#{args[0]}_read_SG',

            :VIZ_WRITE_HEAD => '#{args[0]}_write',
            :VIZ_WRITE_TAIL => '#{args[0]}_write',
            :VIZ_WRITE_SUBGRAPH => '#{args[0]}_write_SG',

            :VIZ_EXECUTE_HEAD => '#{args[0]}_execute_#{args[1]}',
            :VIZ_EXECUTE_TAIL => '#{args[0]}_execute_#{args[1]}',
            :VIZ_EXECUTE_SUBGRAPH => '#{args[0]}_#{args[1]}_execute_SG',

            :VIZ_MAP_HEAD => '#{args[0]}_map_input',
            :VIZ_MAP_TAIL => '#{args[0]}_map_output',
            :VIZ_MAP_SUBGRAPH => 'cluster_#{args[0]}_map_SG',

            :VIZ_REDUCE_HEAD => '#{args[0]}_reduce_input',
            :VIZ_REDUCE_TAIL => '#{args[0]}_reduce_output',
            :VIZ_REDUCE_SUBGRAPH => 'cluster_#{args[0]}_reduce_SG',

            :VIZ_LINK => %q/
            #{args[0]} -> #{args[1]}[lhead=#{args[2]}] 
    /,
        }
end