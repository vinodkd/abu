class Abu
	def initialize(outdir)
		if File.exists? outdir and File.directory? outdir
			@outdir=outdir
			@out_secns = {
				:JOB_TOP => '',
				:MAPPER => '',
				:REDUCER => '',
				:JOB_MAIN_TOP => '',
				:READER => '',
				:EXEC_MAPPER => '',
				:EXEC_REDUCER => '',
				:WRITER => '',
				:JOB_MAIN_BOTTOM => '',
				:JOB_BOTTOM => ''
			}
		else
			puts "Error: #{outdir} doesnt exist or isn't a directory"
			exit
		end
	end
	
	def self.generate(outdir,&block)
		abu = Abu.new(outdir)
		abu.parse(&block)	
		abu.output
	end

	def parse(&block)
		instance_eval(&block)
	end
	
	def output
		File.open(@job_output_file,'w+') do |jobout|
			jobout.puts @out_secns[:JOB_TOP]
			jobout.puts @out_secns[:MAPPER]
			jobout.puts @out_secns[:REDUCER]
			jobout.puts @out_secns[:JOB_MAIN_TOP]
			jobout.puts @out_secns[:READER]
			jobout.puts @out_secns[:EXEC_MAPPER]
			jobout.puts @out_secns[:EXEC_REDUCER]
			jobout.puts @out_secns[:WRITER]
			jobout.puts @out_secns[:JOB_MAIN_BOTTOM]
			jobout.puts @out_secns[:JOB_BOTTOM]
		end		
	end
	
	def job(name)
		@context=name.capitalize
		@job_output_file=File.join(@outdir,@context+'.java')
		
		appy_template_and_assign :JOB_TOP 
		if block_given?
			yield
		end
		
		appy_template_and_assign :JOB_MAIN_TOP
		appy_template_and_assign :JOB_MAIN_BOTTOM
		appy_template_and_assign :JOB_BOTTOM
	end

	def mapreduce(name)
		@context=name.capitalize
		if block_given?
			yield
		end
	end

	def read(key, value, from, using)
		appy_template_and_assign :READER, key, value, from, using
	end

	def map(key1, value1, key2, value2, using)
		appy_template_and_assign :MAPPER, key2, value2, using
		appy_template_and_assign :EXEC_MAPPER, key2, value2, using
	end

	def reduce(key2, listOfvalue2, key3, value3, using)
		appy_template_and_assign :REDUCER, key3, value3, using
		appy_template_and_assign :EXEC_REDUCER, key3, value3, using
	end

	def exec(name,key1, value1, key3, value3)
		# does nothing for now, the map and reduce methods handle writing out the exec statements as well.
		# will change when a true AST is formed.
	end
	
	def write(key, value, to, using)
		appy_template_and_assign :WRITER, key, value, to, using
	end

	def appy_template_and_assign(section,*attrs)
		# dont like the eval, but dont like the ugly here doc either.
		# TODO: figure out the right way to do this
		@out_secns[section]= eval('"'+ @@TEMPLATES[section] + '"')
		#puts "secn= #{section}, value=#{@out_secns[section]}"
	end

	@@TEMPLATES = {
		:JOB_TOP => 'public class #{@context} {
/*
TODO imports to be added
*/
',
		:MAPPER => %q|
static class #{@context}Mapper extends Mapper<#{attrs[0]},#{attrs[1]},#{attrs[2]},#{attrs[3]}> {
	public void map(#{attrs[0]},#{attrs[1]} value, Context context)	throws IOException, InterruptedException {
		// your code goes here
	}
}
|,
		:REDUCER => %q|
static class #{@context}Reducer extends Reducer<#{attrs[0]},#{attrs[1]},#{attrs[2]},#{attrs[3]}> {
	public void reduce(#{attrs[0]} key, #{attrs[1]} value, Context context)	throws IOException, InterruptedException {
		// your code goes here
	}
}
|,
		:JOB_MAIN_TOP => %q|
	public static void main(String[] args) throws Exception {

		// your code goes here
		Job job = new Job();
		job.setJarByClass(#{@context}.class);
|,
		:READER => %q|
		FileInputFormat.addInputPath(job, new Path('#{attrs[2]}'));
|,
		:EXEC_MAPPER => '\n\t\tjob.setMapperClass(#{@context}Mapper.class);',
		:EXEC_REDUCER => '\n\t\tjob.setReducerClass(#{@context}Reducer.class);',
		:WRITER => %q|	
		FileOutputFormat.setOutputPath(job, new Path('#{attrs[2]}'));
		job.setOutputKeyClass('#{attrs[0]}'.class);
		job.setOutputValueClass('#{attrs[1]}'.class);
|,

		:JOB_MAIN_BOTTOM => %q|
	System.exit(job.waitForCompletion(true) ? 0 : 1);
	}
|,
		:JOB_BOTTOM => '}'
	}
end
