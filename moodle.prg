
#include '../common/common.h'

*============================================================================
*============================================================================
* Moodle Export functions:
*============================================================================
*============================================================================

** init - dhempy 6/5/2013 12:27:34 AM





&& Moodle backup file
define class MBZ	as custom

	export_title = 'FoxWeb Export'
	courseid = 'default'
	section_list = CRLF
	section_count = 0
	setting_list = CRLF
	activity_list = CRLF
	msg = ''
	warnings = ''
	backup_folder = ''
	backup_filename = ''
	backup_zipname = ''
	template_folder = ''	
	filename_part = ''	
	current_activity_id = 1000
	question_list = ''
	section_points = 0 && only relevant to matching sections
	answer_list = ''
	case_sensitive = 0	&& Can vary per question.
	questionid =  ''	&& only used for MATCH questions, where question cursor is gone by the time questionid is needed in template.
	quiz_list = ''
	section_list = ''
	vis_stu = .F.
	vis_fac = .F.

	&& Is the current category all combined into one?  (This will be overwritten frequenetly while looping)
	combine = .F.
	combined_output = ""	

		
	procedure Init()
		this.courseid = thiscrs.courseid
		this.export_title = "FoxWeb Export | " + strtran(ttoc(datetime(),3), 'T', ' ')
		
		this.vis_stu = not empty(Request.QueryString('viz_stu')) 
		this.vis_fac = not empty(Request.QueryString('viz_fac'))
		
	  this.PrepDatabase()
	endproc

	procedure Destroy()
		&& close databases
	endproc






	
*********************************************************************************
  procedure ExportMoodleCourse
      * Generates intermediate .xml files and zips to create a Moodle .mbz file. 
      * This is probably the only function you need to call from outside to export a course.

		this.Log(	"ExportMoodleCourse starting for " + this.courseid + ": " + trim(thiscrs.coursename)  )

		&& Preserve output buffer and state...we'll be stomping all over the output buffer.
		local m.existing_content, m.old_buffer_state
		m.old_buffer_state = Response.Buffer
		Response.Buffer = .T.		&& Don't send immediately.
		m.existing_content = Response.OutputBuffer 
		Response.Clear


		this.ScanLessons()	&& generates all section files and populates vars used in top-level files.

		
		
		this.MakeFile("moodle_backup.xml")
		this.MakeFile("completion.xml")
		this.MakeFile("files.xml")
		this.MakeFile("gradebook.xml")
		this.MakeFile("groups.xml")
		this.MakeFile("outcomes.xml")
		this.MakeFile("questions.xml")
		this.MakeFile("roles.xml")
		this.MakeFile("scales.xml")

		&& Course folder files:			
		this.MakeFile("course.xml",     "course")
		this.MakeFile("enrolments.xml", "course")
		this.MakeFile("roles.xml",      "course")
		this.MakeFile("inforef.xml",    "course")
		

		this.ZipFiles()		
		


		this.Warn('<p>Recap of warnings during this export: </p><ul>' + this.warnings + '</ul>')

		&& Restore any prior content and buffer state:
		Response.Clear
		Response.Buffer       = m.old_buffer_state 
		Response.OutputBuffer = m.existing_content

	endproc





*********************************************************************************
  procedure ExportQuestions
      * Generates an .xml file containing all the quiz questions.
      * Does not export the quiz structures, but tags and categories should facilitate that.
      
		this.SetFolders('question') 

		this.Log(	"ExportQuestions(" + this.courseid + "): " + trim(thiscrs.coursename) + " to folder [" + this.backup_folder + "]" )

		&& Preserve output buffer and state...we'll be stomping all over the output buffer.
		local m.existing_content, m.old_buffer_state
		m.old_buffer_state = Response.Buffer
		Response.Buffer = .T.		&& Don't send immediately.
		m.existing_content = Response.OutputBuffer 
		Response.Clear

		if empty (Request.QueryString('limit'))
				m.top_qz_limit = '' 
		else 
				m.top_qz_limit = 'top ' + alltrim(str(val(Request.QueryString('limit'))))
		endif


		m.where_clause  = ' quizid = "' + this.courseid  + '" '
		m.quizid     = left(Request.QueryString('quizid'),7)
		m.quiz_first = left(Request.QueryString('quiz_first'),7)
		m.quiz_last  = left(Request.QueryString('quiz_last'),7)

		this.filename_part = 'all'

		do case 
			case not empty (m.quizid) 
				m.where_clause = m.where_clause + ' and quizid = "' + m.quizid  + '" '
				this.filename_part = m.quizid 

			case not empty (m.quiz_first) and not empty (m.quiz_last)
				m.where_clause = m.where_clause + ' and quizid between "' + m.quiz_first + '" and "' + m.quiz_last + '" '
				this.filename_part = m.quiz_first + '-' + m.quiz_last  + iif(empty(m.top_qz_limit), '', '+' + strtran(m.top_qz_limit,' ','_'))
				
			case not empty (m.quiz_first) and not empty (m.top_qz_limit)
				m.where_clause = m.where_clause + ' and quizid >= "' + m.quiz_first  + '" '
				this.filename_part = m.quiz_first + '+' + strtran(m.top_qz_limit,' ','_')

		endcase
	

		this.Log ([Exporting &top_qz_limit quizzes where &where_clause])
		
		select &top_qz_limit qz.quizid, qz.title ;
			from dl!qquizes qz ;
			where &where_clause ;
			order by quizid ;
			into cursor qz

		m.qzcount = 0
		m.qscount = 0
		
		
		scan		&& quizzes in course 
			this.Log ("Export questions for quiz " + qz.quizid + " at " + ttoc(datetime()) )
			m.qzcount = m.qzcount + 1

			select qsect.* ;
				from dl!qsections qsect ;
				where qsect.sectionid = qz.quizid ;
				order by sectionid ;
				into cursor qsect
			
			scan     && sections in quiz

		
				this.ExportSection()
				
		
				
			endscan  && sections in quiz 

			&& I'm pretty sure this line doesn't belong here:  3/5/2014 11:56:46 PM
			&& this.answer_list = this.answer_list + this.MakeFile('', '', 'answer.key.xml')
				
		endscan && quizzes in course
		
		

		m.filename =  strtran("fw_questions_"+ this.filename_part +".xml", ' ', '-')
		
		this.Log ("Exported " + alltrim(str(m.qscount)) + " questions for " + alltrim(str(m.qzcount)) + " quizzes to <b>" + m.filename + "</b>")

		&&this.MakeFile( this.courseid +"_questions.xml", .F., "questions.xml")
		this.MakeFile( m.filename, .F., "questions.xml")


