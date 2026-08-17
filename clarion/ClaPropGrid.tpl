#TEMPLATE(ClaPropGrid,'Direct2D Property Grid'),FAMILY('ABC')
#!=============================================================================
#!  ClaPropGrid  -  a Direct2D property grid for Clarion 12 (32-bit).
#!
#!  PROPGRID.DLL renders the grid; PropGridClass (PropGrid.inc / .clw) is the
#!  Clarion wrapper.  Three templates ship here:
#!
#!    PropGridGlobal        (APPLICATION) - add ONCE per application.  Places
#!                          the class (ABC category 'PROPGRID'), which is what
#!                          generates the _PropGridLinkMode_ / _PropGridDllMode_
#!                          project defines, and adds propgrid.lib to the
#!                          project.  In a single-EXE app the control templates
#!                          are self-sufficient without it (undefined LINK/DLL
#!                          modes mean "compile the class in"), but in a
#!                          multi-DLL suite it must be on EVERY app.
#!
#!    PropertyGridControl   (CONTROL, MULTI) - drops a REGION on the window and
#!                          builds a grid over it from a list of variables /
#!                          dictionary fields you configure at design time.
#!
#!    FormToPropertyGrid    (EXTENSION, PROCEDURE) - converts the controls that
#!                          are ALREADY on the window into grid rows at run
#!                          time (PropGridClass.BuildFromWindow) and hides the
#!                          originals.  No design-time field list to maintain.
#!
#!  REQUIRED FILES - copy to a folder on the Clarion redirection path (the app
#!  folder, or clarion12\accessory\libsrc\win), all ANSI:
#!      PropGrid.inc   PropGrid.clw
#!  and put propgrid.dll beside the EXE, propgrid.lib where the linker finds
#!  it.  See INSTALL.md.
#!
#!  build 2026-08-16a
#!=============================================================================
#!#############################################################################
#!  APPLICATION EXTENSION - PropGridGlobal
#!#############################################################################
#EXTENSION(PropGridGlobal,'ClaPropGrid - global settings (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('ClaPropGrid')
      #DISPLAY('Direct2D Property Grid - build 2026-08-16a')
      #DISPLAY('')
      #DISPLAY('Add this extension ONCE, at the application level.  It places')
      #DISPLAY('PropGridClass in the build (ABC class category PROPGRID) and')
      #DISPLAY('adds propgrid.lib to the project.  In a multi-DLL suite EVERY')
      #DISPLAY('application in the suite needs it, or that app quietly')
      #DISPLAY('compiles a private copy of the class.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%PGGDisable,DEFAULT(0),AT(10)
      #PROMPT('Add propgrid.&lib to the project',CHECK),%PGGProject,DEFAULT(1),AT(10)
      #PROMPT('Import &library name:',@s64),%PGGLibName,DEFAULT('propgrid.lib')
    #ENDBOXED
    #BOXED('PropGridClass location')
      #INSERT(%AbcLibraryPrompts(ABC))
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%BeforeGenerateApplication),WHERE(%PGGDisable=0)
  #CALL(%AddCategory(ABC),'PROPGRID')
  #CALL(%SetCategoryLocationFromPrompts(ABC),'PROPGRID','PropGrid','')
  #PDEFINE('_PropGridModesSet_',1)
