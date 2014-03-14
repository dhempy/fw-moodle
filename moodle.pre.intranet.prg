
#include '../common/common.h'

*============================================================================
*============================================================================
* Moodle Export functions:
*============================================================================
*============================================================================

** init - dhempy 6/5/2013 12:27:34 AM

set procedure to \db\common\common additive
set procedure to \db\common\bulletin additive




procedure MoodleExportCourse()
	=StaffOnly()
	
	local m.mbz
	m.mbz = createobject("MBZ")
	
	mbz.ExportCourse();
	
	m.Body = m.Body + "<pre>" + strtran(mbz.section_list,'<',"&lt;") + "</pre>" +CRLF
	
	=Merge("shell.htm")
	return 
endproc	


	






&& Moodle backup file
define class MBZ	as custom

	courseid = 'default'
	section_list = ''
	activity_list = ''
	msgs = ''
	backup_folder = NULL

	procedure Init()
		this.courseid = thiscrs.courseid
		m.Title = "Moodle Export - " + trim(thiscrs.coursename) +CRLF
	  this.PrepDatabase()
	  this.SetBackupFolder()
	endproc

	procedure Destroy()
	endproc






	
  *********************************************************************************
	procedure ExportCourse()
		** This is probably the only method you need to call, externally.

		this.msgs = this.msgs + "ExportCourse starting for " + this.courseid + ": " + trim(thiscrs.coursename) + " to folder [" + this.backup_folder + "]<br />"+CRLF
		
		this.ExportLessons()
		** this.ExportBulletins()
	endproc
	

  function SetBackupFolder()
  	if empty (this.backup_folder)
  		this.backup_folder = "\dl\intranet\moodle\backups\demo"
  	endif
  
  	return this.backup_folder
  		
  endfunc

  *********************************************************************************
  * Scans various content in the FoxWeb course, in prep for exporting to mbz by ExportMoodleCourse()
	procedure ScanFoxWebCourse
		this.msgs = this.msgs + "ScanFoxWebCourse starting<br />"
	endproc




  *********************************************************************************
  * Generates intermediate .xml files and zips to create a Moodle .bmz file. 
	procedure ExportMoodleCourse
		this.msgs = this.msgs + "ExportMoodleCourse starting<br />"
	endproc








	
  *********************************************************************************
  * Populates this.section_list.
  * Scans all bulletins in the course to create an XML fragment for inclusion within the main moodle_backup.xml file.
  *********************************************************************************
  
	procedure ExportLessons()
		
		this.msgs = this.msgs + "ExportLessons()...<br />"+CRLF
		
		this.msgs = this.msgs + "Exporting " + alltrim(str(ThisCrs.last_less)) + " lessons.<br />"+CRLF
	
		select doc , lesson, unit_number, unit, lesson_label, lesson_id ;
			from dl!lessons ;
			left outer join unit on unit.id = lessons.unit_id ;
			where lessons.courseid==m.courseid ;
			into cursor lesson ;
			order by doc
	
			
		local m.sections
		m.sections = ""
		 
		scan
			local m.unit
			if isnull(lesson.unit)
				m.unit = ""
			else
				m.unit = alltrim(str(lesson.unit_number)) + '. ' + alltrim(lesson.unit)
			endif
			
			
			m.section_tag = "";
	      + '  <section>' +CRLF ;
	      + '    <sectionid>' + alltrim(str(lesson.lesson_id)) + '</sectionid>' +CRLF ;
	      + '    <title>' +  alltrim(lesson.unit) + ': ' + alltrim(lesson.lesson) + '</title>' +CRLF ;
	      + '    <directory>sections/section_' + alltrim(str(lesson.lesson_id)) + '</directory>' +CRLF ;
	      + '  </section>' +CRLF
	      
	    m.sections = m.sections + m.section_tag
	
		endscan
	
		this.section_list = 	" <sections>" +CRLF +  m.sections + " </sections>" +CRLF;
			
	endproc



  *********************************************************************************
	procedure ExportBulletins()
		local m.start, m.stop, m.one_doc
	*	local m.AllBoards, m.OneBoard
	*	local m.first_day
	
	
		this.msgs = this.msgs + "ExportBulletins()...<br />"+CRLF
		
		
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
			
			return
			return
			return
			
	*		try                       
				use dl!lessons exclusive
				Alter Table lessons add column lesson_id i
				this.msg = this.msg + "Adding lesson_id field to lessons_table <br />"+CRLF
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

	
	
enddefine