&&		this.Log('<div class="warning">TO DO: Write each quiz to disk, then batch into separate files (maybe X quizzes/file or Y bytes/file?)</div>')
&&		this.Log('<div class="warning">TO DO: Experiment with response.flush() or similar to get around output size limitation and improve responsiveness?</div>')
&&		this.Log('<div class="warning">TO DO: Create quizzes to contain the questions.  (Maybe a separate script?) </div>')

		this.Warn('<p>Recap of warnings during this export: </p><ul>' + this.warnings + '</ul>')

		&& Restore any prior content and buffer state:
		Response.Clear
		Response.Buffer       = m.old_buffer_state 
		Response.OutputBuffer = m.existing_content
		
 		Server.AddScriptTimeout(10, .T.)		
		return m.qscount
		
	endproc






	function ExportSection()

				this.Log ("<br /><div class='notice'><h2>Export section " + qsect.sectionid + " at " + ttoc(datetime()) + "</h2>"  )
				
				Server.AddScriptTimeout(5, .T.)
	
				this.question_list = ''
				this.answer_list = ''
				this.questionid =  ''
				this.section_points = 0 		&& This is only relevant for Matching questions.
		
				select qques.* ;
					from dl!qquestions qques ;
					where qques.questionid = qsect.sectionid ;
					order by questionid ;
					into cursor qques
				
				q_count = 0
				q_rows = reccount()
				
				scan     && questions in section
					q_count = q_count + 1
					m.choice_count = 0
					m.key_count = 0
					
					if ( empty( qques.export_typ) )
						m.effective_type = qsect.s_type 	
					else 
						&& FoxWeb question author may override the section's question type for one question.
						m.effective_type = qques.export_typ
					endif
						
					
					this.Log ("Export question " + qques.questionid + " (" + m.effective_type + ") " + qques.qs_text )
					m.qscount = m.qscount + 1
					this.case_sensitive = 0
					
					if (m.effective_type != 'MATCH')
						this.answer_list = ''		&& These build through the entire section, and must be retained until the end of the section.
					else 
						this.section_points = this.section_points + qques.qs_worth 	&& This is only relevant for Matching questions.
						&& This depends on "extra" options having zero points -- which is what FoxWeb forces. 
					endif
				
					&& Collect answers in qchoices:					
					select qchoices.* ;
						from dl!qchoices ;
						where qchoices.choiceid = qques.questionid ;
						order by choiceid ;
						into cursor q_choice
						
					scan 
						&& this.Log("Choice " + q_choice.choiceid + ": " + q_choice.ch_text)
					 	if ( (left(q_choice.ch_text, 1) = '"' ) and (right(q_choice.ch_text, 1) = '"' ) )
					 		&& this.Log("CASE SENSITVE ANSWER: " + q_choice.choiceid + ": " + q_choice.ch_text)
					 		&& Then this is an exact-match response.  Both case, punctuation, and spacing must be exact. 
					 		&& documentation: http://www.dl.ket.org/intranet/faq/qz_grade.htm#correct 
					 		this.case_sensitive = 1
					 	endif

						this.answer_list = this.answer_list + this.MakeFile('', '', 'answer.choice'   ;
								+ iif( m.effective_type = 'MATCH', '.MATCH', '' )  ;
								+ iif( m.effective_type = 'ESSAY', '.ESSAY', '' )  ;
								+ '.xml')
						
						m.choice_count = m.choice_count + 1
					endscan
					
				
					if (m.effective_type = 'TEXT') 
						&& Collect answers in qkey:					
						select qkey.* ;
							from dl!qkey ;
							where qkey.keyid = qques.questionid ;
							and not empty(qkey.K_text) ;
							order by keyid desc ;
							into cursor q_key
						
						m.key_text_list = ''
						
						scan 
							&& this.Log("Key " + q_key.keyid + ": " + q_key.k_text)
							m.marker = '~{' + alltrim(q_key.K_text) + '}~'
							if (this.case_sensitive > 0)
								m.marker = lower(m.marker)
							endif
							if (0 < at(m.marker , m.key_text_list ))
								&& this.Log("Skipping duplicate key " + q_key.keyid + ": " + m.marker + "  >>> Existing keys: " + m.key_text_list )
							else
								m.key_text_list = m.key_text_list + m.marker + ' '
								if (q_key.k_worth > qques.qs_worth)
									this.Warn("Excess score reduced to 100%: " + alltrim(str(q_key.k_worth)) + "/" + alltrim(str(qques.qs_worth)) ;
									+ "points for Key <a href='" + URL('Quiz') + "?courseid=" + this.courseid ;
									+ "&" + "quizid=" + qz.quizid ;
									+ "&" + "do=grade" ;
									+ "&" + "showme=all" ;
									+ "&" + "questionID=" + qques.questionid  ;
									+ "#k-" + q_key.keyid ;
									+ "'>" ;
									+ q_key.keyid + "</a>: " + q_key.k_text ) 
								endif
								this.answer_list = this.answer_list + this.MakeFile('', '', 'answer.key.xml')
								m.key_count = m.key_count + 1
							endif
						endscan
				
					endif


 				  &&this.Log ("Question " + str(q_count) + " of  " + str(q_rows) + " in section " + qsect.sectionid  )		

					if (m.effective_type != 'MATCH'  or (q_count = q_rows) )		&& Only fill matching templates on the last question of the section.
						this.ExportQuestion()	&& combines question data with this.answer_list from keys and choices.
						this.Log(" + " + alltrim(str(m.choice_count)) + " answers, " + alltrim(str(m.key_count)) + " keys")
						this.answer_list = ''
					else 
						if empty(this.questionid)
							this.questionid =  qques.questionid		&& Capture the first ID to use for the questiond when the last matching question is hit.
						endif
					endif
				
				
				endscan  && questions in section

				this.section_list = this.section_list + this.MakeFile('', '', 'section.xml')
				this.question_list = ''
				this.questionid =  ''
				this.answer_list = ''
				
				this.Log ("</div> <!-- end of section --> " )		
				
	endfunc





	function ExportQuestion()
	
		m.effective_type = trim(iif( empty(qques.export_typ), qsect.s_type, qques.export_typ ))
			 
		if (not (m.effective_type = 'MC' or m.effective_type = 'TEXT' or m.effective_type = 'MATCH' or m.effective_type = 'ESSAY'))
			this.Log('<div class="notice">We do not have a template for ' + m.effective_type + ' yet.</div>')
			return
		endif
			 
			 
			m.question = this.MakeFile('', '', 'question.' + trim(m.effective_type) + '.xml')
			this.question_list = this.question_list + m.question
			
	endfunc


	

  function SetFolders(m.subfolder, m.sub_subfolder)
 
		&& param m.subfolder, if given, is the alternate folder name, for both template and backup folders.

		&& Set up this.backup_folder: 			=========================
		
		if empty(m.subfolder)
			this.Warn("Error: no subfolder given to this.SetFolders()")
			return
		endif
		

				
		this.backup_folder   = "\script_data\moodle\" 
		this.MakePath(this.backup_folder)	&& THis is optimistic, as we probably lack permissions. Do that on your own.

		this.backup_folder   = this.backup_folder + m.subfolder + "\" 
		this.MakePath(this.backup_folder)	

		this.backup_folder   = this.backup_folder + ThisCrs.courseid + "\" 
		this.MakePath(this.backup_folder)	

		if not empty(m.sub_subfolder)
			this.backup_folder = this.backup_folder + m.sub_subfolder + "\"
			this.MakePath(this.backup_folder)	
		endif

		m.backup_folder = this.backup_folder
		