#ENDAT
#!
#AT(%AfterGlobalIncludes),WHERE(%PGGDisable=0)
INCLUDE('PropGrid.inc'),ONCE
#ENDAT
#!
#AT(%CustomGlobalDeclarations),WHERE(%PGGDisable=0 AND %PGGProject=1 AND %PGGLibName)
  #PROJECT(%PGGLibName)
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - PropertyGridControl
#!#############################################################################
#!  Drops a REGION; the Direct2D grid is created over it and tracks it on
#!  every resize.  MULTI, so a window may carry several independent grids -
#!  every generated label carries %ActiveTemplateInstance.
#!#############################################################################
#CONTROL(PropertyGridControl,'Property Grid on a window'),WINDOW,MULTI,DESCRIPTION('[PropGrid] ' & %PGObject),HLP('~ClaPropGrid.htm')
  CONTROLS
    REGION,AT(,,200,160),USE(?PropGridRegion)
  END
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable this property grid',CHECK),%PGDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%PGObject,REQ,DEFAULT('PropGrid' & %ActiveTemplateInstance)
      #PROMPT('&Class name:',@s64),%PGClass,REQ,DEFAULT('PropGridClass')
    #ENDBOXED
    #BOXED('Behaviour')
      #PROMPT('&Live sync - write every edit into the variables at once',CHECK),%PGLiveSync,DEFAULT(1),AT(10)
      #PROMPT('&Timer interval, hundredths of a second (0 = leave the window alone):',SPIN(@n4,0,1000,5)),%PGTimer,DEFAULT(10)
      #DISPLAY('The grid pumps its events from EVENT:Timer, so the window needs')
      #DISPLAY('a timer.  The class only sets one if the window has none.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Appearance')
    #INSERT(%PGAppearancePrompts)
  #ENDTAB
  #TAB('&Colours')
    #INSERT(%PGColourPrompts)
  #ENDTAB
  #TAB('&Fields')
    #BOXED('Rows')
      #DISPLAY('One row per entry.  "Variable / field" takes a dictionary')
      #DISPLAY('column (use the lookup button) or any Clarion variable that is')
      #DISPLAY('in scope in this procedure - a local, a global, LOC:Whatever.')
      #DISPLAY('Entries that share a Category name are merged into one header.')
    #ENDBOXED
    #BUTTON('&Properties...'),MULTI(%PGField,%PGFieldCategory & ' / ' & %PGFieldVar & '  [' & %PGFieldEditor & ']'),INLINE
      #PROMPT('&Variable / field:',FIELD),%PGFieldVar,REQ
      #PROMPT('&Display name (blank = derived from the variable):',@s64),%PGFieldName
      #PROMPT('&Category:',@s64),%PGFieldCategory,DEFAULT('General'),REQ
      #PROMPT('&Editor:',DROP('Text|Password|Drop list|Checkbox|Radio|Slider|Spin|Button|Color|Date|Time|Multiline|Read only')),%PGFieldEditor,DEFAULT('Text')
      #ENABLE(%PGFieldEditor='Drop list' OR %PGFieldEditor='Radio')
        #PROMPT('C&hoices, pipe separated (Red|Green|Blue):',@s255),%PGFieldChoices
      #ENDENABLE
      #ENABLE(%PGFieldEditor='Slider' OR %PGFieldEditor='Spin')
        #PROMPT('Range &low:',@n-13.4),%PGFieldLow,DEFAULT(0)
        #PROMPT('Range h&igh:',@n-13.4),%PGFieldHigh,DEFAULT(100)
        #PROMPT('&Step:',@n-13.4),%PGFieldStep,DEFAULT(1)
      #ENDENABLE
      #ENABLE(%PGFieldEditor='Date' OR %PGFieldEditor='Time')
        #PROMPT('&Picture (blank = @d17 for Date, @t4 for Time):',@s20),%PGFieldPicture
      #ENDENABLE
      #PROMPT('&Read only',CHECK),%PGFieldReadOnly,DEFAULT(0),AT(10)
      #PROMPT('D&escription (shown in the description pane):',@s255),%PGFieldDesc
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Parse-time state: this instance's REGION field equate, the style bit mask,
#! and the de-duplicated list of category names.
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%PGRegion)
  #DECLARE(%PGStyleNum)
  #DECLARE(%PGCatNo)
  #DECLARE(%PGRowNo)
  #IF(VAREXISTS(%PGCats) = 0)
    #DECLARE(%PGCats),MULTI,UNIQUE
  #ENDIF
  #FREE(%PGCats)
  #FOR(%Control),WHERE(%ControlInstance = %ActiveTemplateInstance)
    #SET(%PGRegion,%Control)
  #ENDFOR
  #SET(%PGStyleNum,%PGStyleNumber())
  #FOR(%PGField)
    #ADD(%PGCats,%PGFieldCategory)
  #ENDFOR
  #IF(%PGClass = '')
    #SET(%PGClass,'PropGridClass')
  #ENDIF
#ENDAT
#!
#! The class TYPE must be visible in EVERY module, so the include goes to
#! %AfterGlobalIncludes (PROGRAM-module global scope), not
#! %CustomGlobalDeclarations.  ONCE de-dupes against the global extension and
#! against every other ClaPropGrid instance in the app.
#AT(%AfterGlobalIncludes),WHERE(%PGDisable=0)
INCLUDE('PropGrid.inc'),ONCE
#ENDAT
#!
#AT(%CustomGlobalDeclarations),WHERE(%PGDisable=0)
  #PROJECT('propgrid.lib')
#ENDAT
#!
#AT(%DataSection),WHERE(%PGDisable=0)
%PGObject            %PGClass                                    ! ClaPropGrid object
PGResize:%PGObject   EQUATE(EVENT:User + 300 + %ActiveTemplateInstance) ! private "the window settled, re-place me" event
  #FOR(%PGCats)
    #SET(%PGCatNo,INSTANCE(%PGCats))
PGCat:%ActiveTemplateInstance:%PGCatNo LONG                       ! category '%PGCats'
  #ENDFOR
  #FOR(%PGField)
    #SET(%PGRowNo,INSTANCE(%PGField))
PGRow:%ActiveTemplateInstance:%PGRowNo LONG                       ! row for %PGFieldVar
  #ENDFOR
