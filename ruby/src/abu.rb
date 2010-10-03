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
		@defs = Array.new	# hold all definitions of such names in the script
		
	end
	
	def parse
		@script = File.new(@script_file).read()
		instance_eval(@script)
		debug_ast
	end

	def debug_ast
		puts "Job Steps: #{@the_job.name}"
		@the_job.steps.each {|step| puts step}
		puts "defs:"
		@defs.each {|defn| puts defn}
		puts "refs:"
		@refs.each {|ref| puts ref}
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
		@defs << mrjob
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

