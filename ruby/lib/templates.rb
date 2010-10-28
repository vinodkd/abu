require 'erb'

module Templates
    
    TEMPLATE_LOC = File.join(File.dirname(__FILE__),'..','templates')
    
    def Templates.apply_template(section,bndg)
        print "\tprocessing #{section}".ljust(35,".")
        
        t_file = File.join(TEMPLATE_LOC,section.to_s.downcase + '.erb')
        if File.exists? t_file
            t_src = File.new(t_file).read()
        elsif TEMPLATES.has_key? section
            t_src=TEMPLATES[section]
        end
        
        if t_src
            template = ERB.new(t_src,nil,"<>")
            res=template.result(bndg) #..the binding to be used
            puts "done"
            res
        else
            puts "template not found."
            ""  # return a blank string so output doesnt contain nil
        end
    end

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
            :VIZ_BLOCK_TOP => %q/
        subgraph cluster_<%=block.name%>_SG{
            <%=block.name%>_anchor [style=invis shape=point]
            headport=e/,

            :VIZ_BLOCK_BOTTOM => %q/
            labelloc=t
            label="<%block.name%>:<%=block.class.name.split('::').last%>"
        }

     /,
            # requires jobname before the read values
            # had to change the heredoc sigil to / from | as its used in the dot format.
            :VIZ_READ => %q/
            subgraph <%=block.name%>_read_SG{
                rank=same
                <%=block.name%>_read[shape=Mrecord, label="{<%=step.path%>|{<%=step.k1%>|<%=step.v1%>}}"]
            <%
            if step.using!=''
            %>
                <%=block.name%>_<%=step.using%> [shape=component]
                <%=block.name%>_read -> <%=block.name%>_<%=step.using%>[label="using"]'
            <%
            end
            %>
            }
    /,
            :VIZ_EXECUTE => %q/
            subgraph <%=block.name%>_<%=step.name%>_execute_SG{
                rank=same
                <%=block.name%>_execute_<%=step.name%> [label="Execute <%=step.name%>"]
                <%=block.name%>_execute_anchor_<%=step.name%> [style=invis shape=point]

                <%=block.name%>_execute_anchor_<%=step.name%> -> <%=step.name%>_anchor[lhead=cluster_<%=step.name%>_SG style=dashed arrowhead=box arrowtail=dot headport=e]
            }

    /,
            :VIZ_WRITE => %q/
            subgraph <%=block.name%>_write_SG{
                rank=same
                <%=block.name%>_write[shape=Mrecord, label="{{<%=step.k3%>|<%=step.v3%>}|<%=step.path%>}"]
            <%
            if step.using!=''
            %>
                <%=block.name%>_<%=step.using%> [shape=component]
                <%=block.name%>_write -> <%=block.name%>_<%=step.using%> [label="using"]
            <%
            end
            %>
            }
    /,
            :VIZ_MAP => %q/
            subgraph cluster_<%=block.name%>_map_SG{
                <%=block.name%>_map_input [shape=Mrecord label="<%=step.k1%>|<%=step.v1%>"]
                <%=block.name%>_map [label="map   ", shape=plaintext]
                <%=block.name%>_map_output [shape=Mrecord label="<outp> <%=step.k2%>|<%=step.v2%>"]
                <% if step.using!=''%>
                <%=step.using%> [shape=component]
                {rank=same;<%=block.name%>_map;<%=step.using%>}
                <%end%>

                <%=block.name%>_map_input -> <%=block.name%>_map [style=invis] 
                <%=block.name%>_map -> <%=block.name%>_map_output[style=invis]
                <% if step.using!=''%>
                <%=block.name%>_map -> <%=step.using%>
                <%end%>
            }
    /,
            :VIZ_REDUCE => %q/
            subgraph cluster_<%=block.name%>_reduce_SG{
                <%=block.name%>_reduce_input [shape=Mrecord label="<%=step.k2%>|<%=step.v2%>"]
                <%=block.name%>_reduce [label="reduce", shape=plaintext]
                <%=block.name%>_reduce_output [shape=Mrecord label="<outp> <%=step.k3%>|<%=step.v3%>"]
                <%if step.using!=''%>
                <%=step.using%> [shape=component]
                {rank=same;<%=block.name%>_reduce;<%=step.using%>}
                <%end%>

                <%=block.name%>_reduce_input -> <%=block.name%>_reduce [style=invis] 
                <%=block.name%>_reduce -> <%=block.name%>_reduce_output[style=invis]
                <% if step.using!=''%>
                <%=block.name%>_reduce -> <%=step.using%>
                <%end%>
            }
    /,
            :VIZ_READ_HEAD => '<%=block.name%>_read',
            :VIZ_READ_TAIL => '<%=block.name%>_read',
            :VIZ_READ_SUBGRAPH => '<%=block.name%>_read_SG',

            :VIZ_WRITE_HEAD => '<%=block.name%>_write',
            :VIZ_WRITE_TAIL => '<%=block.name%>_write',
            :VIZ_WRITE_SUBGRAPH => '<%=block.name%>_write_SG',

            :VIZ_EXECUTE_HEAD => '<%=block.name%>_execute_<%=step.name%>',
            :VIZ_EXECUTE_TAIL => '<%=block.name%>_execute_<%=step.name%>',
            :VIZ_EXECUTE_SUBGRAPH => '<%=block.name%>_<%=step.name%>_execute_SG',

            :VIZ_MAP_HEAD => '<%=block.name%>_map_input',
            :VIZ_MAP_TAIL => '<%=block.name%>_map_output',
            :VIZ_MAP_SUBGRAPH => 'cluster_<%=block.name%>_map_SG',

            :VIZ_REDUCE_HEAD => '<%=block.name%>_reduce_input',
            :VIZ_REDUCE_TAIL => '<%=block.name%>_reduce_output',
            :VIZ_REDUCE_SUBGRAPH => 'cluster_<%=block.name%>_reduce_SG',

            :VIZ_LINK => %q/
            <%=tail%> -> <%=head%>[lhead=<%=subgraph%>] 
    /,
        }
end