#ENDAT
#!
#! PRIORITY(8600): ABC opens the window at 8000, restores its INI size at 8250
#! and runs the field templates at 8500, so at 8600 the REGION is at its final
#! size and PROP:Handle is live.
#AT(%WindowManagerMethodCodeSection,'Init','(),BYTE'),PRIORITY(8600),WHERE(%PGDisable=0),DESCRIPTION('ClaPropGrid: create the property grid')
  %PGObject.LiveSync      = 0                                     ! these rows are not bound to controls
  %PGObject.TimerInterval = %PGTimer
  IF %PGObject.Init(%Window, %PGRegion, %PGStyleNum)              ! PGS_ style bits
  #INSERT(%PGEmitAppearance,%PGObject)
  #FOR(%PGCats)
    #SET(%PGCatNo,INSTANCE(%PGCats))
    PGCat:%ActiveTemplateInstance:%PGCatNo = %PGObject.AddCategory('%PGCats')
  #ENDFOR
  #FOR(%PGField)
    #SET(%PGRowNo,INSTANCE(%PGField))
    #SET(%PGCatNo,0)
    #FOR(%PGCats),WHERE(UPPER(%PGCats) = UPPER(%PGFieldCategory))
      #SET(%PGCatNo,INSTANCE(%PGCats))
      #BREAK
    #ENDFOR
    PGRow:%ActiveTemplateInstance:%PGRowNo = %PGObject.AddProperty(PGCat:%ActiveTemplateInstance:%PGCatNo,'%(%PGDefaultLabel())',%(%PGEditorEquate(%PGFieldEditor)),'')
    #IF(%PGFieldChoices)
    %PGObject.SetChoices(PGRow:%ActiveTemplateInstance:%PGRowNo,'%PGFieldChoices')
    #ENDIF
    #IF(%PGFieldEditor = 'Slider' OR %PGFieldEditor = 'Spin')
    %PGObject.SetRange(PGRow:%ActiveTemplateInstance:%PGRowNo,%PGFieldLow,%PGFieldHigh,%PGFieldStep)
    #ENDIF
    #IF(%PGFieldDesc)
    %PGObject.SetDescription(PGRow:%ActiveTemplateInstance:%PGRowNo,'%PGFieldDesc')
    #ENDIF
    #IF(%PGFieldReadOnly)
    %PGObject.SetReadOnly(PGRow:%ActiveTemplateInstance:%PGRowNo,1)
    #ENDIF
  #ENDFOR
    #EMBED(%PGAfterInit,'ClaPropGrid: after the grid is built (add your own rows here)'),%ActiveTemplateInstance
    DO PGLoad:%PGObject
  END
#ENDAT
#!
#! Self-contained CASE EVENT() at PRIORITY(2000) - ABOVE the framework's own
#! LOOP/CASE scaffolding, which is registered at 2500 (ABWINDOW.TPW:563).
#! Using 2500 interleaves and produces a duplicate CASE EVENT().
#! EVENT:Sized POSTs a private event instead of repositioning directly,
#! because at the top of TakeWindowEvent the ABC resizer has not yet moved
#! the REGION, so its PROP:Width is still the OLD size.
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%PGDisable=0),DESCRIPTION('ClaPropGrid: event pump and resize')
  CASE EVENT()
  OF EVENT:Timer
    IF %PGObject.TakeEvent()
      #EMBED(%PGOnGridEvent,'ClaPropGrid: the grid raised an event'),%ActiveTemplateInstance
  #IF(%PGLiveSync)
      DO PGSave:%PGObject
  #ELSE
      !  Live sync is off - DO PGSave:%PGObject yourself (e.g. on your OK button).
  #ENDIF
    END
  OF EVENT:Sized
    POST(PGResize:%PGObject)
  OF PGResize:%PGObject
    %PGObject.Reposition()
  END
#ENDAT
#!
#! PRIORITY(7500) is above ABC's "Kill already called" short-stop (5100), and
#! PropGridClass.Kill is idempotent anyway.
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(7500),WHERE(%PGDisable=0),DESCRIPTION('ClaPropGrid: destroy the property grid')
%PGObject.Kill()
#ENDAT
#!
#! The two transfer ROUTINEs.  They live in the procedure, so ThisWindow's
#! methods can DO them - exactly like ABC's own "Do DefineListboxStyle"
#! (ABWINDOW.TPW:438).
#AT(%ProcedureRoutines),WHERE(%PGDisable=0)
!---------------------------------------------------------------------------
PGLoad:%PGObject ROUTINE
!  variables -> grid.  Called once after the grid is built; call it again
!  yourself (DO PGLoad:%PGObject) whenever the variables change behind the
!  grid's back.
  #EMBED(%PGBeforeLoad,'ClaPropGrid: before loading the grid from the variables'),%ActiveTemplateInstance
  #FOR(%PGField)
    #SET(%PGRowNo,INSTANCE(%PGField))
    #CASE(%PGFieldEditor)
    #OF('Date')
    #OROF('Time')
  %PGObject.SetValue(PGRow:%ActiveTemplateInstance:%PGRowNo,FORMAT(%PGFieldVar,%(%PGFieldPictureToUse())))
    #OF('Checkbox')
  %PGObject.SetValue(PGRow:%ActiveTemplateInstance:%PGRowNo,CHOOSE(%PGFieldVar = 1,'1','0'))
    #OF('Button')
  %PGObject.SetValue(PGRow:%ActiveTemplateInstance:%PGRowNo,'%(%PGDefaultLabel())')
    #ELSE
  %PGObject.SetValue(PGRow:%ActiveTemplateInstance:%PGRowNo,CLIP(LEFT(%PGFieldVar)))
    #ENDCASE
  #ENDFOR
  #EMBED(%PGAfterLoad,'ClaPropGrid: after loading the grid from the variables'),%ActiveTemplateInstance
  %PGObject.Redraw()
