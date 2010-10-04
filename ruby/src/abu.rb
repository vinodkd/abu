class Abu
	# structs to hold parsed values
	Job = Struct.new(:name, :steps)
	Read = Struct.new(:k1,:v1,:path,:using)
	Write = Struct.new(:k3,:v3,:path,:using)
	Execute = Struct.new(:name,:k1,:v1,:k3,:v3)
	
	MapReduce = Struct.new(:name,:steps)
	Map = Struct.new(:k1,:v1,:k2,:v2,:using)
	Reduce = Struct.new(:k2,:v2,:k3,:v3,:using)

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
		@the_job		# we'll find the name of the job when we parse it, 
					# so this is only to show that i've yet to get rid of my java roots :(
		@refs = Array.new	# hold all references to names in the script
		@defs = Hash.new	# hold all definitions of such names in the script
		
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
			puts blk

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
			""	# return a blank string so output doesnt contain nil
		end
	end

	def visualize
	end

	@@TEMPLATES = {
		:JOB_TOP => 'public class #{args[0].capitalize} {
/*
TODO imports to be added
*/
',
		:MR_MAP => %q|
static class #{args[0].capitalize}Mapper extends Mapper<#{args[1]},#{args[2]},#{args[3]},#{args[4]}> {
	public void map(#{args[1]} key,#{args[2]} value, Context context)	throws IOException, InterruptedException {
		// your code goes here
	}
}
|,
		:MR_REDUCE => %q|
static class #{args[0].capitalize}Reducer extends Reducer<#{args[1]},#{args[2]},#{args[3]},#{args[4]}> {
	public void reduce(#{args[1]} key, #{args[2]} value, Context context)	throws IOException, InterruptedException {
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
		FileInputFormat.addInputPath(job, new Path('#{args[3]}'));
|,
		:JOB_MAP => '\n\t\tjob.setMapperClass(#{args[0].capitalize}Mapper.class);',
		:JOB_REDUCE => '\n\t\tjob.setReducerClass(#{args[0].capitalize}Reducer.class);',
		:JOB_WRITE => %q|	
		FileOutputFormat.setOutputPath(job, new Path('#{args[3]}'));
		job.setOutputKeyClass(#{args[1]}.class);
		job.setOutputValueClass(#{args[2]}.class);
|,

		:JOB_MAIN_BOTTOM => %q|
		System.exit(job.waitForCompletion(true) ? 0 : 1);
	}
|,
		:JOB_BOTTOM => '}'
	}

end

puts 'Abu: The hadoop scripting language, generator and visualizer'
puts "Usage: <abu> script.abu outdir [gen|viz]+" if ARGV.length < 2
script = ARGV[0]
outdir = ARGV[1]
gen_needed = ARGV[2] if ARGV[2] 
viz_needed = ARGV[3] if ARGV[3]

abu = Abu.new script, outdir
abu.parse
abu.generate if gen_needed
abu.viz if viz_needed

