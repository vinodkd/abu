package org.vinodkd.abu;

import org.parboiled.Parboiled;
import org.parboiled.BaseParser;
import org.parboiled.Rule;
import org.parboiled.ReportingParseRunner;
import org.parboiled.RecoveringParseRunner;
import org.parboiled.support.ParsingResult;
import org.parboiled.support.ParseTreeUtils;
import org.parboiled.annotations.*;
import org.parboiled.common.StringUtils;
import org.parboiled.errors.ParseError;
import org.parboiled.errors.InvalidInputError;
import org.parboiled.support.InputBuffer;

import java.io.*;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.List;

@SuppressWarnings({"InfiniteRecursion"})
@BuildParseTree
public class AbuParser extends BaseParser<Object>{

    public Rule Job(){
        return Sequence(
            JobHdr(),
            JobBody(),
            ZeroOrMore(MapReduceDefn()),
            EOI

        );
    }

    // job:= ["job"|"run"|"flow"] spc <jobname> ":" nl tab <set spec>* nl tab <input spec> nl tab [<mapreddef>| <mapredref>]+ nl tab <output spec>
    public Rule JobHdr()
    {
        return Sequence(JOB,WSpace(),JobName(),COLON,ENDL);
    }

    public Rule JobBody()
    {
        return Sequence(
            Input(),
            Step(),ZeroOrMore(Step()),
            Output()
        );
    }

    public Rule MapReduceDefn()
    {
        return Sequence(
            MR,WSpace(), MRName(),COLON,ENDL,
            Step(),ZeroOrMore(Step())
        );
    }
    //  read    (k1:type,v1:type) from "/path/to/file.ext"  using DataReaderClassName
    public Rule Input()
    {
        return Sequence(TAB,Terminal("read"),ENDL);
    }

    public Rule Step()
    {
        return FirstOf(MapReduceCall(),MapCall(),ReduceCall());
    }

    public Rule MapReduceCall()
    {
        return Sequence(TAB,Terminal("mapreduce"),ENDL);
    }

    public Rule MapCall()
    {
        return Sequence(TAB,Terminal("map"),ENDL);
    }

    public Rule ReduceCall()
    {
        return Sequence(TAB,Terminal("reduce"),ENDL);
    }

    public Rule Output()
    {
        return Sequence(TAB,Terminal("write"),ENDL);
    }

    final Rule JOB = Terminal("job");
    final Rule MR = Terminal("mapreduce");

    public Rule WSpace()
    {
        return FirstOf("\t"," ");
    }

    public Rule JobName()
    {
        return Identifier();
    }

    public Rule MRName()
    {
        return Identifier();
    }

    final Rule COLON = Terminal(":");
    final Rule ENDL = OneOrMore(FirstOf("\r\n",'\r','\n'));

    final Rule TAB = Terminal("\t");

    @SuppressNode
    @DontLabel
    Rule Terminal(String string) {
        return String(string);
    }

    Rule Identifier()
    {
        debug("in id");
        return OneOrMore(LetterOrDigit());
    }

    Rule LetterOrDigit() {
        debug("in lod");
        return FirstOf(CharRange('a', 'z'), CharRange('A', 'Z'), CharRange('0', '9'), '_', '$');
    }


    public void debug(String s)
    {System.out.println(s);}

    public static void main(String args[])
    {
        try{
            AbuParser parser = Parboiled.createParser(AbuParser.class);
            File src = args.length == 1 ? new File(args[0]) : null;

            if(src==null || !src.exists())
                throw new Exception("Enter a valid source to parse");

            String sourceText = readAllText(src);
            System.out.println("src:"+sourceText);

            ParsingResult<?> result = RecoveringParseRunner.run(parser.Job(), sourceText);
            if(result.hasErrors()){
                for(ParseError pe: result.parseErrors){
                    InputBuffer ib = pe.getInputBuffer();
                    int st=pe.getStartIndex();
                    InputBuffer.Position stpos=ib.getPosition(st);
                    int end= pe.getEndIndex();
                    String extr=ib.extract(st, end);
                    System.out.println("Error at ndx:"+ st +",line:"+stpos.line+",col:"+stpos.column+",:str:"+ extr +",msg:" + pe.getErrorMessage());

                    if(pe instanceof InvalidInputError)
                    {
                        System.out.println("Last matched:"+((InvalidInputError)pe).getLastMatch());
                    }
                }
            }
            else{
                System.out.println("input:"+result.parseTreeRoot.getValue());
                String parseTreePrintOut = ParseTreeUtils.printNodeTree(result);
                System.out.println("m"+parseTreePrintOut+"n");
            }
        }catch(Exception e)
        {e.printStackTrace();}
    }

    public static String readAllText( File file) {
        return readAllText(file, Charset.forName("UTF8"));
    }

    public static String readAllText( File file,  Charset charset) {
        try {
            return readAllText(new FileInputStream(file), charset);
        }
        catch (FileNotFoundException e) {
            return null;
        }
    }

    public static String readAllText(InputStream stream,  Charset charset) {
        if (stream == null) return null;
        BufferedReader reader = new BufferedReader(new InputStreamReader(stream, charset));
        StringWriter writer = new StringWriter();
        copyAll(reader, writer);
        return writer.toString();
    }

    public static void copyAll( Reader reader,  Writer writer) {
        try {
            char[] data = new char[4096]; // copy in chunks of 4K
            int count;
            while ((count = reader.read(data)) >= 0) writer.write(data, 0, count);

            reader.close();
            writer.close();
        }
        catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
}