!---------------------------------------------------------------------------
PGSave:%PGObject ROUTINE
!  grid -> variables.  Called from the timer when Live sync is on; call it
!  yourself (DO PGSave:%PGObject) from your OK button otherwise.
  #EMBED(%PGBeforeSave,'ClaPropGrid: before saving the grid into the variables'),%ActiveTemplateInstance
  #FOR(%PGField)
    #SET(%PGRowNo,INSTANCE(%PGField))
    #IF(%PGFieldReadOnly = 0 AND %PGFieldEditor <> 'Read only' AND %PGFieldEditor <> 'Button')
      #CASE(%PGFieldEditor)
      #OF('Date')
      #OROF('Time')
  %PGFieldVar = DEFORMAT(CLIP(%PGObject.GetValue(PGRow:%ActiveTemplateInstance:%PGRowNo)),%(%PGFieldPictureToUse()))
      #OF('Checkbox')
  %PGFieldVar = CHOOSE(CLIP(%PGObject.GetValue(PGRow:%ActiveTemplateInstance:%PGRowNo)) = '1',1,0)
      #ELSE
  %PGFieldVar = CLIP(%PGObject.GetValue(PGRow:%ActiveTemplateInstance:%PGRowNo))
      #ENDCASE
    #ENDIF
  #ENDFOR
  #EMBED(%PGAfterSave,'ClaPropGrid: after saving the grid into the variables'),%ActiveTemplateInstance
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - FormToPropertyGrid
#!#############################################################################
#!  Runtime reflection: PropGridClass.BuildFromWindow walks FIRSTFIELD() to
#!  LASTFIELD(), turns every supported control into a grid row (label taken
#!  from the PROMPT / STRING in front of it), tags the row with the control's
#!  field equate and hides the original.  So this template is almost entirely
#!  configuration - there is no design-time field list to keep in step with
#!  the window.
#!#############################################################################
#EXTENSION(FormToPropertyGrid,'Convert form controls to a Property Grid'),PROCEDURE,HLP('~ClaPropGrid.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable this template',CHECK),%F2PDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%F2PObject,REQ,DEFAULT('FormGrid' & %ActiveTemplateInstance)
      #PROMPT('&Class name:',@s64),%F2PClass,REQ,DEFAULT('PropGridClass')
    #ENDBOXED
    #BOXED('Placement')
      #PROMPT('&Where:',DROP('Fill client area|Dock left|Dock right|Over a region control')),%F2PPlace,DEFAULT('Dock right')
      #ENABLE(%F2PPlace='Dock left' OR %F2PPlace='Dock right')
        #PROMPT('Docked wid&th in pixels:',SPIN(@n4,60,2000,10)),%F2PDockWidth,DEFAULT(300)
      #ENDENABLE
      #ENABLE(%F2PPlace<>'Over a region control')
        #PROMPT('Hori&zontal margin (px):',SPIN(@n3,0,200,1)),%F2PMarginX,DEFAULT(4)
        #PROMPT('&Vertical margin (px):',SPIN(@n3,0,200,1)),%F2PMarginY,DEFAULT(4)
      #ENDENABLE
      #ENABLE(%F2PPlace='Over a region control')
        #PROMPT('&Region control:',CONTROL),%F2PRegion
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Behaviour')
    #BOXED('Conversion')
      #PROMPT('&Hide the original controls (and their prompts)',CHECK),%F2PHide,DEFAULT(1),AT(10)
      #PROMPT('&Live sync - write every edit straight back to the control',CHECK),%F2PLiveSync,DEFAULT(0),AT(10)
      #PROMPT('Default &category name:',@s64),%F2PCategory,DEFAULT('General'),REQ
      #PROMPT('&Timer interval, hundredths of a second (0 = leave the window alone):',SPIN(@n4,0,1000,5)),%F2PTimer,DEFAULT(10)
    #ENDBOXED
    #BOXED('Controls to leave alone')
      #DISPLAY('Anything listed here keeps working exactly as it does now -')
      #DISPLAY('it is neither converted into a row nor hidden.')
      #BUTTON('E&xclude controls'),MULTI(%F2PExclude,%F2PExcludeCtl),INLINE
        #PROMPT('&Control:',CONTROL),%F2PExcludeCtl,REQ
      #ENDBUTTON
    #ENDBOXED
  #ENDTAB
  #TAB('&Lookups')
    #BOXED('Lookup trios as drop-down rows')
      #DISPLAY('The classic Clarion lookup is three controls: an ENTRY holding')
      #DISPLAY('the CODE, a "..." BUTTON that opens a select browse, and a')
      #DISPLAY('STRING showing the DESCRIPTION.  Listed here, the three become')
      #DISPLAY('ONE drop-down row that shows the description and writes the code')
      #DISPLAY('back - no browse needed.  All three controls are excluded from')
      #DISPLAY('the automatic conversion and hidden.')
      #DISPLAY('')
      #DISPLAY('The lookup file is read once, when the window opens, so this')
      #DISPLAY('suits code tables (departments, states, statuses) - not files')
      #DISPLAY('with thousands of records.  The scan stops at the object''s')
      #DISPLAY('MaxScanItems (500 by default); leave the browse button alone for')
      #DISPLAY('anything bigger.')
      #BUTTON('Lookup &drop-downs...'),MULTI(%F2PLookup,%F2PLookupCode & ' -> ' & %F2PLookupFile & '.' & %F2PLookupDescFld),INLINE
        #BOXED('The three controls on THIS window')
          #PROMPT('&Code control (the ENTRY holding the code):',CONTROL),%F2PLookupCode,REQ
          #PROMPT('Lookup &button (the "..." - hidden, optional):',CONTROL),%F2PLookupBtn
          #PROMPT('&Description control (hidden, optional):',CONTROL),%F2PLookupDesc
        #ENDBOXED
        #BOXED('The lookup file')
          #PROMPT('&File:',FILE),%F2PLookupFile,REQ
          #PROMPT('&Order by key (blank = record order):',KEY(%F2PLookupFile)),%F2PLookupKey
          #PROMPT('Cod&e field (goes into the code control):',FIELD(%F2PLookupFile)),%F2PLookupCodeFld,REQ
          #PROMPT('Descri&ption field (what the row shows):',FIELD(%F2PLookupFile)),%F2PLookupDescFld,REQ
        #ENDBOXED
        #BOXED('Row')
          #PROMPT('&Label (blank = the prompt in front of the code control):',@s64),%F2PLookupLabel
          #PROMPT('C&ategory (blank = the default category):',@s64),%F2PLookupCat
          #PROMPT('Descrip&tion (shown in the description pane):',@s255),%F2PLookupTip
        #ENDBOXED
      #ENDBUTTON
    #ENDBOXED
  #ENDTAB
  #TAB('&Buttons')
    #BOXED('OK and Cancel')
      #PROMPT('&Handling:',DROP('Keep the buttons visible|Add OK/Cancel rows to the grid and hide the buttons')),%F2PButtons,DEFAULT('Keep the buttons visible')
      #PROMPT('&OK button (blank = ?OK if this window has one):',CONTROL),%F2POk
      #PROMPT('&Cancel button (blank = ?Cancel if this window has one):',CONTROL),%F2PCancel
      #ENABLE(%F2PButtons='Add OK/Cancel rows to the grid and hide the buttons')
        #PROMPT('&Actions category name:',@s64),%F2PActionCat,DEFAULT('Actions')
      #ENDENABLE
      #DISPLAY('A grid button row POSTs EVENT:Accepted to the real button, so')
      #DISPLAY('the form''s own OK / Cancel logic runs completely unchanged.')
      #DISPLAY('')
      #DISPLAY('IMPORTANT: with Live sync OFF, SyncBack() is generated on the')
      #DISPLAY('OK button ONLY.  If this window has no OK button and you leave')
      #DISPLAY('the prompt blank, nothing writes the grid back - either turn')
      #DISPLAY('Live sync on or call <object>.SyncBack() from your own embed.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Appearance')
    #INSERT(%PGAppearancePrompts)
  #ENDTAB
  #TAB('&Colours')
    #INSERT(%PGColourPrompts)
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! %F2POkCtl / %F2PCancelCtl are lazy #EQUATEs (ABASCII.TPW:237): a
#! #DECLARE + #SET is NOT visible to the #AT embed matcher, an #EQUATE is.
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%F2PStyleNum)
  #DECLARE(%F2PLNo)
  #DECLARE(%F2PLCatNo)
  #DECLARE(%F2PLCatVar)
  #DECLARE(%F2PLNameCtl)
  #SET(%F2PStyleNum,%PGStyleNumber())
  #EQUATE(%F2POkCtl,%PGGetOkControl())
  #EQUATE(%F2PCancelCtl,%PGGetCancelControl())
  #IF(%F2PClass = '')
    #SET(%F2PClass,'PropGridClass')
  #ENDIF
