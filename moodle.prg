
#include '../common/common.h'

*============================================================================
*============================================================================
* Moodle Export functions:
*============================================================================
*============================================================================

** init - dhempy 6/5/2013 12:27:34 AM

** set procedure to \db\common\common additive
**set procedure to \db\common\bulletin additive





&& Moodle backup file
define class MBZ	as custom

	export_title = 'FoxWeb Export'
	courseid = 'default'
	section_list = CRLF
	section_count = 0
	setting_list = CRLF
	activity_list = CRLF
	msg = ''
	backup_folder = ''
	backup_filename = ''
	backup_zipname = ''
	template_folder = ''	
	current_activity_id = 999
	question_list = ''
	answer_list = ''
	questionid =  ''	&& only used for MATCH questions, where question cursor is gone by the time questionid is needed in template.
	quiz_list = ''
	section_list = ''
		
	procedure Init()
		this.courseid = thiscrs.courseid
		this.export_title = "FoxWeb Export | " + strtran(ttoc(datetime(),3), 'T', ' ')
		
	  this.PrepDatabase()
	endproc

	procedure Destroy()
		&& close databases
	endproc






	
*********************************************************************************
  procedure ExportMoodleCourse
      * Generates intermediate .xml files and zips to create a Moodle .mbz file. 
      * This is probably the only functio you need to call.

		this.Log(	"ExportMoodleCourse starting for " + this.courseid + ": " + trim(thiscrs.coursename) + " to folder [" + this.backup_folder + "]" )

		&& Preserve output buffer and state...we'll be stomping all over the output buffer.
		local m.existing_content, m.old_buffer_state
		m.old_buffer_state = Response.Buffer
		Response.Buffer = .T.		&& Don't send immediately.
		m.existing_content = Response.OutputBuffer 
		Response.Clear


	  this.SetFolders('course')

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
		
		
		this.Log("NEXT: <em>Create sub folders for each lesson and populate.</em>")
		

		** this.ExportBulletins()

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

		this.Log(	"ExportQuestions starting for " + this.courseid + ": " + trim(thiscrs.coursename) + " to folder [" + this.backup_folder + "]" )

		&& Preserve output buffer and state...we'll be stomping all over the output buffer.
		local m.existing_content, m.old_buffer_state
		m.old_buffer_state = Response.Buffer
		Response.Buffer = .T.		&& Don't send immediately.
		m.existing_content = Response.OutputBuffer 
		Response.Clear



		m.top_qz_limit = Request.QueryString('limit')
		do case 
			case empty(m.top_qz_limit)
				m.top_qz_limit = 'top 10' 
					
			case m.top_qz_limit = 'none'
				m.top_qz_limit = '' 
			
			otherwise
				m.top_qz_limit = 'top ' + str(val(m.top_qz_limit))
				
		endcase 
		
		

		* request.q


		select &top_qz_limit qz.quizid, qz.title ;
			from dl!qquizes qz ;
			where quizid = this.courseid ;
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
		
		this.Log ("Exported " + alltrim(str(m.qscount)) + " questions for " + alltrim(str(m.qzcount)) + " quizzes ")
		

		this.MakeFile( this.courseid +"_questions.xml", .F., "questions.xml")


		this.Log('<div class="warning">TO DO: Develop the ESSAY templates.</div>')
		this.Log('<div class="warning">TO DO: Create quizzes to contain the questions.  (Maybe a separate script?) </div>')


		&& Restore any prior content and buffer state:
		Response.Clear
		Response.Buffer       = m.old_buffer_state 
		Response.OutputBuffer = m.existing_content
		
 		Server.AddScriptTimeout(10, .T.)		
		return
		
	endproc






	function ExportSection()

				this.Log ("<br /><div class='notice'><h2>Export section " + qsect.sectionid + " at " + ttoc(datetime()) + "</h2>"  )
				
				Server.AddScriptTimeout(5, .T.)
	
				this.question_list = ''
				this.answer_list = ''
				this.questionid =  ''
		
				select qques.* ;
					from dl!qquestions qques ;
					where qques.questionid = qsect.sectionid ;
					order by questionid ;
					into cursor qques
				
				q_count = 0
				q_rows = reccount()
				
				scan     && questions in section
					q_count = q_count + 1
					
					this.Log ("<h3>Export question " + qques.questionid + " (" + qsect.s_type + ") " + qques.qs_text + '</h3>' )
					m.qscount = m.qscount + 1
					
					if (qsect.s_type != 'MATCH')
						this.answer_list = ''		&& These build through the entire section, and must be retained until the end of the section.
					endif
				
					&& Collect answers in qchoices:					
					select qchoices.* ;
						from dl!qchoices ;
						where qchoices.choiceid = qques.questionid ;
						order by choiceid ;
						into cursor q_choice
						
					scan 
						this.Log("Exporting answer choice " + q_choice.choiceid + ": " + q_choice.ch_text)
						this.answer_list = this.answer_list + this.MakeFile('', '', 'answer.choice'   ;
								+ iif( qsect.s_type = 'MATCH', '.MATCH', '' )  ;
								+ iif( qsect.s_type = 'ESSAY', '.ESSAY', '' )  ;
								+ '.xml')
					endscan
					
				
					if (qsect.s_type = 'TEXT') 
						&& Collect answers in qkey:					
						select qkey.* ;
							from dl!qkey ;
							where qkey.keyid = qques.questionid ;
							order by keyid ;
							into cursor q_key
							
						scan 
							this.Log("Exporting answer key " + q_key.keyid + ": " + q_key.k_text)
							this.answer_list = this.answer_list + this.MakeFile('', '', 'answer.key.xml')
						endscan
				
					endif

 				  this.Log ("Question " + str(q_count) + " of  " + str(q_rows) + " in section " + qsect.sectionid  )		

					if (qsect.s_type != 'MATCH'  or (q_count = q_rows) )		&& Only fill matching templates on the last question of the section.
						this.ExportQuestion()	&& combines question data with this.answer_list from keys and choices.
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
			 
			 if (not (qsect.s_type = 'MC' or qsect.s_type = 'TEXT' or qsect.s_type = 'MATCH' or qsect.s_type = 'ESSAY'))
			 	this.Log('<div class="notice">We do not have a template for ' + qsect.s_type + ' yet.</div>')
			 	return
			 endif
			 
			 
			m.question = this.MakeFile('', '', 'question.' + trim(qsect.s_type) + '.xml')
			this.question_list = this.question_list + m.question
			
	endfunc
	

  function SetFolders(m.subfolder)
 
		&& param m.subfolder, if given, is the alternate folder name, for both template and backup folders.

		&& Set up this.backup_folder: 			=========================
		
		if empty(m.subfolder)
			this.Log("Error: no subfolder given to this.SetFolders()")
			return
		endif

		this.MakePath("\script_data\moodle")	&& THis is optimistic, as we probably lack permissions. Do that on your own.
		this.MakePath("\script_data\moodle\" + m.subfolder) 	&& THis is optimistic, as we probably lack permissions. Do that on your own.
		this.backup_folder   = "\script_data\moodle\" + m.subfolder + "\" + ThisCrs.courseid
		this.backup_filename = ThisCrs.courseid + ".mbz"

		m.backup_folder = this.backup_folder
		
		this.Log("rmdir /s /q &backup_folder")

&& 		run rmdir /s /q &backup_folder   && This causes bizarre errors.

		this.MakePath(this.backup_folder)
  


		&& Set up this.template_folder: 			=========================

		this.template_folder = '/db/moodle/template/' + m.subfolder			&& assumes relative to the called script, probably under /dl/intranet...
  		
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
		* MakeFile() returns the generated content)
		
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


		m.bytes = alltrim(str(len(m.output)))

		if (empty(m.dest_fname)) 		
			this.Log("Fulfilled <tt>&src_fname</tt> to memory -- &bytes bytes" )
		
		else 
			&& strconv(...,9)  Converts to UTF-8 -- Only do this for file writes!  If you do it for returned content, that later gets converted again by MakeFile(to disk), it gets corrupted.
			STRTOFILE( strconv(m.output, 9)  , m.dest) 

			if (!file(m.dest))
				this.Log("<strong class='error'>ERROR: Could not create &dest from &src</strong>")
			else
				this.Log("Created <tt>&dest</tt> --  &bytes bytes" )
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













  *********************************************************************************
  * Scans various content in the FoxWeb course, in prep for exporting to mbz by ExportMoodleCourse()
	procedure ScanFoxWebCourse
		this.Log("ScanFoxWebCourse starting")
		
		this.ScanLessons()

	endproc




	
  *********************************************************************************
  * Populates this.section_list and this.setting_list.
  * Scans all bulletins in the course to create an XML fragment for inclusion within the main moodle_backup.xml file.
  * It also creates sub folders for each lesson.  Ideally, this should fall under an Export function, not a Scan function,
  * but let's face it...this is a one-and-done project!
  *********************************************************************************
  
	procedure ScanLessons()
		
		this.Log("ScanLessons()...")
		
		this.Log("Exporting " + alltrim(str(ThisCrs.last_less)) + " lessons.")
	

		m.top_limit = 'top 10'
		m.top_limit = ''
		
 		select &top_limit doc , lesson, unit_number, unit, lesson_label, lesson_id, lesson_number ;
			from dl!lessons ;
			left outer join unit on unit.id = lessons.unit_id ;
			where lessons.courseid==m.courseid ;
			into cursor lesson ;
			order by doc
	
			
		this.section_count = 0
		
		scan
			this.ExportLesson()
			this.ExportLessonActivities()	
		
			this.section_count = this.section_count + 1
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


	function ExportLessonActivities()	

