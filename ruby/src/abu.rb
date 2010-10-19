class Abu
    # structs to hold parsed values
    Job = Struct.new(:name, :steps)
    Read = Struct.new(:k1,:v1,:path,:using)
    Write = Struct.new(:k3,:v3,:path,:using)
    Execute = Struct.new(:name,:k1,:v1,:k3,:v3)
    
    MapReduce = Struct.new(:name,:steps)
    Map = Struct.new(:k1,:v1,:k2,:v2,:using)
    Reduce = Struct.new(:k2,:v2,:k3,:v3,:using)
    
    @@KNOWN_IMPORTS = {
        #TODO: put imports for known types here. Right now the kludge is to import all of hadoop.io.
    }

    def initialize(script_file, outdir)
        if !File.exists? script_file
            puts "Error: #{script} doesnt exist"
            exit
        else
            @script_file=script_file
        end
        
        if File.exists? outdir and File.directory? outdir
            @outdir=outdir
        else
            puts "Error: #{outdir} doesnt exist or isn't a directory"
            exit
        end
        @the_job        # we'll find the name of the job when we parse it, 
                        # so this is only to show that i've yet to get rid of my java roots :(
        @refs = Array.new   # hold all references to names in the script
        @defs = Hash.new    # hold all definitions of such names in the script
        # @import_reqd = Set.new    # hold all names that will need imports
    end
    
    def parse
        @script = File.new(@script_file).read()
        instance_eval(@script)
        #debug_ast
        validate_refs
        validate_flow
    end

    def job(name)
        raise "Only one job per script" if @the_job
        @the_job = Job.new(name,[])
        @current_context=@the_job
        if block_given?
            yield
        end
    end
    
    def mapreduce(name)
        mrjob=MapReduce.new(name,[])
        @current_context = mrjob
        @defs[name] = mrjob
        if block_given?
            yield
        end
    end

    def read(key, value, from, using)
        raise "read can be used only inside job" if @current_context.class != Job
        @current_context.steps << Read.new(key,value,from,using)
    end

    def map(key1, value1, key2, value2, using)
        @current_context.steps << Map.new(key1,value1,key2,value2,using)
    end

    def reduce(key2, listOfvalue2, key3, value3, using)
        @current_context.steps << Reduce.new(key2, listOfvalue2, key3, value3, using)
    end

    def execute(name,key1, value1, key3, value3)
        raise "execute can be used only inside job" if @current_context.class != Job
        call_to_mr = Execute.new(name, key1,value1,key3,value3)
        @current_context.steps << call_to_mr
        @refs << call_to_mr
    end
    
    def write(key, value, to, using)
        raise "write can be used only inside job" if !@current_context.class == Job
        @current_context.steps << Write.new(key,value,to,using)
    end

    def method_missing(name, *args, &block)
        puts "#{name} not found"
    end
    
    def debug_ast
        puts "Job Steps: #{@the_job.name}"
        @the_job.steps.each {|step| puts step}
        puts "defs:"
        @defs.each {|defn| puts defn}
        puts "refs:"
        @refs.each {|ref| puts ref}
    end
    
    def validate_refs
        ref_names = @refs.collect {|r| r.name}
        def_names = @defs.keys
        
        ref_names.each do |ref|
            if !def_names.include? ref
                # TODO: refine this to show a message instead of a stacktrace
                raise "No definition found for #{ref}"
            end
        end
    end
    
    def validate_flow
    end
    
    def generate
        output_file = File.join @outdir,@the_job.name.capitalize + ".java"
        File.open(output_file,"w+") do |outfile|
            outfile.puts apply_template(:JOB_IMPORTS,[])
            outfile.puts apply_template(:JOB_TOP,@the_job.to_a)
            gen_defns(outfile)
            gen_job(outfile)
            outfile.puts apply_template(:JOB_BOTTOM, @the_job.to_a)
        end
        
    end

    def gen_defns(outfile)
        @the_job.steps.each do |step|
            step_name = step.class.name.split('::').last
            if ['Map','Reduce'].include? step_name
                section = ('MR_'+ step_name.upcase).intern
                outfile.puts apply_template(section, [@the_job.name] + step.to_a)
            end
        end
        @defs.each_value do |defn|
            defn.steps.each do |step|
                # section name = <block name>_<step name> in caps to differntiate it from the symbols for the parse phase.
                # this could do with some refactoring methinks.
                section = ('MR_' + step.class.name.split('::').last.upcase).intern  

                outfile.puts apply_template(section, [defn.name] + step.to_a)
            end
        end
    end

    def gen_job(outfile)
        outfile.puts apply_template(:JOB_MAIN_TOP,@the_job.to_a)
        @the_job.steps.each do |step|
            blk= step.class.name.split('::').last
            #puts blk

            # if the step is an execute step, find the defn, and insert calls to the maps & reduces defined there
            if blk.eql? 'Execute' and (mrdef = @defs[step.name])
                mrdef.steps.each do |mrstep|
                    mrblk = mrstep.class.name.split('::').last
                    section = ('JOB_' + mrblk.upcase).intern
                    outfile.puts apply_template(section,[mrdef.name] + mrstep.to_a)
                end
            else
                section = ('JOB_' + blk.upcase).intern
                outfile.puts apply_template(section, [@the_job.name] + step.to_a)
            end
        end
        outfile.puts apply_template(:JOB_MAIN_BOTTOM, @the_job.to_a)
    end

    def apply_template(section,args)
        puts "processing #{section}.."
        if @@TEMPLATES.has_key? section
            template = @@TEMPLATES[section] 
            instance_eval '"' + template + '"'
        else
            puts "template for #{section} not found."
            ""  # return a blank string so output doesnt contain nil
        end
    end

    def visualize
        output_file = File.join @outdir,@the_job.name.capitalize + ".gv"
        File.open(output_file,"w+") do |outfile|
            outfile.puts apply_template(:VIZ_JOB_TOP,[])
            viz_defns outfile
            viz_job outfile
            outfile.puts apply_template(:VIZ_JOB_BOTTOM, @the_job.to_a)
        end
        print "Generating png..."
        dot_done = `dot #{output_file} | neato -n -s -Tpng -o#{output_file}.png`
        print "done"
    end

    def viz_job(outfile)
        viz_block @the_job, outfile
    end
    
    def viz_defns(outfile)
        @defs.each_value do |defn|
            puts "Processing #{defn.name}.."
            viz_block defn, outfile
        end
    end

    def viz_block(block, outfile)
        oldstep=nil
        outfile.puts apply_template(:VIZ_BLOCK_TOP, [block.name])
        block.steps.each do |step|
            # section name = <block name>_<step name> in caps to differntiate it from the symbols for the parse phase.
            # this could do with some refactoring methinks.
            #puts 'viz_block:',step, oldstep
            step_type = step.class.name.split('::').last
            section = ('VIZ_' + step_type.upcase).intern  
            outfile.puts apply_template(section, [block.name] + step.to_a)
            if oldstep
                viz_link block, oldstep, step, outfile
            end
            oldstep = step
        end
        outfile.puts apply_template(:VIZ_BLOCK_BOTTOM, [block.name, block.class.name.split('::').last])
    end
    
    def viz_link(block, oldstep, step,outfile)
        tail = get_tail block,oldstep
        head = get_head block,step
        subgraph = get_subgraph block,step
        outfile.puts apply_template(:VIZ_LINK, [tail,head,subgraph])
    end
    
    def get_tail(block,step)
        apply_template ('VIZ_'+ step.class.name.split('::').last.upcase+'_TAIL').intern,[block.name] + step.to_a
    end
       
    def get_head(block,step)
        apply_template ('VIZ_'+ step.class.name.split('::').last.upcase+'_HEAD').intern,[block.name] + step.to_a
    end
    
    def get_subgraph(block,step)
        apply_template ('VIZ_'+ step.class.name.split('::').last.upcase+'_SUBGRAPH').intern,[block.name] + step.to_a
    end

    @@TEMPLATES = {
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
        :JOB_TOP => 'public class #{args[0].capitalize} {
',
        :MR_MAP => %q|
static class #{args[0].capitalize}Mapper extends Mapper<#{args[1]},#{args[2]},#{args[3]},#{args[4]}> {
    public void map(#{args[1]} key,#{args[2]} value, Context context)   throws IOException, InterruptedException {
        // your code goes here
    }
}
|,
        :MR_REDUCE => %q|