#!  the DISTINCT category overrides used by the lookup rows.  A blank
#!  override - or one that just repeats the default category - reuses
#!  PGFCat and gets no entry here.
  #IF(VAREXISTS(%F2PLCats) = 0)
    #DECLARE(%F2PLCats),MULTI,UNIQUE
  #ENDIF
  #FREE(%F2PLCats)
  #FOR(%F2PLookup),WHERE(%F2PLookupCat AND UPPER(%F2PLookupCat) <> UPPER(%F2PCategory))
    #ADD(%F2PLCats,%F2PLookupCat)
  #ENDFOR
#ENDAT
#!
#! Every lookup file has to be a file this PROCEDURE uses, or the
#! generated Relate: / Access: references have nothing to bind to.
#! %GatherSymbols + #ADD(%ProcFilesUsed,...) is exactly how ABC's own
#! RecordValidation extension pulls in a "must be in file" table
#! (ABUPDATE.TPW:112).  ABC then opens it at Init PRIORITY(7500) and
#! closes it in Kill, well before the grid is built at 8600.
#AT(%GatherSymbols),WHERE(%F2PDisable=0)
  #FOR(%F2PLookup),WHERE(%F2PLookupFile)
    #ADD(%ProcFilesUsed,%F2PLookupFile)
  #ENDFOR
