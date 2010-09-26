class Abu
	def initialize(outdir)
		if File.exists? outdir and File.directory? outdir
			@outdir=outdir
		else
			puts "Error: #{outdir} doesnt exist or isn't a directory"
			exit
		end
	end
	
	def self.generate(outdir,&block)
		abu = new(outdir)
		abu.instance_eval(&block)
	end
	
	def job(name)
		@context=name
		@jobout = File.new(File.join(@outdir,name.capitalize+'.java'),'w+')

		# dont like the eval, but dont like the ugly here doc either.
		# TODO: figure out the right way to do this
		@jobout << eval('"'+ Templates::JOB_TEMPLATE_TOP + '"')
		if block_given?
			yield
		end
		@jobout << eval('"'+ Templates::JOB_TEMPLATE_BOT + '"')
		nil
	end

	def mapreduce(name)
		@context=name
		if block_given?
			yield
		end
		nil
	end

	def read(key, value, from, using)
		@jobout << "read (#{key},#{value}) from #{from} using #{using}" << "\n"
		nil
	end

	def map(key1, value1, key2, value2, using)
		mapout = File.new(File.join(@outdir,'Mapper.java'),'w+')
		
		# dont like the eval, but dont like the ugly here doc either.
		# TODO: figure out the right way to do this
		mapout << eval('"'+ Templates::MAP_TEMPLATE + '"')
		nil
	end

	def reduce(key2, listOfvalue2, key3, value3, using)
		reduceout = File.new(File.join(@outdir,'Reducer.java'),'w+')

		# dont like the eval, but dont like the ugly here doc either.
		# TODO: figure out the right way to do this
		reduceout << eval('"'+ Templates::REDUCE_TEMPLATE + '"')
		nil
	end

	def exec(name,key1, value1, key3, value3)
		@jobout << "#{name} (#{key1},#{value1}) to (#{key3},#{value3})\n"
	end
	
	def write(key, value, to, using)
		@jobout << "write (#{key},#{value}) to #{to} using #{using}" << "\n"
		nil
		end
end

module Templates
	JOB_TEMPLATE_TOP=%q|
public class #{@context.capitalize} {
	public static void main(String[] args) throws Exception {

		// your code goes here
		Job job = new Job();
		job.setJarByClass(#{@context.capitalize}.class);
		FileInputFormat.addInputPath(job, new Path(args[0]));
		FileOutputFormat.setOutputPath(job, new Path(args[1]));
/*
		job.setMapperClass(#{@context.capitalize}Mapper.class);
		job.setReducerClass(NewMaxTemperatureReducer.class);
		job.setOutputKeyClass(Text.class);
		job.setOutputValueClass(IntWritable.class);
*/
|

	JOB_TEMPLATE_BOT=%q|
	System.exit(job.waitForCompletion(true) ? 0 : 1);
	}
}
|

	MAP_TEMPLATE=%q|
import java.io.IOException;
import java.io.InterruptedException;
/*
TODO: imports to be added
*/
static class #{@context.capitalize}Mapper extends Mapper<#{key1},#{value1},#{key2},#{value2}> {
	public void map(#{key1} key, #{value1} value, Context context)	throws IOException, InterruptedException {
		// your code goes here
	}
}
|

	REDUCE_TEMPLATE=%q|
import java.io.IOException;
import java.io.InterruptedException;
/*
TODO: imports to be added
*/
static class #{@context.capitalize}Reducer extends Reducer<#{key2},#{listOfvalue2},#{key3},#{value3}> {
	public void reduce(#{key2} key, #{listOfvalue2} value, Context context)	throws IOException, InterruptedException {
		// your code goes here
	}
}
|
end
