Roadmap:
========
Milestone 1 (v 0.1):

   - build parser: Basic parser done. Recognizes the keyword and basic structure expected.

Milestone 2 (v 0.2):

   - build (j)ruby parser + generator + visualizer (no validation or 'smarts'): DONE
   - make it shebang runnable : DONE
   - refactor code to make it better/DRY : DONE for templates, TBD for parse code
   - refactor script syntax to make it better/DRY-er: DESIGN DONE, to be coded
   - revalutate including java "trapdoors" per feedback from CHUG session: DONE as part of design above
   - evaluate making a maven plugin/ant task

Milestone 3 (v 0.3):

   - make it workflow enabled (See http://kdpeterson.net/blog/2009/11/hadoop-workflow-tools-survey.html for a nice set of requirements)
       - provide a wrapper for existing hadoop jobs to be expressed in abu: the migration path
       - make it an object-model rich dsl - gradle style
   - build java code generator
   - build java visualizer

Milestone 4:

   - evaluate jruby implementation of full scripting language.
   - decide on which of two versions to continue, or if both should.
   - refactor round 2 to implement validating grammar and plugin commands (see redesign thoughts in design.md)
Milestone 5 (v 0.4):

   - build analyzer (aka 'smarts' and/or validation). This is where the tuple definitions mentioned in Design #6 would matter.

Milestone 6:

   - Test out on at least 10 basic samples from the Hadoop Definitive Guide or Hadoop in Action, generate code and viz
   - Add higher level viz for jobs
   - add sanity tests

Milestone 7 (v 1.0):

   - Validate (j)ruby version and release.

Milestone 8 (v 1.1):

   - Validate java version and release
