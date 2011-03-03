require "templates"

module Abu
    class Abu
        # structs to hold parsed values
        Var = Struct.new(:name, :type)
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
            @the_job                    # we'll find the name of the job when we parse it, 
                                        # so this is only to show that i've yet to get rid of my java roots :(
            @refs          = Array.new  # hold all references to names in the script
            @defs          = Hash.new   # hold all definitions of such names in the script
            #@import_reqd   = Set.new    # hold all names that will need imports
            @vars          = Hash.new   # holds all the variables declared in the job.
            # TODO: determine how to handle vars in the mapreduce jobs themselves.
            @unnamedvars   = 0          # counter that helps create unique names for variables left unnamed by the user
        end

        def parse
            @script = File.new(@script_file).read()
            instance_eval(@script, @script_file)
            #debug_ast
            validate_refs
            validate_flow
        end

        def job(name)
          #p "job"
            raise "Only one job per script" if @the_job
            @the_job = Job.new(name,[])
            @current_context=@the_job
            if block_given?
                yield
            end
        end

        def mapreduce(name,key1, value1, key3, value3)
          #p "mr"
            mrjob=MapReduce.new(name,[])
            @current_context = mrjob
            @defs[name] = mrjob
            if block_given?
                yield
            end
        end

        def read(key, value, from, using = '')
          #p "read"
            raise "read can be used only inside job" if @current_context.class != Job
            keyvar = process_key key 
            valuevar = process_val value
            @current_context.steps << Read.new(keyvar,valuevar,from,using)
        end
        
        def map(key1, value1, key2, value2, using = '')
          #p "map"
            key1var = process_key key1
            val1var = process_val value1
            key2var = process_key key2
            val2var = process_val value2
            
            @current_context.steps << Map.new(key1var,val1var,key2var,val2var,using)
        end

        def reduce(key2, listOfvalue2, key3, value3, using = '')
          #p "reduce"
            key2var = process_key key2
            val2var = process_val listOfvalue2
            key3var = process_key key3
            val3var = process_val value3

            @current_context.steps << Reduce.new(key2var, val2var, key3var, val3var, using)
        end

        def execute(name,key1, value1, key3, value3)
          #p "exec"
            raise "execute can be used only inside job" if @current_context.class != Job
            
            key1var = process_key key1
            val1var = process_val value1
            key3var = process_key key3
            val3var = process_val value3

            call_to_mr = Execute.new(name, key1var,val1var,key3var,val3var)
            @current_context.steps << call_to_mr
            @refs << call_to_mr
        end

        def write(key, value, to, using = '')
          #p "write"
            raise "write can be used only inside job" if !@current_context.class == Job
            keyvar = process_key key
            valvar = process_val value
            @current_context.steps << Write.new(keyvar,valvar,to,using)
        end

        def method_missing(name, *args, &block)
            puts "#{name} not found"
        end

        def process_key(var)
          process_var var, 'key'
        end
        
        def process_val(var)
          process_var var, 'value'
        end
        
        def process_var(var, defaultname, defaultType = 'Text')
          raise "value cannot be blank" if var ==""
          
          parts = var.split ':'
          raise "value cannot be blank" if parts.length == 0
              
          name = parts[0].strip
          if name.empty? 
            @unnamedvars += 1
            name = defaultname + @unnamedvars
          end
          typ = parts.length > 1 ? parts[1].strip : "" 
          
          #p "b4:#{name}, #{typ}"
          
          # if its a known name, check if the type matches, and if not, raise hell
          if @vars.has_key? name
            raise "#{name} is previously defined as of type: #{@vars[name]}" if !typ.empty? and typ != @vars[name]
            typ = @vars[name]
          else
            # add it to list of known definitions, which includes mr job names
            typ = defaultType if typ.empty?
            @vars[name] = typ
          end
          #p "#{name}, #{typ}, #{@vars[name]}"
          return Var.new name, typ 
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
            puts "gen: processing #{@the_job.name}"
            
            output_file = File.join @outdir,@the_job.name.capitalize + ".java"
            File.open(output_file,"w+") do |outfile|
                outfile.puts Templates.apply_template(:JOB_IMPORTS,binding)
                outfile.puts Templates.apply_template(:JOB_TOP,binding)
                gen_defns(outfile)
                gen_job(outfile)
                outfile.puts Templates.apply_template(:JOB_BOTTOM, binding)
            end

        end

        def gen_defns(outfile)
            @the_job.steps.each do |step|
                step_name = step.class.name.split('::').last
                if ['Map','Reduce'].include? step_name
                    section = ('MR_'+ step_name.upcase).intern
                    name=@the_job.name
                    outfile.puts Templates.apply_template(section, binding)
                end
            end
            @defs.each_value do |defn|
                defn.steps.each do |step|
                    # section name = <block name>_<step name> in caps to differntiate it from the symbols for the parse phase.
                    # this could do with some refactoring methinks.
                    section = ('MR_' + step.class.name.split('::').last.upcase).intern  
                    name = defn.name
                    outfile.puts Templates.apply_template(section,binding)
                end
            end
        end

        def gen_job(outfile)
            outfile.puts Templates.apply_template(:JOB_MAIN_TOP,binding)
            @the_job.steps.each do |step|
                blk= step.class.name.split('::').last
                #puts blk

                # if the step is an execute step, find the defn, and insert calls to the maps & reduces defined there
                if blk.eql? 'Execute' and (mrdef = @defs[step.name])
                    mrdef.steps.each do |mrstep|
                        mrblk = mrstep.class.name.split('::').last
                        section = ('JOB_' + mrblk.upcase).intern
                        outfile.puts Templates.apply_template(section,binding)
                    end
                else
                    section = ('JOB_' + blk.upcase).intern
                    outfile.puts Templates.apply_template(section, binding)
                end
            end
            outfile.puts Templates.apply_template(:JOB_MAIN_BOTTOM, binding)
        end


        def visualize
            puts "viz:processing #{@the_job.name}"

            output_file = File.join @outdir,@the_job.name.capitalize + ".gv"
            File.open(output_file,"w+") do |outfile|
                outfile.puts Templates.apply_template(:VIZ_JOB_TOP,binding)
                viz_defns outfile
                viz_job outfile
                outfile.puts Templates.apply_template(:VIZ_JOB_BOTTOM, binding)
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
                puts "processing #{defn.name}.."
                viz_block defn, outfile
            end
        end

        def viz_block(block, outfile)
            oldstep=nil
            outfile.puts Templates.apply_template(:VIZ_BLOCK_TOP, binding)
            block.steps.each do |step|
                # section name = <block name>_<step name> in caps to differntiate it from the symbols for the parse phase.
                # this could do with some refactoring methinks.
                #puts 'viz_block:',step, oldstep
                step_type = step.class.name.split('::').last
                section = ('VIZ_' + step_type.upcase).intern  
                outfile.puts Templates.apply_template(section, binding)
                if oldstep
                    viz_link block, oldstep, step, outfile
                end
                oldstep = step
            end
            outfile.puts Templates.apply_template(:VIZ_BLOCK_BOTTOM, binding)
        end

        def viz_link(block, oldstep, step,outfile)
            tail = get_tail block,oldstep
            head = get_head block,step
            subgraph = get_subgraph block,step
            outfile.puts Templates.apply_template(:VIZ_LINK, binding)
        end

        def get_tail(block,step)
            Templates.apply_template( ('VIZ_'+ step.class.name.split('::').last.upcase+'_TAIL').intern,binding)
        end

        def get_head(block,step)
            Templates.apply_template( ('VIZ_'+ step.class.name.split('::').last.upcase+'_HEAD').intern,binding)
        end

        def get_subgraph(block,step)
            Templates.apply_template( ('VIZ_'+ step.class.name.split('::').last.upcase+'_SUBGRAPH').intern,binding)
        end
    end

end