#ENDAT
#!
#AT(%AfterGlobalIncludes),WHERE(%F2PDisable=0)
INCLUDE('PropGrid.inc'),ONCE
#ENDAT
#!
#AT(%CustomGlobalDeclarations),WHERE(%F2PDisable=0)
  #PROJECT('propgrid.lib')
#ENDAT
#!
#AT(%DataSection),WHERE(%F2PDisable=0)
%F2PObject            %F2PClass                                  ! ClaPropGrid object (form conversion)
PGFResize:%F2PObject  EQUATE(EVENT:User + 340 + %ActiveTemplateInstance) ! private "the window settled" event
PGFCat:%ActiveTemplateInstance   LONG                            ! main category id
PGFExcl:%ActiveTemplateInstance  STRING(1024)                    ! pipe list of FEQs to leave alone
  #IF(%F2PPlace <> 'Over a region control')
PGFX:%ActiveTemplateInstance     SIGNED                          ! computed placement, pixels
PGFY:%ActiveTemplateInstance     SIGNED
PGFW:%ActiveTemplateInstance     SIGNED
PGFH:%ActiveTemplateInstance     SIGNED
PGFPix:%ActiveTemplateInstance   BYTE                            ! saved PROP:Pixels
  #ENDIF
  #IF(%F2PButtons = 'Add OK/Cancel rows to the grid and hide the buttons')
PGFAct:%ActiveTemplateInstance   LONG                            ! 'Actions' category id
PGFOkRow:%ActiveTemplateInstance LONG
PGFCanRow:%ActiveTemplateInstance LONG
  #ENDIF
  #IF(ITEMS(%F2PLookup))
PGFLCnt:%ActiveTemplateInstance  SIGNED                          ! records taken from the lookup file
PGFLBuf:%ActiveTemplateInstance  USHORT                          ! ABC SaveBuffer handle (the scan is side effect free)
  #ENDIF
  #FOR(%F2PLCats)
    #SET(%F2PLCatNo,INSTANCE(%F2PLCats))
PGFLCat:%ActiveTemplateInstance:%F2PLCatNo LONG                  ! lookup category '%F2PLCats'
  #ENDFOR
  #FOR(%F2PLookup)
    #SET(%F2PLNo,INSTANCE(%F2PLookup))
PGFLRow:%ActiveTemplateInstance:%F2PLNo  LONG                    ! drop row for %F2PLookupCode
PGFLCode:%ActiveTemplateInstance:%F2PLNo STRING(2048)            ! pipe list: %F2PLookupFile.%F2PLookupCodeFld
PGFLName:%ActiveTemplateInstance:%F2PLNo STRING(4096)            ! pipe list: %F2PLookupFile.%F2PLookupDescFld
  #ENDFOR
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Init','(),BYTE'),PRIORITY(8600),WHERE(%F2PDisable=0),DESCRIPTION('ClaPropGrid: convert the form into a property grid')
  %F2PObject.LiveSync      = %F2PLiveSync
  %F2PObject.HideOriginals = %F2PHide
  %F2PObject.TimerInterval = %F2PTimer
  DO PGPlace:%F2PObject                                           ! creates the grid
  IF %F2PObject.Initialized
  #INSERT(%PGEmitAppearance,%F2PObject)
    PGFExcl:%ActiveTemplateInstance = ''
  #FOR(%F2PExclude)
    #IF(%F2PExcludeCtl)
    PGFExcl:%ActiveTemplateInstance = CLIP(PGFExcl:%ActiveTemplateInstance) & '|' & %F2PExcludeCtl
    #ENDIF
  #ENDFOR
  #IF(%F2POkCtl)
    PGFExcl:%ActiveTemplateInstance = CLIP(PGFExcl:%ActiveTemplateInstance) & '|' & %F2POkCtl
  #ENDIF
  #IF(%F2PCancelCtl)
    PGFExcl:%ActiveTemplateInstance = CLIP(PGFExcl:%ActiveTemplateInstance) & '|' & %F2PCancelCtl
  #ENDIF
  #! every control of every lookup trio - collected BEFORE BuildFromWindow,
  #! because the exclude list is an argument to it.
  #FOR(%F2PLookup)
    #IF(%F2PLookupCode)
    PGFExcl:%ActiveTemplateInstance = CLIP(PGFExcl:%ActiveTemplateInstance) & '|' & %F2PLookupCode
    #ENDIF
    #IF(%F2PLookupBtn)
    PGFExcl:%ActiveTemplateInstance = CLIP(PGFExcl:%ActiveTemplateInstance) & '|' & %F2PLookupBtn
    #ENDIF
    #IF(%F2PLookupDesc)
    PGFExcl:%ActiveTemplateInstance = CLIP(PGFExcl:%ActiveTemplateInstance) & '|' & %F2PLookupDesc
    #ENDIF
  #ENDFOR
    PGFCat:%ActiveTemplateInstance = %F2PObject.AddCategory('%F2PCategory')
    %F2PObject.BuildFromWindow(PGFCat:%ActiveTemplateInstance,CLIP(PGFExcl:%ActiveTemplateInstance))
  #FOR(%F2PLCats)
    #SET(%F2PLCatNo,INSTANCE(%F2PLCats))
    PGFLCat:%ActiveTemplateInstance:%F2PLCatNo = %F2PObject.AddCategory('%F2PLCats')
  #ENDFOR
  #FOR(%F2PLookup)
    #SET(%F2PLNo,INSTANCE(%F2PLookup))
    #! which category variable this row goes into, and which control (if
    #! any) shows the description.  Plain #SETs - NOT #GROUP/%() calls,
    #! which come back empty from inside this loop.
    #SET(%F2PLCatVar,'PGFCat:' & %ActiveTemplateInstance)
    #SET(%F2PLCatNo,0)
    #IF(%F2PLookupCat)
      #SET(%F2PLCatNo,INLIST(%F2PLookupCat,%F2PLCats))
    #ENDIF
    #IF(%F2PLCatNo)
      #SET(%F2PLCatVar,'PGFLCat:' & %ActiveTemplateInstance & ':' & %F2PLCatNo)
    #ENDIF
    #SET(%F2PLNameCtl,'0')
    #IF(%F2PLookupDesc)
      #SET(%F2PLNameCtl,%F2PLookupDesc)
    #ENDIF