static class #{args[0].capitalize}Reducer extends Reducer<#{args[1]},#{args[2]},#{args[3]},#{args[4]}> {
    public void reduce(#{args[1]} key, Iterable<#{args[2]}> values, Context context)    throws IOException, InterruptedException {
        // your code goes here
    }
}
|,
        :JOB_MAIN_TOP => %q|
    public static void main(String[] args) throws Exception {

        // your code goes here
        Job job = new Job();
        job.setJarByClass(#{args[0].capitalize}.class);
|,
        :JOB_READ => %q|
        FileInputFormat.addInputPath(job, new Path(\"#{args[3]}\"));
|,
        :JOB_MAP => '\n\t\tjob.setMapperClass(#{args[0].capitalize}Mapper.class);',
        :JOB_REDUCE => '\n\t\tjob.setReducerClass(#{args[0].capitalize}Reducer.class);',
        :JOB_WRITE => %q|   
        FileOutputFormat.setOutputPath(job, new Path(\"#{args[3]}\"));
        job.setOutputKeyClass(#{args[1]}.class);
        job.setOutputValueClass(#{args[2]}.class);
|,

        :JOB_MAIN_BOTTOM => %q|
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
|,
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

puts 'Abu: The hadoop scripting language, generator and visualizer'
puts "Usage: <abu> script.abu outdir [gen|viz]+" if ARGV.length < 2
script = ARGV[0]
outdir = ARGV[1]

gen_needed = ARGV[2].downcase.eql? 'gen' if ARGV[2]
gen_needed = ARGV[3].downcase.eql? 'gen' if ARGV[3] and !gen_needed

viz_needed = ARGV[2].downcase.eql? 'viz' if ARGV[2]
viz_needed = ARGV[3].downcase.eql? 'viz' if ARGV[3] and !viz_needed

# puts "#{gen_needed}, #{viz_needed}"
abu = Abu.new script, outdir
abu.parse
abu.generate if gen_needed
abu.visualize if viz_needed