&&		this.activity_list = this.activity_list + "TODO: 	ExportLessonActivities() for " + lesson.lesson + "<br />"+CRLF


			m.sectionid = alltrim(str(lesson.lesson_id)) 
			m.activityid = this.NewActivityID()
			
			m.activity_tag = "";
	      + '  <activity>' +CRLF ;
	      + '    <moduleid>' + m.activityid + '</moduleid>' +CRLF ;
	      + '    <sectionid>' + m.sectionid + '</sectionid>' +CRLF ;
	      + '    <modulename>label</modulename>' +CRLF ;
	      + '    <title>' + alltrim(lesson.lesson) + ' Bulletins </title>' +CRLF ;
	      + '    <directory>activities/label_' + m.activityid + '</directory>' +CRLF ;
	      + '  </activity>' +CRLF

			m.setting_tag = "";
				 + '      <setting>' + CRLF ;
		     + '        <level>activity</level>' + CRLF ;
		     + '        <activity>label_' + m.activityid + '</activity>' + CRLF ;
		     + '        <name>label_' + m.activityid + '_included</name>' + CRLF ;
		     + '        <value>1</value>' + CRLF ;
		     + '      </setting>' + CRLF ;
		     + '      <setting>' + CRLF ;
		     + '        <level>activity</level>' + CRLF ;
		     + '        <activity>label_' + m.activityid + '</activity>' + CRLF ;
		     + '        <name>label_' + m.activityid + '_userinfo</name>' + CRLF ;
		     + '        <value>0</value>' + CRLF ;
		     + '      </setting>' + CRLF 

	      
			if isnull(m.activity_tag) or isnull(m.setting_tag)
				m.activity_tag = "<strong>Warning: null field in bulletins " + m.activityid + ".</strong><br />"+CRLF
				this.Log(m.activity_tag)
			endif
			
	    this.activity_list = this.activity_list + m.activity_tag
	    this.setting_list = this.setting_list + m.setting_tag

			m.activity_folder =  "activities\label_" + m.activityid 
			

		
			=Bulletin(.T., lesson.doc, .T.)
			
			m.label_text = m.bull_list + m.sidebar
			m.label_text = strtran(m.label_text, '&', '&'+'amp;')	&& Moodle's (PHP's?) XML parser squacks on naked ampersands.  This strtran must come first.
			m.label_text = strtran(m.label_text, '<', '&'+'lt;')
			m.label_text = strtran(m.label_text, '>', '&'+'gt;')
			
