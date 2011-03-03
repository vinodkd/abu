require 'erb'

module Templates
    
    TEMPLATE_LOC = File.join(File.dirname(__FILE__),'templates')
    
    def Templates.apply_template(section,bndg)
        print "\tprocessing #{section}".ljust(35,".")
        
        t_file = File.join(TEMPLATE_LOC,section.to_s.downcase + '.erb')
        if File.exists? t_file
            t_src = File.new(t_file).read()
            t_name = t_file
        elsif TEMPLATES.has_key? section
            t_src=TEMPLATES[section]
            t_name = section
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
      # TODO: figure out why this template fails when externalized.
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
            job.setOutputKeyClass(<%=step.k3.type%>.class);
            job.setOutputValueClass(<%=step.v3.type%>.class);|,

            :JOB_BOTTOM => '}',

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
        }
end