!   lookup %F2PLNo: %F2PLookupCode + %F2PLookupBtn -> one drop row from %F2PLookupFile
    PGFLCode:%ActiveTemplateInstance:%F2PLNo = ''
    PGFLName:%ActiveTemplateInstance:%F2PLNo = ''
    PGFLCnt:%ActiveTemplateInstance = 0
    Relate:%F2PLookupFile.Open()                                  ! reference counted - safe
    PGFLBuf:%ActiveTemplateInstance = Access:%F2PLookupFile.SaveBuffer()
    #IF(%F2PLookupKey)
    SET(%F2PLookupKey)
    #ELSE
    SET(%F2PLookupFile)
    #ENDIF
    LOOP
      IF Access:%F2PLookupFile.Next() THEN BREAK.
      IF PGFLCnt:%ActiveTemplateInstance >= %F2PObject.MaxScanItems THEN BREAK.
      IF LEN(CLIP(PGFLCode:%ActiveTemplateInstance:%F2PLNo)) > 1900 THEN BREAK.
      IF LEN(CLIP(PGFLName:%ActiveTemplateInstance:%F2PLNo)) > 3900 THEN BREAK.
      PGFLCnt:%ActiveTemplateInstance += 1
      IF PGFLCnt:%ActiveTemplateInstance = 1
        PGFLCode:%ActiveTemplateInstance:%F2PLNo = %F2PObject.PipeSafe(%F2PLookupCodeFld)
        PGFLName:%ActiveTemplateInstance:%F2PLNo = %F2PObject.PipeSafe(%F2PLookupDescFld)
      ELSE
        PGFLCode:%ActiveTemplateInstance:%F2PLNo = CLIP(PGFLCode:%ActiveTemplateInstance:%F2PLNo) & '|' & %F2PObject.PipeSafe(%F2PLookupCodeFld)
        PGFLName:%ActiveTemplateInstance:%F2PLNo = CLIP(PGFLName:%ActiveTemplateInstance:%F2PLNo) & '|' & %F2PObject.PipeSafe(%F2PLookupDescFld)
      END
    END
    Access:%F2PLookupFile.RestoreBuffer(PGFLBuf:%ActiveTemplateInstance)
    Relate:%F2PLookupFile.Close()
    PGFLRow:%ActiveTemplateInstance:%F2PLNo = %F2PObject.AddFileDrop(%F2PLCatVar,'%F2PLookupLabel',%F2PLookupCode,%F2PLNameCtl,CLIP(PGFLCode:%ActiveTemplateInstance:%F2PLNo),CLIP(PGFLName:%ActiveTemplateInstance:%F2PLNo),'%F2PLookupTip')
    #IF(%F2PLookupBtn)
    HIDE(%F2PLookupBtn)                                           ! the drop row replaces the browse
    #ENDIF
  #ENDFOR
  #IF(%F2PButtons = 'Add OK/Cancel rows to the grid and hide the buttons')
    PGFAct:%ActiveTemplateInstance = %F2PObject.AddCategory('%F2PActionCat')
    #IF(%F2POkCtl)
    PGFOkRow:%ActiveTemplateInstance = %F2PObject.AddProperty(PGFAct:%ActiveTemplateInstance,'OK',PGT:Button,'OK')
    %F2PObject.SetTag(PGFOkRow:%ActiveTemplateInstance,%F2POkCtl) ! TakeButton POSTs EVENT:Accepted here
    HIDE(%F2POkCtl)
    #ENDIF
    #IF(%F2PCancelCtl)
    PGFCanRow:%ActiveTemplateInstance = %F2PObject.AddProperty(PGFAct:%ActiveTemplateInstance,'Cancel',PGT:Button,'Cancel')
    %F2PObject.SetTag(PGFCanRow:%ActiveTemplateInstance,%F2PCancelCtl)
    HIDE(%F2PCancelCtl)
    #ENDIF
  #ENDIF
    #EMBED(%F2PAfterBuild,'ClaPropGrid (form): after the grid is built (add your own rows here)'),%ActiveTemplateInstance
    %F2PObject.Redraw()
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%F2PDisable=0),DESCRIPTION('ClaPropGrid: event pump and resize')
  CASE EVENT()
  OF EVENT:Timer
    IF %F2PObject.TakeEvent()
      #EMBED(%F2POnGridEvent,'ClaPropGrid (form): the grid raised an event'),%ActiveTemplateInstance
      !  Live sync (when it is on) is handled inside PropGridClass.TakeChanged.
    END
  OF EVENT:Sized
    POST(PGFResize:%F2PObject)
  OF PGFResize:%F2PObject
    DO PGPlace:%F2PObject
  END
