require "templates"

module Abu
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
        
        def get_proc
            if @the_proc
                @the_proc 
            else
                @the_proc= Proc.new
            end
        end
        
        def generate
            output_file = File.join @outdir,@the_job.name.capitalize + ".java"
            File.open(output_file,"w+") do |outfile|
                outfile.puts apply_template(:JOB_IMPORTS,binding)
                outfile.puts apply_template(:JOB_TOP,binding)
                gen_defns(outfile)
                gen_job(outfile)
                outfile.puts apply_template(:JOB_BOTTOM, binding)
            end

        end

        def gen_defns(outfile)
            @the_job.steps.each do |step|
                step_name = step.class.name.split('::').last
                if ['Map','Reduce'].include? step_name
                    section = ('MR_'+ step_name.upcase).intern
                    name=@the_job.name
                    outfile.puts apply_template(section, binding)
                end
            end
            @defs.each_value do |defn|
                defn.steps.each do |step|
                    # section name = <block name>_<step name> in caps to differntiate it from the symbols for the parse phase.
                    # this could do with some refactoring methinks.
                    section = ('MR_' + step.class.name.split('::').last.upcase).intern  
                    name = defn.name
                    outfile.puts apply_template(section,binding)
                end
            end
        end

        def gen_job(outfile)
            outfile.puts apply_template(:JOB_MAIN_TOP,binding)
            @the_job.steps.each do |step|
                blk= step.class.name.split('::').last
                #puts blk

                # if the step is an execute step, find the defn, and insert calls to the maps & reduces defined there
                if blk.eql? 'Execute' and (mrdef = @defs[step.name])
                    mrdef.steps.each do |mrstep|
                        mrblk = mrstep.class.name.split('::').last
                        section = ('JOB_' + mrblk.upcase).intern
                        outfile.puts apply_template(section,binding)
                    end
                else
                    section = ('JOB_' + blk.upcase).intern
                    outfile.puts apply_template(section, binding)
                end
            end
            outfile.puts apply_template(:JOB_MAIN_BOTTOM, @the_job.to_a)
        end

        def apply_template(section,args=nil)
            puts "processing #{section}.."
            if Templates::TEMPLATES.has_key? section
                template = ERB.new(Templates::TEMPLATES[section],nil,"<>")
                template.result(args) #..which is the binding in this case
            else
                puts "template for #{section} not found."
                ""  # return a blank string so output doesnt contain nil
            end
        end

        def visualize
            output_file = File.join @outdir,@the_job.name.capitalize + ".gv"
            File.open(output_file,"w+") do |outfile|
                outfile.puts apply_template(:VIZ_JOB_TOP,binding)
                viz_defns outfile
                viz_job outfile
                outfile.puts apply_template(:VIZ_JOB_BOTTOM, binding)
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
            outfile.puts apply_template(:VIZ_BLOCK_TOP, binding)
            block.steps.each do |step|
                # section name = <block name>_<step name> in caps to differntiate it from the symbols for the parse phase.
                # this could do with some refactoring methinks.
                #puts 'viz_block:',step, oldstep
                step_type = step.class.name.split('::').last
                section = ('VIZ_' + step_type.upcase).intern  
                outfile.puts apply_template(section, binding)
                if oldstep
                    viz_link block, oldstep, step, outfile
                end
                oldstep = step
            end
            outfile.puts apply_template(:VIZ_BLOCK_BOTTOM, binding)
        end

        def viz_link(block, oldstep, step,outfile)
            tail = get_tail block,oldstep
            head = get_head block,step
            subgraph = get_subgraph block,step
            outfile.puts apply_template(:VIZ_LINK, binding)
        end

        def get_tail(block,step)
            apply_template( ('VIZ_'+ step.class.name.split('::').last.upcase+'_TAIL').intern,binding)
        end

        def get_head(block,step)
            apply_template( ('VIZ_'+ step.class.name.split('::').last.upcase+'_HEAD').intern,binding)
        end

        def get_subgraph(block,step)
            apply_template( ('VIZ_'+ step.class.name.split('::').last.upcase+'_SUBGRAPH').intern,binding)
        end
    end

end