&&			m.label_text = strconv(m.label_text, 9)	&& Convert to UTF-8

			this.MakeFile("inforef.xml" , m.activity_folder, .F., "activities\label_")
			this.MakeFile("label.xml"   , m.activity_folder, .F., "activities\label_")
			this.MakeFile("filters.xml" , m.activity_folder, .F., "activities\label_")
			this.MakeFile("grades.xml"  , m.activity_folder, .F., "activities\label_")
			this.MakeFile("module.xml"  , m.activity_folder, .F., "activities\label_")
			this.MakeFile("roles.xml"   , m.activity_folder, .F., "activities\label_")

	endfunc


  *********************************************************************************
	procedure ExportBulletins()
		local m.start, m.stop, m.one_doc
	*	local m.AllBoards, m.OneBoard
	*	local m.first_day
	
	
		this.Log("ExportBulletins()...")
		
		
	&&	for m.one_doc = 1 to ThisCrs.last_less
		for m.one_doc = 1 to 3		&&&&&&&&& limit to three during testing.
			m.body = m.body + "<hr /><div class='box'><h2>Lesson " + alltrim(str(m.one_doc)) + " </h2>"+CRLF
			=Bulletin(.T., str(m.one_DOC), .T.)
			m.body = m.body + "<div class='box'>" + m.bull_list + "</div>" +CRLF
			m.body = m.body + "<div class='box'>" + m.sidebar + "</div>" +CRLF
			m.body = m.body + "</div>"+CRLF
			
		endfor
	
		m.body = m.body + "</ul>"+CRLF
		
		m.AllBoards = ''
		
		return 
					
		for m.one_doc = m.start to m.stop
			HTML_out = ''
			m.DocBottom = ''
			=Bulletin(.T., str(m.one_DOC))
			m.OneBoard = HTML_out
			
			if m.one_doc = m.start
				clip_start = 1
			else
			clip_start = at('<!-- DayStart Do not edit this line! -->',m.OneBoard)
			endif
			if m.one_doc = m.stop
				clip_stop = len(m.OneBoard)+1
			else
				clip_stop  = at('<!-- DayStop  Do not edit this line! -->' ,m.OneBoard)
			endif
			m.AllBoards ;
				= m.AllBoards ;
				+ substr(m.OneBoard,clip_start, clip_stop-clip_start) +iif(m.one_doc = m.stop,'','<hr>')+CRLF;
				+ CRLF + CRLF 
	
	
				
		endfor
		
		HTML_out = m.AllBoards
	
	
	*!*		=Merge('shell.htm')
	endproc
	
	
	
	
	
	
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
		this.msg = this.msg + m.msg + '<br />' +CRLF
		return m.msg
	endproc		

	function NewActivityID
		this.current_activity_id = this.current_activity_id + 1
		return alltrim(str(this.current_activity_id ))
	endfunc
	
enddefine