#ENDAT
#!
#! The OK button, EARLY (the generated form logic sits at PRIORITY 4999), so
#! the grid's edits are in the USE variables before the form saves them.
#AT(%ControlEventHandling,%F2POkCtl,'Accepted'),PRIORITY(2000),WHERE(%F2PDisable=0 AND %F2POkCtl<>''),DESCRIPTION('ClaPropGrid: push the grid into the controls')
  #EMBED(%F2PBeforeSyncBack,'ClaPropGrid (form): before SyncBack on OK'),%ActiveTemplateInstance
  #IF(%F2PLiveSync = 0)
%F2PObject.SyncBack()                                             ! grid -> the controls' USE variables
  #ELSE
!  Live sync is on, so every edit is already in the USE variables.
  #ENDIF
  #EMBED(%F2PAfterSyncBack,'ClaPropGrid (form): after SyncBack on OK'),%ActiveTemplateInstance
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(7500),WHERE(%F2PDisable=0),DESCRIPTION('ClaPropGrid: destroy the property grid')
%F2PObject.Kill()
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%F2PDisable=0)
!---------------------------------------------------------------------------
PGPlace:%F2PObject ROUTINE
!  Work out where the grid goes and create it (first call) or move it
!  (every later call).  DO this yourself after you resize anything.
  #IF(%F2PPlace = 'Over a region control')
  IF %F2PObject.Initialized
    %F2PObject.Reposition()                                       ! tracks %F2PRegion
  ELSE
    %F2PObject.Init(%Window,%F2PRegion,%F2PStyleNum)
  END
  #ELSE
  PGFPix:%ActiveTemplateInstance = 0{PROP:Pixels}
  0{PROP:Pixels} = TRUE                                           ! everything below is in PIXELS
  PGFW:%ActiveTemplateInstance = 0{PROP:Width}
  PGFH:%ActiveTemplateInstance = 0{PROP:Height}
  0{PROP:Pixels} = PGFPix:%ActiveTemplateInstance
    #IF(%F2PPlace = 'Dock left')
  PGFX:%ActiveTemplateInstance = %F2PMarginX
  PGFY:%ActiveTemplateInstance = %F2PMarginY
  PGFW:%ActiveTemplateInstance = %F2PDockWidth
  PGFH:%ActiveTemplateInstance = PGFH:%ActiveTemplateInstance - 2 * %F2PMarginY
    #ELSIF(%F2PPlace = 'Dock right')
  PGFX:%ActiveTemplateInstance = PGFW:%ActiveTemplateInstance - %F2PDockWidth - %F2PMarginX
  PGFY:%ActiveTemplateInstance = %F2PMarginY
  PGFW:%ActiveTemplateInstance = %F2PDockWidth
  PGFH:%ActiveTemplateInstance = PGFH:%ActiveTemplateInstance - 2 * %F2PMarginY
    #ELSE
  PGFX:%ActiveTemplateInstance = %F2PMarginX
  PGFY:%ActiveTemplateInstance = %F2PMarginY
  PGFW:%ActiveTemplateInstance = PGFW:%ActiveTemplateInstance - 2 * %F2PMarginX
  PGFH:%ActiveTemplateInstance = PGFH:%ActiveTemplateInstance - 2 * %F2PMarginY
    #ENDIF
  IF PGFW:%ActiveTemplateInstance < 1 THEN PGFW:%ActiveTemplateInstance = 1.
  IF PGFH:%ActiveTemplateInstance < 1 THEN PGFH:%ActiveTemplateInstance = 1.
  IF %F2PObject.Initialized
    %F2PObject.SetPos(PGFX:%ActiveTemplateInstance,PGFY:%ActiveTemplateInstance,PGFW:%ActiveTemplateInstance,PGFH:%ActiveTemplateInstance)
  ELSE
    %F2PObject.InitXY(%Window,PGFX:%ActiveTemplateInstance,PGFY:%ActiveTemplateInstance,PGFW:%ActiveTemplateInstance,PGFH:%ActiveTemplateInstance,%F2PStyleNum)
  END
  #ENDIF
#ENDAT
#!=============================================================================
#!  Shared #GROUPs.  A #GROUP has no end marker and swallows everything after
#!  it, so every #AT / #EMBED above must come FIRST - hence the include here,
#!  at the very end (the same order ABCHAIN.TPL uses for ABGROUP.TPW).
#!=============================================================================
#INCLUDE('ClaPropGrid.tpw')