&&		this.Log("rmdir /s /q &backup_folder   (command skipped) ")
&& 		run rmdir /s /q &backup_folder   && This causes bizarre errors.
&& 		this.MakePath(this.backup_folder)
  


		&& Set up this.template_folder: 			=========================

		this.template_folder = '/db/moodle/template/' + m.subfolder			&& assumes relative to the called script, probably under /dl/intranet...

		this.Log("Saving export files to: <tt>" + this.backup_folder + "</tt>") 
		
  endfunc


  function ZipFiles()
  	&& Compresses all generated files into a single zip (or .mbz) file
 
 		&& this.Log("Zipping all files in <tt>" + this.backup_folder + "</tt> into zip file <tt>" + this.filename_part + "</tt>."  )
 		
  	Server.AddScriptTimeout(30, .T.)
 		
		m.shell_cmd = "C:\Progra~1\7-Zip\7z.exe a -r " + this.backup_folder + "..\" + this.filename_part + ".zip " + this.backup_folder + "*.*"
	 		&& TODO - consider using %ProgramFiles% env var instead of hard-coded path.   
 		&& this.Log("run &shell_cmd ")
 		run &shell_cmd

  	Server.AddScriptTimeout(30, .T.)
 		
 		m.shell_cmd = "rmdir /s /q " + this.backup_folder 
		&& this.Log("run &shell_cmd")
 		run &shell_cmd
 				&& Why doesn't this rmdir work?
		
		this.Log("<div class='box'><h1>Course backup saved to:</h1> <tt>" + left(this.backup_folder, len(this.backup_folder)-1) + ".zip </tt></div>") 
		
		
  endfunc


	
	
	procedure MakeFile(m.dest_fname, m.dest_path, m.src_fname, m.src_path)
		* Creates m.dest_fname.  If it goes to the root of the output folder with a static filename, all other params can be omitted.
		* If the file is going to a subfolder, put the subpath (relative to the output folder) in dest_path.
		* Pulls m.src_fname from the template folder, fills it in, and saves it as the same name in backup_folder
		* If the dest_fname is different than the template (e.g. you're adding a dynamic ID in the filename), use src_fname. Otherwise it defaults to dest_fname.
		* If the dest_path different than the template path (e.g. you're adding a dynamic ID in the folder name), use src_path. Otherwise it defaults to dest_path.
		* Assumes Response.Buffer is .T.
		* If m.dest_fname is empty(), don't create the output file.  (STill returns output)
		*   In this case, you need to spec the src_fname, such as MakeFile('', '', 'my_template.xml')
		* MakeFile() returns the generated content
		
		m.dest_path = iif( empty(m.dest_path), ''          , "\" + m.dest_path )
		m.src_fname = iif( empty(m.src_fname), m.dest_fname, m.src_fname )
		m.src_path  = iif( empty(m.src_path) , m.dest_path , "\" + m.src_path  )
		
		m.src_path_abs  = this.template_folder + m.src_path
		m.src	 = m.src_path_abs + "\" + m.src_fname + ".fwx"

		if empty(this.backup_folder) 
			this.Log("backup_folder is empty trying to create &dest_path !")
			return
		endif
		m.dest_path_abs = this.MakePath(this.backup_folder + m.dest_path)
		m.dest = m.dest_path_abs + "\" + m.dest_fname

		&& Time to make the donuts!
		&& this.Log("About to execute " + m.src)
				
		Server.Execute(m.src)		

		
		m.output = Response.OutputBuffer 
		Response.Clear


		&& Catch any absolute links and make full URL's:  (would like to catch relative links too, but that's an odd thing to have in a bulletin, and hard to do without regex's)
		m.output = strtran(m.output, [href="/], [href="http://] + Request.ServerVariables("SERVER_NAME") + [/])
		m.output = strtran(m.output, [href='/], [href='http://] + Request.ServerVariables("SERVER_NAME") + [/])

		m.bytes = alltrim(str(len(m.output)))

		if (empty(m.dest_fname)) 		
			&& this.Log("Fulfilled <tt>&src_fname</tt> to memory -- &bytes bytes" )
		
		else 
			&& strconv(...,9)  Converts to UTF-8 -- Only do this for file writes!  If you do it for returned content, that later gets converted again by MakeFile(to disk), it gets corrupted.
			STRTOFILE( strconv(m.output, 9)  , m.dest) 

			if (!file(m.dest))
				this.Warn("<strong class='error'>ERROR: Could not create &dest from &src</strong>")
			else
				&& this.Log("Created <tt>&dest</tt> --  &bytes bytes" )
			endif
		endif
		
		return m.output

	endproc



	function MakePath (m.path)
		if (file (m.path + '\exists.txt') )
			return m.path
		endif
		
		try
			mkdir &path && Create path.  If this causes an error, check that the folder in m.path in fw_exit exists.  Maybe create exists.txt yourself.  Please notify the sysadmin.
		catch
		endtry 
		
		try
			dir nofiles.* to file m.path+'\exists.txt' && Contents of file not significant...only file presence.
		catch
		endtry 
		
		if (!file (m.path + '\exists.txt') )
			this.Log("Could not create path [" + m.path + "]")
			return 
		else
			return m.path
		endif
		
	endfunc













&&   *********************************************************************************
&&   * Scans various content in the FoxWeb course, in prep for exporting to mbz by ExportMoodleCourse()
&& 	procedure ScanFoxWebCourse
&& 		this.Log("ScanFoxWebCourse starting")
&& 		
&&  		this.ScanLessons()
&& 
&& 	endproc




	
  *********************************************************************************
  * Populates this.section_list and this.setting_list.
  * Scans all bulletins in the course to create an XML fragment for inclusion within the main moodle_backup.xml file.
  * It also creates sub folders for each lesson.  Ideally, this should fall under an Export function, not a Scan function,
  * but let's face it...this is a one-and-done project!
  *********************************************************************************
  
	procedure ScanLessons()
		
		this.Log("ScanLessons()...")
		
		this.Log("Exporting " + alltrim(str(ThisCrs.last_less)) + " lessons.")
	

	
		if empty (Request.QueryString('limit'))
				m.top_lesson_limit = '' 
		else 
				m.top_lesson_limit = 'top ' + alltrim(str(val(Request.QueryString('limit'))))
		endif


		m.where_clause  = ' lessons.courseid = "' + this.courseid  + '" '
		m.lessonid     = alltrim(str(val(Request.QueryString('lessonid'))     ))
		m.lesson_first = alltrim(str(val(Request.QueryString('lesson_first')) ))
		m.lesson_last  = alltrim(str(val(Request.QueryString('lesson_last'))  ))
		m.lesson_start = alltrim(str(val(Request.QueryString('lesson_start')) ))
		

		this.filename_part = ThisCrs.courseid + '.'
	
		if (this.vis_fac)
				this.filename_part = this.filename_part + 'fac.'
		endif

		if (this.vis_stu )
				this.filename_part = this.filename_part + 'stu.'
		endif


		do case 
			case not empty (Request.QueryString('lessonid')) 
				m.where_clause = m.where_clause + ' and lessons.lesson_number == ' + m.lessonid  + ' '
				this.filename_part = this.filename_part + m.lessonid 

			case not empty (Request.QueryString('lesson_first')) and not empty (Request.QueryString('lesson_last'))
				m.where_clause = m.where_clause + ' and lessons.lesson_number between ' + m.lesson_first + ' and ' + m.lesson_last + ' '
				this.filename_part = this.filename_part + m.lesson_first + '-' + m.lesson_last  + iif(empty(m.top_lesson_limit), '', '+' + strtran(m.top_lesson_limit,' ','_'))
				
			case not empty (Request.QueryString('lesson_start')) 
				m.where_clause = m.where_clause + ' and lessons.lesson_number >= ' + m.lesson_start  + ' '
				this.filename_part = this.filename_part + m.lesson_first + '+' + strtran(m.top_lesson_limit,' ','_')

		endcase
	

		this.Log ([Exporting &top_lesson_limit lessonzes where &where_clause])

	  this.SetFolders('course' , this.filename_part)


 		select &top_lesson_limit doc , lesson, unit_number, unit, lesson_label, lesson_id, lessons.id, lesson_number ;
			from dl!lessons ;
			left outer join unit on unit.id = lessons.unit_id ;
			where &where_clause ; 
			into cursor lesson ;
			order by doc
	

		this.Log ([Found ] + alltrim(str(_tally)) + [ lessonzes...])
			
		this.section_count = 0
		
		scan
			this.Log("<div class='box'> <h2>Lesson " + alltrim(str(lesson.lesson_id)) + ": " + alltrim(lesson.id)	 + " | "+ alltrim(lesson.lesson) + "</h2>")
			
   		Server.AddScriptTimeout(10, .T.)
   		
			this.ExportLesson()
			this.ExportLessonCategories()			&& And the bulletins therein...
		
			this.section_count = this.section_count + 1
			this.Log("</div>")
		endscan
	
		
			
		this.Log("<strong>Created " + str(this.section_count) + " sections.</strong>")
		&&	this.Log("this.section_list is " + this.section_list + ".")
	endproc


	function ExportLesson()

			local m.unit
			if isnull(lesson.unit)
				m.unit = ""
			else
				m.unit = alltrim(str(lesson.unit_number)) + '. ' + alltrim(lesson.unit) + ": "
			endif

			m.sectionid = alltrim(str(lesson.lesson_id)) 
			m.sectionnumber = alltrim(str(lesson.lesson_number))
			
			m.section_tag = "";
	      + '  <section>' +CRLF ;
	      + '    <sectionid>' + m.sectionid + '</sectionid>' +CRLF ;
	      + '    <title>' +  m.unit + alltrim(lesson.lesson) + '</title>' +CRLF ;
	      + '    <directory>sections/section_' + m.sectionid + '</directory>' +CRLF ;
	      + '  </section>' +CRLF

			m.setting_tag = "";
				 + '      <setting>' + CRLF ;
		     + '          <level>section</level>' + CRLF ;
		     + '        <section>section_' + m.sectionid + '</section>' + CRLF ;
		     + '        <name>section_' + m.sectionid + '_included</name>' + CRLF ;
		     + '        <value>1</value>' + CRLF ;
		     + '      </setting>' + CRLF ;
		     + '      <setting>' + CRLF ;
		     + '        <level>section</level>' + CRLF ;
		     + '        <section>section_' + m.sectionid + '</section>' + CRLF ;
		     + '        <name>section_' + m.sectionid + '_userinfo</name>' + CRLF ;
		     + '        <value>0</value>' + CRLF ;
		     + '      </setting>' + CRLF 

	      
			if isnull(m.section_tag) or isnull(m.setting_tag)
				m.section_tag = "<strong>Warning: null field in lesson " + m.sectionid + ".</strong><br />"+CRLF
				this.Log(m.section_tag)
			endif
			
	    this.section_list = this.section_list + m.section_tag
	    this.setting_list = this.setting_list + m.setting_tag

			m.section_folder =  "sections\section_" + m.sectionid 
			
			this.MakeFile("inforef.xml", m.section_folder, .F., "sections\section_")
			this.MakeFile("section.xml", m.section_folder, .F., "sections\section_")

	endfunc


											function ExportLessonCategoryCombined()	
													&& Exports an entire bulletin category within one lesson as a single Moodle label.
													&& Paremeters: global cursor cat.id, lesson.doc
										
													this.activity_list = this.activity_list + "TODO: 	ExportLessonCategoryCombined() for " + lesson.lesson + "<br />"+CRLF
													this.Warn("TODO: 	ExportLessonCategoryCombined() for " + lesson.lesson)

													= DynamicCategories ('STU', cat.id)		&& Sets m.bull_list and m.sidebar
													this.CreateLabel('<div ' + m.classtag + '><h3>'+alltrim(cat.category)+ '</h3>' + m.bull_list + m.sidebar +  ' </div>', 0) 

													return
													return
													return
													return
													return
													return
													return
													return
													return
													

										
&&													m.sectionid = alltrim(str(lesson.lesson_id)) 
&&													m.moduleid = this.NewModuleID()
&&													m.sectionnumber = alltrim(str(lesson.lesson_number))
&&													
&&													m.activity_tag = "";
&&											      + '  <activity>' +CRLF ;
&&											      + '    <moduleid>' + m.moduleid + '</moduleid>' +CRLF ;
&&											      + '    <sectionid>' + m.sectionid + '</sectionid>' +CRLF ;
&&											      + '    <modulename>label</modulename>' +CRLF ;
&&											      + '    <title>' + alltrim(lesson.lesson) + ' Bulletins </title>' +CRLF ;
&&											      + '    <directory>activities/label_' + m.moduleid + '</directory>' +CRLF ;
&&											      + '  </activity>' +CRLF
&&										
&&													m.setting_tag = "";
&&														 + '      <setting>' + CRLF ;
&&												     + '        <level>activity</level>' + CRLF ;
&&												     + '        <activity>label_' + m.moduleid + '</activity>' + CRLF ;
&&												     + '        <name>label_' + m.moduleid + '_included</name>' + CRLF ;
&&												     + '        <value>1</value>' + CRLF ;
&&												     + '      </setting>' + CRLF ;
&&												     + '      <setting>' + CRLF ;
&&												     + '        <level>activity</level>' + CRLF ;
&&												     + '        <activity>label_' + m.moduleid + '</activity>' + CRLF ;
&&												     + '        <name>label_' + m.moduleid + '_userinfo</name>' + CRLF ;
&&												     + '        <value>0</value>' + CRLF ;
&&												     + '      </setting>' + CRLF 
&&										
&&											      
&&													if isnull(m.activity_tag) or isnull(m.setting_tag)
&&														m.activity_tag = "<strong>Warning: null field in bulletins " + m.moduleid + ".</strong><br />"+CRLF
&&														this.Log(m.activity_tag)
&&													endif
&&													
&&											    this.activity_list = this.activity_list + m.activity_tag
&&											    this.setting_list = this.setting_list + m.setting_tag
&&										
&&													
&&										
&&										
&&													=Bulletin(.T., lesson.doc, .T.)
&&										
&&										this.Warn("ToDo: lesson fields dependent on =Bulletin?")			
&&										
&&													m.label_text = m.bull_list + m.sidebar
&&													m.label_text = strtran(m.label_text, '&', '&'+'amp;')	&& Moodle's (PHP's?) XML parser squawks on naked ampersands.  This strtran must come first.
&&													m.label_text = strtran(m.label_text, '<', '&'+'lt;')
&&													m.label_text = strtran(m.label_text, '>', '&'+'gt;')
&&													
&&										&&			m.label_text = strconv(m.label_text, 9)	&& Convert to UTF-8
&&										
&&													m.label_name = 'Combined Bulletins for ' + alltrim(lesson.lesson)
&&										
&&													m.activity_folder =  "activities\label_" + m.moduleid 
&&										
&&													this.MakeFile("inforef.xml" , m.activity_folder, .F., "activities\label_")
&&													this.MakeFile("label.xml"   , m.activity_folder, .F., "activities\label_")
&&													this.MakeFile("filters.xml" , m.activity_folder, .F., "activities\label_")
&&													this.MakeFile("grades.xml"  , m.activity_folder, .F., "activities\label_")
&&													this.MakeFile("module.xml"  , m.activity_folder, .F., "activities\label_")
&&													this.MakeFile("roles.xml"   , m.activity_folder, .F., "activities\label_")
&&										
											endfunc





  *********************************************************************************
	procedure ExportLessonCategories(m.lesson_doc)
	
	
			this.Log("<h3>ExportLessonCategories for " + alltrim(lesson.id) + ": " + alltrim(lesson.lesson) + "</h3>")
		
			m.where_clause = ' '		&& Maybe add forstu, forfac fields?  What about forpub?
			m.order_by = ''

&&			if (not  this.vis_fac)
&&					&& this doesn't seem to work...oh, well, the bulletin filters seem to take care of it.
&&					m.where_clause = m.where_clause + ' and not (bul_cat.category = "Facilitator") '
&&			endif

				
		 	select bul_cat.* from dl!bul_cat ;
				where bul_cat.id in ;
					(select bul_catid from dl!bul_catcrs where courseid = this.courseid) ;
					and not(	bul_cat.exp_type == 'skip') ;
		 		order by sort_order, category ;
		 		into cursor cat
					
			&& this.Log("Found " + alltrim(str(_tally)) + " categories")
			
			scan

&&				if (cat.exp_type == 'combine')
&&					this.Log(" <b> === Export type: " + cat.exp_type + " === </b>")
&&					this.ExportLessonCategoryCombined()			&& Handles category title, etc.
&&				else 
					&& default behavior is 'single'
					this.ExportLessonCategoryBulletins()
&&				endif

			endscan
			
		
	endproc
	
	
	
	
	

	function ExportLessonCategoryBulletins()

		&& this.Log("ExportLessonCategoryBulletins()... Category:  "+ trim(cat.category) )
	
&&		m.where_clause = ' and forsch = .T. '		&& Maybe add forstu, forfac fields?  What about forpub?
		m.where_clause = ''		&& Maybe add forstu, forfac fields?  What about forpub?
		m.order_by = '	order by bcrs.sort_order, bcrs.bullfirst, b.id '
		
		&& Is this category all combined into one?
		this.combine = (cat.exp_type == 'combine')
		this.combined_output = ""	
		
		do case
			case this.vis_stu and this.vis_fac
				m.where_clause = m.where_clause + ' and (  b.forstu = .T. or  b.forfac = .T. )'

			case this.vis_stu 
				m.where_clause = m.where_clause + ' and b.forstu = .T. '

			case this.vis_fac
				m.where_clause = m.where_clause + ' and b.forfac = .T. '

			otherwise && This is kinda silly...but at least not confusing.
				m.where_clause = m.where_clause + ' and b.forstu = .F. and b.forfac = .F. '
				
		endcase

		
		select b.id as bulletinid, b.text, b.url, b.detail, b.b_css, b.exp_dont, ;
				bcrs.html, bcrs.bullfirst, bcrs.bulllast ;
			from dl!bulletin b ;
				join dl!bul_crs bcrs on b.id = bcrs.bulletinid ;
			where bcrs.courseid = this.courseid ;
				and b.bul_catid = cat.id ;
				and bcrs.bullfirst <= lesson.doc ;
				and bcrs.bulllast  >= lesson.doc ;
				and b.exp_dont = .F. ;
				&where_clause ;
			 	&order_by ;
			into cursor Bull

		if (_tally == 0 ) 
			&& this.Log("Suppressing category with no bulletins.")
			return 0
		endif

		this.Log("<h4>Category: " + trim(str(cat.id) )+ ". " + trim(cat.category )+ " (" + alltrim(str(_tally)) + " bulletins) (sort_order=" + alltrim(str(cat.sort_order)) + ")</h4>" )
		
		m.class_list = "dl_topic_category "
		
		m.classtag = [class="dl_topic_category ] + trim(cat.css_class) + ["]
		if (not empty (trim(cat.css_id)))
			m.class_list = m.class_list + trim(cat.css_id) + " "
		endif
		m.cat_header = '<h3 class="' + m.class_list + '">'+alltrim(cat.category)+ '</h3>'


		if (this.combine)
			this.combined_output = '<div class="' + m.class_list + '">' ;
				+ m.cat_header +CRLF ;	
				+ '<ul class="combined_bulletins">' + CRLF 
		else
			this.CreateLabel('<div class="' + m.class_list + '">' + m.cat_header+ '</div>', 0) 
		endif

		m.bull_count = 0
		
		scan

			if (Bull.exp_dont)
				this.Log("Skipping 'don't export' bulletin: " + alltrim(Bull.text) + " bulletins ")
				loop
			endif

			m.bull_count = m.bull_count + this.ExportBulletin()

		endscan


		if (this.combine)
			this.combined_output = this.combined_output + '</ul></div>'+CRLF
			this.CreateLabel(this.combined_output, 0) 
		endif

					
		return m.bull_count 
	endfunc


	function ExportBulletin()
		this.Log("ExportBulletin(): " + trim(str(Bull.bulletinid) )+ ". " + trim(Bull.text) )

		
		if isnull(Bull.detail) or empty(Bull.detail)
			m.text = this.GenHTML(Bull.text, bull.url)
			if (this.combine)
				this.combined_output = this.combined_output  + "<li>"+m.text+"</li>" +CRLF
			else
				this.CreateLabel(m.text, 1)
			endif

		else

			if (this.combine)
				this.combined_output = this.combined_output  + "<li>"+this.GenHTML(Bull.text, bull.url)+"</li>" +CRLF
				this.Warn("Bulletin detail page cannot be exported in a combined category! Consider moving to another category. " ;
					+ "<a href='" + URL('BulletinMenu') + "?courseid=" + this.courseid ;
					+ "&" + "bulletinid=" + alltrim(str(Bull.bulletinid)) ;
					+ "&" + "edit=bulletin" ;
					+ "'>EDIT BULLETIN " ;
					+ alltrim(str(Bull.bulletinid)) + "</a>" ) 
					
			else
				this.CreatePage(bull.text, 1, '', bull.detail)
			endif

		endif
		
		return 1
	endfunc



	&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
	&& Generates html from text and url  (Lifted from ../common/bulletin.prg 5/23/2014 15:51:59 )
	&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
	function GenHTML(m.text, m.url)
			&& text	= 'Visit the [Wierd Physics Site] for some ideas.'
			&& url	= 'http://phys.com'
			
			&& returns: html = 'Visit the <a href="http://phys.com">Wierd Physics Site</a> for some ideas.'
						
		m.url = alltrim(m.url)
		
	
	
			&& Link prefix to retrieve private documents:
			&& This URL also appears in /common/common.prg ... check there if you need to change this.
			
	*	&& This is how it should be...once we get VFP upgraded above 6.0:
	*	m.url = strtran(m.url, '<<private>>', ;
	*		URL('Get',lower(login.level)) + '?courseid='+m.courseid+'&'+'name=' , ;
	*		-1, -1, 2 )	&& -1, -1, 2 indicates case insensitive

		if (0 < at('<<', m.text) )
			this.Warn('FoxWeb tag in HTML:  ' + m.text)
		endif
		
		m.url = strtran(m.url, '<<private>>', ;
			URL('Get',lower(login.level)) + '?courseid='+m.courseid+'&'+'name=' )
		m.url = strtran(m.url, '<<Private>>', ;
			URL('Get',lower(login.level)) + '?courseid='+m.courseid+'&'+'name=' )
		m.url = strtran(m.url, '<<PRIVATE>>', ;
			URL('Get',lower(login.level)) + '?courseid='+m.courseid+'&'+'name=' )
	

		m.link = ''

		do case 
			case (m.url = "http:") or (m.url = "https:") 
				&&this.Warn("Full URL found: [&url]")
				m.link = trim(m.url)
			case (m.url = '/') 
				&&this.Warn("Absolute link found: [&url] Prepending http://" + Request.ServerVariables("SERVER_NAME") +"")
				m.link = "http://" + Request.ServerVariables("SERVER_NAME") + trim(m.url)
				&&this.Warn("Link to local file: " + m.link)
			case not empty(m.url)
				&&this.Warn("Relative URL found: [&url] Prepending http://" + Request.ServerVariables("SERVER_NAME") + "/" + trim(thiscrs.webpath) + '/' +"")
				m.link = "http://" + Request.ServerVariables("SERVER_NAME") + "/" + trim(thiscrs.webpath) + '/' + trim(m.url)
				&&this.Warn("Link to local file: " + m.link)
		endcase	

	
		
		if (empty(m.link))	
			&& this.Log("No URL to link text to.  OK.")
			return m.text
		endif

				
		if (0 < at('[', m.text) )
			&& m.msg = m.msg + 'convert [...] to a link.<br />'+CRLF
			m.changed_html = strtran(m.text, '[', '<a href="' + m.link + '">', 1,1)
			m.changed_html = strtran(m.changed_html, ']', '</a>', 1,1)
		else
			&& m.msg= m.msg + 'wrap entire string in a link.<br />'+CRLF
			m.changed_html = '<a href="' + m.link + '">' ;
				+ m.text + '</a>'
		endif

		&& n.b. We're not exporting include references to Moodle.  They were never used in DL. 

		&& 	this.Log('Linking text in bulletin: ' + m.changed_html)
	
	
		return m.changed_html
	endproc



	function CreateLabel(m.text, m.indent_level, m.name)	

			&& Can't use params in .fwx templates apparantly, so create redundant local vars:
			
			m.sectionid = alltrim(str(lesson.lesson_id)) 
			m.moduleid = this.NewModuleID()
			m.sectionnumber = alltrim(str(lesson.lesson_number))

			if empty(m.indent_level)
				m.indent = 0
			else
				m.indent = m.indent_level
			endif
				
			m.label_text = alltrim(m.text)
			if empty(m.name)
				m.label_name = m.label_text
			else
				m.label_name = m.name
			endif
			

			&& this.Log("CreateLabel(" m.moduleid + "." + m.label_text + ") (" + alltrim(str(len(m.label_text))) + ' chars' )

			m.label_name = this.KillTags(m.label_name)  && don't really want links in names, truncating can leave broken tags.  Note - this is not the label contents.  Not sure it even appears anywhere.
			if (len(m.label_name) >= 75) 
				m.label_name = left(m.label_name,75)
				&& this.log('Truncating name of ' + m.moduleid + ' text to 75 characters. (Actual content not affected) ' + alltrim(str(len(m.label_name))) + ' chars in: ' + m.label_name)
			endif

			m.activity_folder =  "activities\label_" + m.moduleid 
			
			&& this.Log("CreateLabel(" + m.moduleid + "." + m.label_text + ") in " + m.activity_folder  )

			this.ActivityTag(m.moduleid, m.sectionid, 'label', m.label_name, m.activity_folder)
			this.SettingTag (m.moduleid, 'label')
			
			this.MakeFile("inforef.xml" , m.activity_folder, .F., "activities\label_")
			this.MakeFile("label.xml"   , m.activity_folder, .F., "activities\label_")
			this.MakeFile("filters.xml" , m.activity_folder, .F., "activities\label_")
			this.MakeFile("grades.xml"  , m.activity_folder, .F., "activities\label_")
			this.MakeFile("module.xml"  , m.activity_folder, .F., "activities\label_")
			this.MakeFile("roles.xml"   , m.activity_folder, .F., "activities\label_")

	endfunc


	function KillTags(m.text)	&& Removes all HTML tags, leaving naked text. 
		do while .T.
			m.a = at('<', m.text)
			m.b = at('>', m.text)
			if ( m.a < 1 or m.a > m.b )
				&& no full tag found
				exit 
			endif
			m.text = left (m.text,m.a-1) + substr(m.text,m.b+1)
		enddo

		return m.text
	endfunc




	function CreatePage(m.text, m.indent_level, m.name, m.content)	

			&& Can't use params in .fwx templates apparantly, so create redundant local vars:
			
			m.sectionid = alltrim(str(lesson.lesson_id)) 
			m.moduleid = this.NewModuleID()
			m.sectionnumber = alltrim(str(lesson.lesson_number))

			&& this.Log("CreatePage()")
			
			
			if empty(m.indent_level)
				m.indent = 0
			else
				m.indent = m.indent_level
			endif
				
			m.page_text = alltrim(m.text)
			
			&& In moodle, the link won't be embedded.  It must be the entire activity text:
			m.page_text = strtran(m.page_text, '[', '' )   
			m.page_text = strtran(m.page_text, ']', '' )   

			if empty(m.name)
				m.page_name = m.page_text
			else
				m.page_name = m.name
			endif

			if (len(m.page_name) >= 250) 
				m.page_name = left(m.page_name,250) + "..."
				&&  this.log('Truncating name of ' + m.moduleid + ' text to 250 characters. (Actual content not affected) ' + alltrim(str(len(m.page_name))) + ' chars in: ' + m.page_name)
			endif
			
			m.page_content = m.content
			
			m.activity_folder =  "activities\page_" + m.moduleid 
			
			this.ActivityTag(m.moduleid, m.sectionid, 'page', m.page_name, m.activity_folder)
			this.SettingTag (m.moduleid, 'page')
			
			this.MakeFile("inforef.xml" , m.activity_folder, .F., "activities\page_")
			this.MakeFile("page.xml"   , m.activity_folder, .F., "activities\page_")
			this.MakeFile("grades.xml"  , m.activity_folder, .F., "activities\page_")
			this.MakeFile("module.xml"  , m.activity_folder, .F., "activities\page_")
			this.MakeFile("roles.xml"   , m.activity_folder, .F., "activities\page_")

	endfunc



	function ActivityTag(m.moduleid, m.sectionid, m.modulename, m.label_name, m.activity_folder)
			m.activity_tag = "";
	      + '  <activity>' +CRLF ; 
	      + '    <moduleid>' + m.moduleid + '</moduleid>' +CRLF ;
	      + '    <sectionid>' + m.sectionid + '</sectionid>' +CRLF ;
	      + '    <modulename>' + m.modulename + '</modulename>' +CRLF +CRLF;
	      + '    <title><![CDATA[' + m.label_name +  ']]></title>' +CRLF ;
	      + '    <directory>' + strtran(m.activity_folder, '\', '/')  + '</directory>' +CRLF ;
	      + '  </activity>' +CRLF

			if isnull(m.activity_tag) 
				m.activity_tag = "WARNING: null field in bulletins " + m.moduleid + " activity tag. Nothing to export."+CRLF
				this.Warn(m.activity_tag)
			endif

	    this.activity_list = this.activity_list + m.activity_tag
	endfunc



	function SettingTag(m.moduleid,  m.modulename)
			m.setting_tag = "";
				 + '      <setting>' + CRLF ;
		     + '        <level>activity</level>' + CRLF ;
		     + '        <activity>' + m.modulename + '_' + m.moduleid + '</activity>' + CRLF ;
		     + '        <name>' + m.modulename + '_' + m.moduleid + '_included</name>' + CRLF ;
		     + '        <value>1</value>' + CRLF ;
		     + '      </setting>' + CRLF ;
		     + '      <setting>' + CRLF ;
		     + '        <level>activity</level>' + CRLF ;
		     + '        <activity>' + m.modulename + '_' + m.moduleid + '</activity>' + CRLF ;
		     + '        <name>' + m.modulename + '_' + m.moduleid + '_userinfo</name>' + CRLF ;
		     + '        <value>0</value>' + CRLF ;
		     + '      </setting>' + CRLF 


			if isnull(m.setting_tag)
				m.activity_tag = "WARNING: null field in bulletins " + m.moduleid + ". Nothing to export."+CRLF
				this.Warn(m.activity_tag)
			endif
			
	    this.setting_list = this.setting_list + m.setting_tag
	endfunc	
	
	
	
  *********************************************************************************
	procedure PrepDatabase()


			&& This doesn't actually pan out.  Given this needs to run once ever, I'm not going to figure out how to do this.
			&& Just do the following manually.
			
			&& We'll try this - put ?init_db=1 in the URL to initialize the database.  Good luck.
			if empty(Request.QueryString('init_db'))
				return
			endif
			

		TRY
			use dl!qquestions exclusive again
			
			ALTER table dl!qquestions ADD COLUMN id int AUTOINC NEXTVALUE 200000 DEFAULT RECNO()+100000
			
		CATCH

		finally 
			use 
					
		endtry
	
			
	*		try                       
				close all
				open database \db\dl exclusive			
				use dl!lessons exclusive again 
				
				Alter Table dl!lessons add column lesson_id i
				this.Log("Adding lesson_id field to lessons_table ")
				Replace ALL lesson_id with Recno()+1000
				
				dimension maxid(1)
				maxid = 1001
				select max(recno())	from lessons into array maxid 
				maxid = maxid + 1
	
				Alter Table myTable alter column lesson_id i autoinc nextvalue maxid step 1
	
	
	* *   Catch to oError When .T.
	*    		m.body = m.body + "Error Updating Tables!<br />"+chr(13)+;
	*                   oError.Message+chr(13)+;
	*                   "Error #:"+Transform(oError.ErrorNo)+chr(13)+;
	*                   "Line #:"+Transform(oError.LineNo)+chr(13)+;
	*                   "Error #:"+Transform(oError.LineContents),48,"Error")
	*                   
	* 		catch
	* 			&& no problem...fields probably already exist.
	* 			
	* 		endtry
	
		use
	endproc


	procedure Log(m.msg)
		if ( 0 < at('</h',m.msg) + at('/div', m.msg) )
			&& Then we don't need a <br />
			this.msg = this.msg + m.msg  +CRLF
		else
			this.msg = this.msg + m.msg + '<br />' +CRLF
		endif
		
		return m.msg
	endproc		

	procedure Warn(m.msg)
		this.msg = this.msg + "<div class='warning'>" + m.msg + '</div>' +CRLF
		this.warnings = this.warnings + '<li>' + m.msg + '</li>'+CRLF
		return m.msg
	endproc		

	function NewModuleID
		this.current_activity_id = this.current_activity_id + 1
		return alltrim(str(this.current_activity_id ))
	endfunc
	
enddefine

