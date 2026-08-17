#TEMPLATE(ClaPropGrid,'Direct2D Property Grid [v1.2 2026-08-17 14:17]'),FAMILY('ABC')
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
#!  VERSION 1.2  -  2026-08-17 14:17
#!
#!  VERSION STAMP - THE CONVENTION.  Every edit to this chain bumps the
#!  version and refreshes the timestamp, because the #1 support symptom in
#!  this project is the IDE serving a STALE PARSED COPY of the template out
#!  of the registry (see INSTALL.md section 8).  With the stamp on screen you
#!  can tell at a glance whether the prompts you are looking at came from the
#!  file you just edited: if the version in the prompt sheet is not the one
#!  below, close the IDE, re-run ClarionCL -tr, reopen.
#!
#!  The template language cannot single-source it - the #TEMPLATE description
#!  is read at REGISTRATION time, long before any #GROUP can run - so the
#!  string is a literal in FIVE places and they must be kept in step:
#!      1. this comment
#!      2. the #TEMPLATE(...) description line above
#!      3. #DISPLAY on PropGridGlobal      -> General tab
#!      4. #DISPLAY on PropertyGridControl -> General tab
#!      5. #DISPLAY on FormToPropertyGrid  -> General tab
#!=============================================================================
#!#############################################################################
#!  APPLICATION EXTENSION - PropGridGlobal
#!#############################################################################
#EXTENSION(PropGridGlobal,'ClaPropGrid - global settings (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('ClaPropGrid')
      #DISPLAY('Version 1.2 - updated 2026-08-17 14:17')
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
    #DISPLAY('Version 1.2 - updated 2026-08-17 14:17')
    #DISPLAY('')
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
      #BOXED('This row on its own')
        #DISPLAY('Both of these are for the odd row that has to stand out.')
        #DISPLAY('Leave them alone and the row looks like every other one.')
        #PROMPT('&Wrap the value over up to N lines (0 = one line):',SPIN(@n2,0,64,1)),%PGFieldWrap,DEFAULT(0)
        #PROMPT('Name fac&e (blank = the grid font):',@s32),%PGFieldNameFace
        #PROMPT('Name si&ze (0 = the grid size):',SPIN(@n3,0,48,1)),%PGFieldNameSize,DEFAULT(0)
        #PROMPT('Name b&old',CHECK),%PGFieldNameBold,DEFAULT(0),AT(10)
        #PROMPT('Value f&ace (blank = the grid font):',@s32),%PGFieldValFace
        #PROMPT('Value siz&e (0 = the grid size):',SPIN(@n3,0,48,1)),%PGFieldValSize,DEFAULT(0)
        #PROMPT('Value bol&d',CHECK),%PGFieldValBold,DEFAULT(0),AT(10)
      #ENDBOXED
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
    #! per-row overrides: wrap the value, and/or a font of its own
    #IF(%PGFieldWrap)
    %PGObject.SetRowWrap(PGRow:%ActiveTemplateInstance:%PGRowNo,%PGFieldWrap)
    #ENDIF
    #IF(%PGFieldNameFace OR %PGFieldNameSize OR %PGFieldNameBold)
    %PGObject.SetRowFontFace(PGRow:%ActiveTemplateInstance:%PGRowNo,PGF:Name,'%PGFieldNameFace',%PGFieldNameSize,%PGFieldNameBold,0)
    #ENDIF
    #IF(%PGFieldValFace OR %PGFieldValSize OR %PGFieldValBold)
    %PGObject.SetRowFontFace(PGRow:%ActiveTemplateInstance:%PGRowNo,PGF:Value,'%PGFieldValFace',%PGFieldValSize,%PGFieldValBold,0)
    #ENDIF
  #ENDFOR
  #! every category exists by now, so the per-category fonts can find
  #! their headers by name
  #INSERT(%PGEmitCatFonts,%PGObject)
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
    #DISPLAY('Version 1.2 - updated 2026-08-17 14:17')
    #DISPLAY('')
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
  #TAB('&Tabs')
    #BOXED('Tab handling')
      #DISPLAY('Every TAB is either CONVERTED - the controls on it become grid')
      #DISPLAY('rows under a category named after the tab - or LEFT ALONE, in')
      #DISPLAY('which case the tab and everything inside it is not touched at')
      #DISPLAY('all and keeps working exactly as it does now.  "Leave alone" is')
      #DISPLAY('the right answer for a tab that holds a browse LIST with its')
      #DISPLAY('Insert / Change / Delete buttons.')
      #DISPLAY('')
      #DISPLAY('A tab that is NOT in the conversion list below converts whole.')
      #PROMPT('Tab names become extra &categories',CHECK),%F2PTabCats,DEFAULT(1),AT(10)
      #PROMPT('&Hide tabs the conversion empties (and the sheet, when every tab goes)',CHECK),%F2PTrimTabs,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Find them for me')
      #DISPLAY('The scan fills the conversion list with every TAB on this window')
      #DISPLAY('and, indented under each tab that converts, every control on it')
      #DISPLAY('that BuildFromWindow would turn into a row.  Tag ANY line -')
      #DISPLAY('a tab or a single control - "Leave alone" to keep it working')
      #DISPLAY('untouched; a spared control keeps its tab visible.')
      #DISPLAY('')
      #DISPLAY('A tab holding a LIST that has no DROP attribute (i.e. a browse,')
      #DISPLAY('not a drop-down) is prefilled "Leave alone" and its controls are')
      #DISPLAY('NOT listed - the tab entry already covers them.  Flip it to')
      #DISPLAY('"Convert into the grid" and scan again to list them.')
      #DISPLAY('')
      #DISPLAY('Scanning only APPENDS what is missing: nothing is added twice')
      #DISPLAY('and nothing you edited is overwritten, so re-scanning after you')
      #DISPLAY('change the window is always safe.')
      #BUTTON('&Scan this window for tabs and controls'),WHENACCEPTED(%PGScanTabs())
      #ENDBUTTON
      #PROMPT('Last scan:',@s64),%F2PTabScanInfo
    #ENDBOXED
    #BOXED('Conversion list')
      #DISPLAY('"TAB ?x" is a tab, an indented "- ?y" is one control inside the')
      #DISPLAY('tab above it.  Category name applies to TAB lines only.')
      #DISPLAY('Behaviour -> "Controls to leave alone" still works too: both')
      #DISPLAY('lists feed the same exclusion.')
      #BUTTON('Conversion &list...'),MULTI(%F2PTab,CHOOSE(%F2PTabKind = 'CONTROL','      - ','TAB ') & %F2PTabCtl & '  ->  ' & CHOOSE(%F2PTabAction = 'Leave alone','Leave alone','Convert')),INLINE
        #PROMPT('&Tab or control:',CONTROL),%F2PTabCtl,REQ
        #PROMPT('&What to do:',DROP('Convert into the grid|Leave alone')),%F2PTabAction,DEFAULT('Convert into the grid')
        #PROMPT('Cate&gory name (tabs only; blank = the tab''s text):',@s64),%F2PTabCat
        #! %F2PTabKind is written by the scan and never shown: a zero sized
        #! #BOXED,WHERE(%False) is the shipped way to carry a hidden child on
        #! a repeating list (ado.tpw:1715).  It defaults to TAB so that a row
        #! you add by hand still honours the Category name.
        #BOXED,WHERE(%False),AT(0,0,0,0)
          #PROMPT('Kind',@s8),%F2PTabKind,DEFAULT('TAB')
        #ENDBOXED
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
    #ENDBOXED
    #BOXED('Find them for me')
      #DISPLAY('Scan the window for the standard Clarion lookup: an ENTRY whose')
      #DISPLAY('"Lookup Key" / "Lookup Field" prompts are filled in (Actions tab')
      #DISPLAY('of the entry, pre- or post-edit), the "..." BUTTON that follows')
      #DISPLAY('it, and the STRING that shows the description.  The file and the')
      #DISPLAY('code field come from the lookup KEY, so they are exact; the')
      #DISPLAY('description field is a GUESS - check it.')
      #DISPLAY('')
      #DISPLAY('Everything found is APPENDED to the list below; a trio already')
      #DISPLAY('listed is never added twice, so re-scanning after you change the')
      #DISPLAY('window is safe.  Delete anything you do not want converted.')
      #BUTTON('&Scan this window for lookups'),WHENACCEPTED(%PGScanLookups())
      #ENDBUTTON
      #PROMPT('Last scan:',@s64),%F2PScanInfo
      #DISPLAY('Hand-coded lookups (your own browse call in an embed) cannot be')
      #DISPLAY('detected - the scan counts them as "unconfigured" and you add')
      #DISPLAY('those by hand below.')
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
  #TAB('&Added rows')
    #BOXED('Rows for things that are NOT on the window')
      #DISPLAY('BuildFromWindow can only convert controls that exist.  Add rows')
      #DISPLAY('here for a variable or dictionary column that has no control on')
      #DISPLAY('this window - or that the automatic conversion cannot handle -')
      #DISPLAY('exactly as the PropertyGridControl template does.')
      #DISPLAY('')
      #DISPLAY('These rows are bound to a VARIABLE, not to a control, so they')
      #DISPLAY('are loaded and saved by the generated PGFLoad: / PGFSave:')
      #DISPLAY('routines instead of by SyncBack().  Entries whose Category name')
      #DISPLAY('matches the default category, a lookup category or the Actions')
      #DISPLAY('category are merged into that one header.')
      #BUTTON('&Added properties...'),MULTI(%F2PAdded,%F2PAddCat & ' / ' & %F2PAddVar & '  [' & %F2PAddEditor & ']'),INLINE
        #PROMPT('&Variable / field:',FIELD),%F2PAddVar,REQ
        #PROMPT('&Display name (blank = derived from the variable):',@s64),%F2PAddName
        #PROMPT('&Category (blank = the default category):',@s64),%F2PAddCat
        #PROMPT('&Editor:',DROP('Text|Password|Drop list|Checkbox|Radio|Slider|Spin|Button|Color|Date|Time|Multiline|Read only')),%F2PAddEditor,DEFAULT('Text')
        #ENABLE(%F2PAddEditor='Drop list' OR %F2PAddEditor='Radio')
          #PROMPT('C&hoices, pipe separated (Red|Green|Blue):',@s255),%F2PAddChoices
        #ENDENABLE
        #ENABLE(%F2PAddEditor='Slider' OR %F2PAddEditor='Spin')
          #PROMPT('Range &low:',@n-13.4),%F2PAddLow,DEFAULT(0)
          #PROMPT('Range h&igh:',@n-13.4),%F2PAddHigh,DEFAULT(100)
          #PROMPT('&Step:',@n-13.4),%F2PAddStep,DEFAULT(1)
        #ENDENABLE
        #ENABLE(%F2PAddEditor='Date' OR %F2PAddEditor='Time')
          #PROMPT('&Picture (blank = @d17 for Date, @t4 for Time):',@s20),%F2PAddPicture
        #ENDENABLE
        #PROMPT('&Read only',CHECK),%F2PAddReadOnly,DEFAULT(0),AT(10)
        #PROMPT('D&escription (shown in the description pane):',@s255),%F2PAddDesc
        #BOXED('This row on its own')
          #DISPLAY('For the odd row that has to stand out.  Converted controls')
          #DISPLAY('are styled per CATEGORY instead - see the Appearance tab.')
          #PROMPT('&Wrap the value over up to N lines (0 = one line):',SPIN(@n2,0,64,1)),%F2PAddWrap,DEFAULT(0)
          #PROMPT('Name fac&e (blank = the grid font):',@s32),%F2PAddNameFace
          #PROMPT('Name si&ze (0 = the grid size):',SPIN(@n3,0,48,1)),%F2PAddNameSize,DEFAULT(0)
          #PROMPT('Name b&old',CHECK),%F2PAddNameBold,DEFAULT(0),AT(10)
          #PROMPT('Value f&ace (blank = the grid font):',@s32),%F2PAddValFace
          #PROMPT('Value siz&e (0 = the grid size):',SPIN(@n3,0,48,1)),%F2PAddValSize,DEFAULT(0)
          #PROMPT('Value bol&d',CHECK),%F2PAddValBold,DEFAULT(0),AT(10)
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
  #DECLARE(%F2PLTabCat)
  #DECLARE(%F2PLNameCtl)
  #DECLARE(%F2PAddNo)
  #DECLARE(%F2PAddPic)
  #DECLARE(%F2PAddLbl)
  #DECLARE(%F2PAddPos)
  #DECLARE(%F2PActEarly)
  #SET(%F2PStyleNum,%PGStyleNumber())
  #EQUATE(%F2POkCtl,%PGGetOkControl())
  #EQUATE(%F2PCancelCtl,%PGGetCancelControl())
  #IF(%F2PClass = '')
    #SET(%F2PClass,'PropGridClass')
  #ENDIF
#!-----------------------------------------------------------------------------
#!  Categories.  Four things add rows to this one grid - the converted
#!  controls, the lookup drop-downs, the added properties and the OK/Cancel
#!  actions - and rows merge into ONE header whenever the names match:
#!      name = the default category   -> PGFCat:n   (always exists)
#!      name = the actions category   -> PGFAct:n   (only when actions are on)
#!      anything else                 -> PGFLCat:n:k, k = INSTANCE in %F2PLCats
#!  %F2PActEarly says a lookup or added row needs PGFAct BEFORE the actions
#!  block creates it, so Init has to create that category early.
#!-----------------------------------------------------------------------------
  #IF(VAREXISTS(%F2PLCats) = 0)
    #DECLARE(%F2PLCats),MULTI,UNIQUE
  #ENDIF
  #FREE(%F2PLCats)
  #SET(%F2PActEarly,0)
  #FOR(%F2PLookup),WHERE(%F2PLookupCat AND UPPER(%F2PLookupCat) <> UPPER(%F2PCategory))
    #IF(%F2PButtons = 'Add OK/Cancel rows to the grid and hide the buttons' AND UPPER(%F2PLookupCat) = UPPER(%F2PActionCat))
      #SET(%F2PActEarly,1)
    #ELSE
      #ADD(%F2PLCats,%F2PLookupCat)
    #ENDIF
  #ENDFOR
  #FOR(%F2PAdded),WHERE(%F2PAddCat AND UPPER(%F2PAddCat) <> UPPER(%F2PCategory))
    #IF(%F2PButtons = 'Add OK/Cancel rows to the grid and hide the buttons' AND UPPER(%F2PAddCat) = UPPER(%F2PActionCat))
      #SET(%F2PActEarly,1)
    #ELSE
      #ADD(%F2PLCats,%F2PAddCat)
    #ENDIF
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
    #IF(%F2PTabCats)
PGFTCat:%ActiveTemplateInstance  LONG                            ! TabCategoryOf() result for a lookup row
    #ENDIF
  #ENDIF
  #FOR(%F2PLCats)
    #SET(%F2PLCatNo,INSTANCE(%F2PLCats))
PGFLCat:%ActiveTemplateInstance:%F2PLCatNo LONG                  ! extra category '%F2PLCats'
  #ENDFOR
  #FOR(%F2PLookup)
    #SET(%F2PLNo,INSTANCE(%F2PLookup))
PGFLRow:%ActiveTemplateInstance:%F2PLNo  LONG                    ! drop row for %F2PLookupCode
PGFLCode:%ActiveTemplateInstance:%F2PLNo STRING(2048)            ! pipe list: %F2PLookupFile.%F2PLookupCodeFld
PGFLName:%ActiveTemplateInstance:%F2PLNo STRING(4096)            ! pipe list: %F2PLookupFile.%F2PLookupDescFld
  #ENDFOR
  #FOR(%F2PAdded)
    #SET(%F2PAddNo,INSTANCE(%F2PAdded))
PGFRow:%ActiveTemplateInstance:%F2PAddNo LONG                    ! added row for %F2PAddVar
  #ENDFOR
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Init','(),BYTE'),PRIORITY(8600),WHERE(%F2PDisable=0),DESCRIPTION('ClaPropGrid: convert the form into a property grid')
  %F2PObject.LiveSync      = %F2PLiveSync
  %F2PObject.HideOriginals = %F2PHide
  %F2PObject.TimerInterval = %F2PTimer
  #! a plain literal, never the raw prompt: an app saved by an OLDER build of
  #! this template has no value stored for %F2PTabCats, and an empty right
  #! hand side would not compile.
  #IF(%F2PTabCats)
  %F2PObject.TabCategories = 1                                    ! each TAB's text becomes a category
  #ELSE
  %F2PObject.TabCategories = 0                                    ! everything lands in the default category
  #ENDIF
  DO PGPlace:%F2PObject                                           ! creates the grid
  IF %F2PObject.Initialized
  #INSERT(%PGEmitAppearance,%F2PObject)
    PGFExcl:%ActiveTemplateInstance = ''
  #FOR(%F2PExclude)
    #IF(%F2PExcludeCtl)
    PGFExcl:%ActiveTemplateInstance = CLIP(PGFExcl:%ActiveTemplateInstance) & '|' & %F2PExcludeCtl
    #ENDIF
  #ENDFOR
  #! the conversion list - tabs AND single controls, the same treatment for
  #! both because BuildFromWindow excludes SUBTREES: a TAB's own FEQ in the
  #! list leaves every control inside it untouched, a control's FEQ just that
  #! control.  Merges into the same string as the Behaviour exclude list.
  #FOR(%F2PTab),WHERE(%F2PTabAction = 'Leave alone')
    #IF(%F2PTabCtl)
    PGFExcl:%ActiveTemplateInstance = CLIP(PGFExcl:%ActiveTemplateInstance) & '|' & %F2PTabCtl
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
  #! per tab category names.  SetTabCategory only records the override, so it
  #! must run BEFORE BuildFromWindow; it works with tab categories switched
  #! off too, which is why it is not guarded by %F2PTabCats.  TAB lines of the
  #! conversion list only - the Category prompt is ignored on control lines.
  #FOR(%F2PTab),WHERE(%F2PTabCat AND %F2PTabAction <> 'Leave alone' AND %F2PTabKind <> 'CONTROL')
    #IF(%F2PTabCtl)
    %F2PObject.SetTabCategory(%F2PTabCtl,'%F2PTabCat')            ! instead of the tab's own text
    #ENDIF
  #ENDFOR
    PGFCat:%ActiveTemplateInstance = %F2PObject.AddCategory('%F2PCategory')
  #IF(%F2PActEarly)
    PGFAct:%ActiveTemplateInstance = %F2PObject.AddCategory('%F2PActionCat') ! a lookup / added row asked for this one by name
  #ENDIF
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
    #SET(%F2PLTabCat,0)
    #IF(%F2PLookupCat)
      #SET(%F2PLCatNo,INLIST(%F2PLookupCat,%F2PLCats))
    #ENDIF
    #IF(%F2PLCatNo)
      #SET(%F2PLCatVar,'PGFLCat:' & %ActiveTemplateInstance & ':' & %F2PLCatNo)
    #ELSIF(%F2PActEarly AND %F2PLookupCat AND UPPER(%F2PLookupCat) = UPPER(%F2PActionCat))
      #SET(%F2PLCatVar,'PGFAct:' & %ActiveTemplateInstance)
    #ELSIF(%F2PTabCats AND %F2PLookupCat = '')
      #! no category named, and tab categories are on: the row belongs on the
      #! tab its code control sits on.  Resolved at RUN time (TabCategoryOf
      #! makes the category on demand) with the default category as fallback.
      #SET(%F2PLCatVar,'PGFTCat:' & %ActiveTemplateInstance)
      #SET(%F2PLTabCat,1)
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
    #IF(%F2PLTabCat)
    PGFTCat:%ActiveTemplateInstance = %F2PObject.TabCategoryOf(%F2PLookupCode) ! the tab this lookup sits on
    IF ~PGFTCat:%ActiveTemplateInstance THEN PGFTCat:%ActiveTemplateInstance = PGFCat:%ActiveTemplateInstance.
    #ENDIF
    PGFLRow:%ActiveTemplateInstance:%F2PLNo = %F2PObject.AddFileDrop(%F2PLCatVar,'%F2PLookupLabel',%F2PLookupCode,%F2PLNameCtl,CLIP(PGFLCode:%ActiveTemplateInstance:%F2PLNo),CLIP(PGFLName:%ActiveTemplateInstance:%F2PLNo),'%F2PLookupTip')
    #IF(%F2PLookupBtn)
    HIDE(%F2PLookupBtn)                                           ! the drop row replaces the browse
    #ENDIF
  #ENDFOR
  #! ---- added rows: bound to a VARIABLE, so they carry no tag and are
  #! ---- loaded / saved by the PGFLoad: / PGFSave: routines below.
  #FOR(%F2PAdded)
    #SET(%F2PAddNo,INSTANCE(%F2PAdded))
    #SET(%F2PLCatVar,'PGFCat:' & %ActiveTemplateInstance)
    #SET(%F2PLCatNo,0)
    #IF(%F2PAddCat)
      #SET(%F2PLCatNo,INLIST(%F2PAddCat,%F2PLCats))
    #ENDIF
    #IF(%F2PLCatNo)
      #SET(%F2PLCatVar,'PGFLCat:' & %ActiveTemplateInstance & ':' & %F2PLCatNo)
    #ELSIF(%F2PActEarly AND %F2PAddCat AND UPPER(%F2PAddCat) = UPPER(%F2PActionCat))
      #SET(%F2PLCatVar,'PGFAct:' & %ActiveTemplateInstance)
    #ENDIF
    #! the row label: the developer's name, else the variable with any
    #! leading '?' and any prefix stripped - the rule %PGDefaultLabel uses
    #! for the control template, done with #SETs because a #GROUP called
    #! from inside a #FOR over a MULTI list silently kills the whole block.
    #SET(%F2PAddLbl,%F2PAddName)
    #IF(%F2PAddLbl = '')
      #SET(%F2PAddLbl,CLIP(%F2PAddVar))
      #IF(SUB(%F2PAddLbl,1,1) = '?')
        #SET(%F2PAddLbl,SUB(%F2PAddLbl,2,LEN(%F2PAddLbl)))
      #ENDIF
      #SET(%F2PAddPos,INSTRING(':',%F2PAddLbl,1,1))
      #IF(%F2PAddPos)
        #SET(%F2PAddLbl,SUB(%F2PAddLbl,%F2PAddPos + 1,LEN(%F2PAddLbl)))
      #ENDIF
      #IF(%F2PAddLbl = '')
        #SET(%F2PAddLbl,'Field')
      #ENDIF
    #ENDIF
    PGFRow:%ActiveTemplateInstance:%F2PAddNo = %F2PObject.AddProperty(%F2PLCatVar,'%F2PAddLbl',%(%PGEditorEquate(%F2PAddEditor)),'')
    #IF(%F2PAddChoices)
    %F2PObject.SetChoices(PGFRow:%ActiveTemplateInstance:%F2PAddNo,'%F2PAddChoices')
    #ENDIF
    #IF(%F2PAddEditor = 'Slider' OR %F2PAddEditor = 'Spin')
    %F2PObject.SetRange(PGFRow:%ActiveTemplateInstance:%F2PAddNo,%F2PAddLow,%F2PAddHigh,%F2PAddStep)
    #ENDIF
    #IF(%F2PAddDesc)
    %F2PObject.SetDescription(PGFRow:%ActiveTemplateInstance:%F2PAddNo,'%F2PAddDesc')
    #ENDIF
    #IF(%F2PAddReadOnly)
    %F2PObject.SetReadOnly(PGFRow:%ActiveTemplateInstance:%F2PAddNo,1)
    #ENDIF
    #! per-row overrides, exactly as the control template does them
    #IF(%F2PAddWrap)
    %F2PObject.SetRowWrap(PGFRow:%ActiveTemplateInstance:%F2PAddNo,%F2PAddWrap)
    #ENDIF
    #IF(%F2PAddNameFace OR %F2PAddNameSize OR %F2PAddNameBold)
    %F2PObject.SetRowFontFace(PGFRow:%ActiveTemplateInstance:%F2PAddNo,PGF:Name,'%F2PAddNameFace',%F2PAddNameSize,%F2PAddNameBold,0)
    #ENDIF
    #IF(%F2PAddValFace OR %F2PAddValSize OR %F2PAddValBold)
    %F2PObject.SetRowFontFace(PGFRow:%ActiveTemplateInstance:%F2PAddNo,PGF:Value,'%F2PAddValFace',%F2PAddValSize,%F2PAddValBold,0)
    #ENDIF
  #ENDFOR
  #IF(ITEMS(%F2PAdded))
    DO PGFLoad:%F2PObject                                         ! variables -> the added rows
  #ENDIF
  #IF(%F2PButtons = 'Add OK/Cancel rows to the grid and hide the buttons')
    #IF(%F2PActEarly = 0)
    PGFAct:%ActiveTemplateInstance = %F2PObject.AddCategory('%F2PActionCat')
    #ENDIF
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
  #! LAST of the building: by now the converted controls, the lookups,
  #! the added rows, the actions AND every tab category exist, so a
  #! per-category font can find its header by name whichever of them
  #! created it.
  #INSERT(%PGEmitCatFonts,%F2PObject)
    #EMBED(%F2PAfterBuild,'ClaPropGrid (form): after the grid is built (add your own rows here)'),%ActiveTemplateInstance
  #! LAST, after BuildFromWindow, after every AddFileDrop (each of which hides
  #! its own trio) and after the embed above - so a control you UNHIDE there
  #! still keeps its tab on screen.
  #IF(%F2PTrimTabs)
    %F2PObject.TrimTabs()                                         ! hide the tabs the conversion emptied
  #ENDIF
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
  #IF(ITEMS(%F2PAdded) AND %F2PLiveSync)
      DO PGFSave:%F2PObject                                       ! the added rows have no control to sync into
  #ENDIF
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
  #IF(ITEMS(%F2PAdded))
DO PGFSave:%F2PObject                                             ! added rows -> their variables (FIRST)
  #ENDIF
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
  #IF(ITEMS(%F2PAdded))
!---------------------------------------------------------------------------
PGFLoad:%F2PObject ROUTINE
!  variables -> the ADDED rows (the converted controls look after themselves).
!  Called once after the grid is built; DO it again yourself whenever those
!  variables change behind the grid's back.
  #EMBED(%F2PBeforeLoad,'ClaPropGrid (form): before loading the added rows from the variables'),%ActiveTemplateInstance
    #FOR(%F2PAdded)
      #SET(%F2PAddNo,INSTANCE(%F2PAdded))
      #SET(%F2PAddPic,%F2PAddPicture)
      #IF(%F2PAddPic = '')
        #IF(%F2PAddEditor = 'Time')
          #SET(%F2PAddPic,'@t4')
        #ELSE
          #SET(%F2PAddPic,'@d17')
        #ENDIF
      #ENDIF
      #CASE(%F2PAddEditor)
      #OF('Date')
      #OROF('Time')
  %F2PObject.SetValue(PGFRow:%ActiveTemplateInstance:%F2PAddNo,FORMAT(%F2PAddVar,%F2PAddPic))
      #OF('Checkbox')
  %F2PObject.SetValue(PGFRow:%ActiveTemplateInstance:%F2PAddNo,CHOOSE(%F2PAddVar = 1,'1','0'))
      #OF('Button')
        #SET(%F2PAddLbl,%F2PAddName)
        #IF(%F2PAddLbl = '')
          #SET(%F2PAddLbl,CLIP(%F2PAddVar))
          #IF(SUB(%F2PAddLbl,1,1) = '?')
            #SET(%F2PAddLbl,SUB(%F2PAddLbl,2,LEN(%F2PAddLbl)))
          #ENDIF
          #SET(%F2PAddPos,INSTRING(':',%F2PAddLbl,1,1))
          #IF(%F2PAddPos)
            #SET(%F2PAddLbl,SUB(%F2PAddLbl,%F2PAddPos + 1,LEN(%F2PAddLbl)))
          #ENDIF
          #IF(%F2PAddLbl = '')
            #SET(%F2PAddLbl,'Field')
          #ENDIF
        #ENDIF
  %F2PObject.SetValue(PGFRow:%ActiveTemplateInstance:%F2PAddNo,'%F2PAddLbl')
      #ELSE
  %F2PObject.SetValue(PGFRow:%ActiveTemplateInstance:%F2PAddNo,CLIP(LEFT(%F2PAddVar)))
      #ENDCASE
    #ENDFOR
  #EMBED(%F2PAfterLoad,'ClaPropGrid (form): after loading the added rows from the variables'),%ActiveTemplateInstance
  %F2PObject.Redraw()
!---------------------------------------------------------------------------
PGFSave:%F2PObject ROUTINE
!  the ADDED rows -> variables.  Called from the OK button (before SyncBack)
!  and, with Live sync on, every time the grid raises an event.
  #EMBED(%F2PBeforeSave,'ClaPropGrid (form): before saving the added rows into the variables'),%ActiveTemplateInstance
    #FOR(%F2PAdded)
      #SET(%F2PAddNo,INSTANCE(%F2PAdded))
      #SET(%F2PAddPic,%F2PAddPicture)
      #IF(%F2PAddPic = '')
        #IF(%F2PAddEditor = 'Time')
          #SET(%F2PAddPic,'@t4')
        #ELSE
          #SET(%F2PAddPic,'@d17')
        #ENDIF
      #ENDIF
      #IF(%F2PAddReadOnly = 0 AND %F2PAddEditor <> 'Read only' AND %F2PAddEditor <> 'Button')
        #CASE(%F2PAddEditor)
        #OF('Date')
        #OROF('Time')
  %F2PAddVar = DEFORMAT(CLIP(%F2PObject.GetValue(PGFRow:%ActiveTemplateInstance:%F2PAddNo)),%F2PAddPic)
        #OF('Checkbox')
  %F2PAddVar = CHOOSE(CLIP(%F2PObject.GetValue(PGFRow:%ActiveTemplateInstance:%F2PAddNo)) = '1',1,0)
        #ELSE
  %F2PAddVar = CLIP(%F2PObject.GetValue(PGFRow:%ActiveTemplateInstance:%F2PAddNo))
        #ENDCASE
      #ENDIF
    #ENDFOR
  #EMBED(%F2PAfterSave,'ClaPropGrid (form): after saving the added rows into the variables'),%ActiveTemplateInstance
  #ENDIF
#ENDAT
#!=============================================================================
#!  %PGScanLookups - fill the Lookups list from what is already on the window.
#!
#!  Runs at PROMPT time, from the "Scan this window for lookups" button
#!  (#BUTTON(...),WHENACCEPTED(...) with an empty body is the shipped idiom
#!  for an action button - ABCONTRL.TPW:36).  It lives in the .tpl, not the
#!  .tpw, because a #GROUP in the included file that reads THIS template's
#!  symbols has been measured to come back empty.
#!
#!  What it reads (all of it put there by ABC itself):
#!    %PostLookupKey / %PostLookupField  - the ENTRY's own "when accepted"
#!    %PreLookupKey  / %PreLookupField   - ... or "when selected" lookup,
#!        declared per control in ABWINDOW.TPW:2058-2067 (they are children
#!        of the %Control list, so #FOR(%Control) fixes them).
#!    #FIND(%Key,<that key>) fixes %File as well - ABWINDOW.TPW:2096 relies
#!        on exactly that - which gives the lookup FILE, and the key's
#!        component field IS the code field.
#!
#!  What it guesses: the description control (the first STRING/PROMPT after
#!  the trio's ENTRY that has a USE VARIABLE) and, from it, the description
#!  field (that variable when it belongs to the lookup file, otherwise the
#!  file's first string field that is not the code field).
#!
#!  #ADD(list,ITEMS(list)+1) + #SET(child,...) is the population idiom from
#!  ABCONTRL.TPW:222-227; PRESERVE keeps the caller's %Control / %File /
#!  %Key fixes intact.
#!=============================================================================
#GROUP(%PGScanLookups),PRESERVE,AUTO
#DECLARE(%pgHit),MULTI
#DECLARE(%pgHitCode,%pgHit)
#DECLARE(%pgHitCodeUse,%pgHit)
#DECLARE(%pgHitBtn,%pgHit)
#DECLARE(%pgHitDesc,%pgHit)
#DECLARE(%pgHitFile,%pgHit)
#DECLARE(%pgHitCodeFld,%pgHit)
#DECLARE(%pgHitDescFld,%pgHit)
#DECLARE(%pgHitDrop,%pgHit)
#DECLARE(%pgOpen)
#DECLARE(%pgIsBtn)
#DECLARE(%pgKey)
#DECLARE(%pgFld)
#DECLARE(%pgTxt)
#DECLARE(%pgUse)
#DECLARE(%pgCodeFile)
#DECLARE(%pgSeen)
#DECLARE(%pgAdded)
#DECLARE(%pgSkipped)
#DECLARE(%pgUnres)
#FREE(%pgHit)
#SET(%pgOpen,0)
#SET(%pgAdded,0)
#SET(%pgSkipped,0)
#SET(%pgUnres,0)
#!---- pass 1: walk the window in declaration order ---------------------------
#!  EVERY entry opens a candidate, because a hand-wired lookup (no Lookup Key
#!  set, just an ALRT / DROPID and a browse call in an embed) is identified
#!  later, in pass 2, from the description STRING's own field.
#FOR(%Control)
  #CASE(%ControlType)
  #OF('ENTRY')
  #OROF('SPIN')
    #SET(%pgKey,'')
    #SET(%pgFld,'')
    #IF(VAREXISTS(%PostLookupKey))
      #IF(%PostLookupKey)
        #SET(%pgKey,%PostLookupKey)
        #SET(%pgFld,%PostLookupField)
      #ENDIF
    #ENDIF
    #IF(%pgKey = '' AND VAREXISTS(%PreLookupKey))
      #IF(%PreLookupKey)
        #SET(%pgKey,%PreLookupKey)
        #SET(%pgFld,%PreLookupField)
      #ENDIF
    #ENDIF
    #ADD(%pgHit,ITEMS(%pgHit) + 1)                  #! the new entry is now current
    #SET(%pgHitCode,%Control)
    #SET(%pgHitCodeUse,%ControlUse)
    #SET(%pgHitBtn,'')
    #SET(%pgHitDesc,'')
    #SET(%pgHitDescFld,'')
    #SET(%pgHitCodeFld,%pgFld)
    #SET(%pgHitFile,'')
    #!  DROPID('Majors') on the entry names the file in a drag-and-drop
    #!  lookup - a third chance at the table, checked against the dictionary.
    #SET(%pgTxt,EXTRACT(%ControlStatement,'DROPID',1))
    #IF(SUB(%pgTxt,1,1) = '<39>')
      #SET(%pgTxt,SUB(%pgTxt,2,LEN(%pgTxt) - 2))
    #ENDIF
    #SET(%pgHitDrop,%pgTxt)
    #IF(%pgKey)
      #FIND(%Key,%pgKey)                            #! fixes %File too
      #SET(%pgHitFile,%File)
    #ENDIF
    #SET(%pgOpen,1)
  #OF('BUTTON')
    #IF(%pgOpen)
      #!  Only a button that PROVES it is the lookup is taken, because the
      #!  generated code HIDEs it - pairing "the next button on the window"
      #!  would hide something like ?Btn_Save.  Proof is either ABC's own
      #!  FieldLookupButton (it stores the ENTRY it serves in
      #!  %ControlToLookup - ABCONTRL.TPW:241) or a name that says so.
      #!  Nothing proven = no button on the entry, and the real one simply
      #!  stays visible and keeps working.
      #SET(%pgIsBtn,0)
      #IF(VAREXISTS(%ControlToLookup))
        #IF(%ControlToLookup)
          #IF(UPPER(%ControlToLookup) = UPPER(%pgHitCode))
            #SET(%pgIsBtn,1)
          #ENDIF
        #ENDIF
      #ENDIF
      #IF(%pgIsBtn = 0 AND INSTRING('LOOKUP',UPPER(%Control),1,1))
        #SET(%pgIsBtn,1)
      #ENDIF
      #!  the real signature of a lookup button is its CAPTION.  EXTRACT gives
      #!  it back quoted, so strip the quotes the way ABBROWSE.TPW:2759 does.
      #!  '...' exactly - never 'Save...' - because the generated code HIDEs it.
      #IF(%pgIsBtn = 0)
        #SET(%pgTxt,EXTRACT(%ControlStatement,'BUTTON',1))
        #IF(SUB(%pgTxt,1,1) = '<39>')
          #SET(%pgTxt,SUB(%pgTxt,2,LEN(%pgTxt) - 2))
        #ENDIF
        #IF(%pgTxt = '...')
          #SET(%pgIsBtn,1)
        #ENDIF
      #ENDIF
      #IF(%pgIsBtn AND %pgHitBtn = '')
        #SET(%pgHitBtn,%Control)
      #ENDIF
    #ENDIF
  #OF('STRING')
  #OROF('PROMPT')
    #IF(%pgOpen)
      #IF(%pgHitDesc = '' AND %ControlUse)
        #IF(SUB(%ControlUse,1,1) <> '?')            #! a caption, not a USE variable
          #SET(%pgHitDesc,%Control)
        #ENDIF
      #ENDIF
    #ENDIF
  #OF('LIST')
  #OROF('COMBO')
  #OROF('CHECK')
  #OROF('OPTION')
  #OROF('TEXT')
  #OROF('SHEET')
  #OROF('TAB')
    #SET(%pgOpen,0)                                 #! the next data control ends the trio
  #ENDCASE
#ENDFOR
#!---- pass 2: resolve the description field, then append ---------------------
#SET(%pgSeen,'')
#FOR(%F2PLookup)
  #SET(%pgSeen,%pgSeen & '|' & UPPER(%F2PLookupCode) & '|')
#ENDFOR
#FOR(%pgHit)
  #SET(%pgUse,'')
  #IF(%pgHitDesc)
    #FIX(%Control,%pgHitDesc)
    #SET(%pgUse,%ControlUse)
  #ENDIF
  #!  ---- the table, when no Lookup Key told us ----------------------------
  #!  STRING(@s15),USE(MAJ:Description) IS the answer: the field names its
  #!  own file, and it is the description field as well.  #FIND(%Field,..)
  #!  fixes %File (ABWINDOW.TPW:2103 uses it the same way); it is verified by
  #!  comparing the result, because a miss leaves the previous fix in place.
  #IF(%pgHitFile = '' AND %pgUse)
    #IF(SUB(%pgUse,1,1) <> '?')
      #FIND(%Field,%pgUse)
      #IF(UPPER(%Field) = UPPER(%pgUse))
        #SET(%pgHitFile,%File)
        #SET(%pgHitDescFld,%Field)
      #ENDIF
    #ENDIF
  #ENDIF
  #IF(%pgHitFile = '' AND %pgHitDrop)             #! DROPID('Majors')
    #FOR(%File),WHERE(UPPER(%File) = UPPER(%pgHitDrop))
      #SET(%pgHitFile,%File)
      #BREAK
    #ENDFOR
  #ENDIF
  #!  ---- the code field, when no Lookup Key told us ------------------------
  #!  Take the side of a MANY:1 relation that is NOT the entry's own field;
  #!  otherwise the lookup table's primary key, first component.
  #IF(%pgHitFile AND %pgHitCodeFld = '')
    #SET(%pgCodeFile,'')
    #IF(%pgHitCodeUse)
      #IF(SUB(%pgHitCodeUse,1,1) <> '?')
        #FIND(%Field,%pgHitCodeUse)
        #IF(UPPER(%Field) = UPPER(%pgHitCodeUse))
          #SET(%pgCodeFile,%File)
        #ENDIF
      #ENDIF
    #ENDIF
    #IF(%pgCodeFile)
      #FIX(%File,%pgCodeFile)
      #FOR(%Relation),WHERE(UPPER(%Relation) = UPPER(%pgHitFile))
        #FOR(%FileKeyField),WHERE(%FileKeyFieldLink)
          #IF(UPPER(%FileKeyField) = UPPER(%pgHitCodeUse))
            #SET(%pgHitCodeFld,%FileKeyFieldLink)
          #ELSIF(UPPER(%FileKeyFieldLink) = UPPER(%pgHitCodeUse))
            #SET(%pgHitCodeFld,%FileKeyField)
          #ENDIF
        #ENDFOR
      #ENDFOR
    #ENDIF
    #!  a relation field must really belong to the lookup table
    #IF(%pgHitCodeFld)
      #SET(%pgTxt,'')
      #FIX(%File,%pgHitFile)
      #FOR(%Field),WHERE(UPPER(%Field) = UPPER(%pgHitCodeFld))
        #SET(%pgTxt,%Field)
        #BREAK
      #ENDFOR
      #IF(%pgTxt = '')
        #SET(%pgHitCodeFld,'')
      #ENDIF
    #ENDIF
    #IF(%pgHitCodeFld = '')
      #FIX(%File,%pgHitFile)
      #IF(%FilePrimaryKey)
        #FIX(%Key,%FilePrimaryKey)
        #FOR(%KeyField)
          #SET(%pgHitCodeFld,%KeyField)
          #BREAK
        #ENDFOR
      #ENDIF
    #ENDIF
  #ENDIF
  #IF(%pgHitFile)
    #FIX(%File,%pgHitFile)
    #IF(%pgUse)
      #FOR(%Field),WHERE(UPPER(%Field) = UPPER(%pgUse))
        #SET(%pgHitDescFld,%Field)                  #! the STRING shows a field of the file
        #BREAK
      #ENDFOR
    #ENDIF
    #IF(%pgHitDescFld = '')
      #FOR(%Field),WHERE(%FieldType = 'STRING' OR %FieldType = 'CSTRING' OR %FieldType = 'PSTRING')
        #IF(UPPER(%Field) <> UPPER(%pgHitCodeFld))
          #SET(%pgHitDescFld,%Field)                #! first text field that is not the code
          #BREAK
        #ENDIF
      #ENDFOR
    #ENDIF
    #IF(%pgHitDescFld = '')
      #SET(%pgHitDescFld,%pgHitCodeFld)             #! a one column table - show the code
    #ENDIF
  #ENDIF
  #!  Only a candidate that resolved to a table AND a code field is a lookup.
  #!  A plain data entry with no browse next to it lands here and is dropped
  #!  silently; one that clearly IS a trio but could not be identified (the
  #!  description STRING shows a local variable, say) is counted so the
  #!  developer knows to add it by hand.
  #IF(%pgHitFile = '' OR %pgHitCodeFld = '')
    #IF(%pgHitBtn AND %pgHitDesc)
      #SET(%pgUnres,%pgUnres + 1)
    #ENDIF
  #ELSIF(INSTRING('|' & UPPER(%pgHitCode) & '|',%pgSeen,1,1))
    #SET(%pgSkipped,%pgSkipped + 1)                 #! already in the list - leave it alone
  #ELSE
    #ADD(%F2PLookup,ITEMS(%F2PLookup) + 1)
    #SET(%F2PLookupCode,%pgHitCode)
    #SET(%F2PLookupBtn,%pgHitBtn)
    #SET(%F2PLookupDesc,%pgHitDesc)
    #SET(%F2PLookupFile,%pgHitFile)
    #SET(%F2PLookupKey,'')
    #SET(%F2PLookupCodeFld,%pgHitCodeFld)
    #SET(%F2PLookupDescFld,%pgHitDescFld)
    #SET(%F2PLookupLabel,'')
    #SET(%F2PLookupCat,'')
    #SET(%F2PLookupTip,'')
    #SET(%pgAdded,%pgAdded + 1)
  #ENDIF
#ENDFOR
#SET(%F2PScanInfo,'added ' & %pgAdded & ', already listed ' & %pgSkipped & ', could not identify ' & %pgUnres)
#!=============================================================================
#!  %PGScanTabs - fill the CONVERSION LIST from what is on the window: one
#!  entry per TAB and, indented under every tab that converts, one entry per
#!  control on it that BuildFromWindow would turn into a row.
#!
#!  Runs at PROMPT time, from the "Scan this window for tabs and controls"
#!  button, and it lives HERE and not in ClaPropGrid.tpw for the same reason
#!  %PGScanLookups does: a #GROUP in the included file that reads THIS
#!  template's symbols (%F2PTab and its children) has been measured to come
#!  back empty.
#!
#!  Prefilled action.  A tab holding a browse is left alone, everything else
#!  converts.  "Is this LIST a browse" is the shipped test from
#!  CONTROL.TPW:209 - a LIST with no DROP attribute.  DROP's parameter is a
#!  row count, so a QUOTED one really came from DROPID('Majors') on a drag
#!  and drop browse and still means "not a drop-down".
#!  %ControlUnsplitStatement, not %ControlStatement: a LIST with a long FORMAT
#!  is split over continuation lines and the attribute can land on any of them.
#!
#!  Convertible control types - exactly the ones PropGridClass.AddControl
#!  turns into a row (PropGrid.clw:418-473):
#!      ENTRY  SPIN  SLIDER  CHECK  OPTION  TEXT  RTF  BUTTON
#!      LIST / COMBO that HAVE a DROP attribute (and the DROPLIST /
#!      DROPCOMBO types, which some window formatters report instead)
#!  PROMPT / STRING become the LABEL of the next control, never a row of
#!  their own (PropGrid.clw:532), so they are never listed; nor are the
#!  controls of a tab that is left alone - its one entry covers them.
#!
#!  Containment is resolved by walking %ControlParent up from the control
#!  until a TAB turns up, so a control inside a GROUP inside a TAB is still
#!  found.  The walk uses #FIX(%Control,..) and therefore cannot run inside
#!  #FOR(%Control) - hence the passes, exactly as %PGScanLookups is built.
#!  Two private lists, never one: %pgCand is every candidate IN WINDOW ORDER
#!  (that order is what puts each control under its own tab), %pgTab is the
#!  per tab state.  A #FOR over a list cannot be nested inside a #FOR over
#!  the SAME list, and pass 4 has to read tab state while walking candidates.
#!=============================================================================
#GROUP(%PGScanTabs),PRESERVE,AUTO
#DECLARE(%pgCand),MULTI
#DECLARE(%pgCandCtl,%pgCand)
#DECLARE(%pgCandKind,%pgCand)                       #! TAB | CONTROL | BROWSE
#DECLARE(%pgCandOwner,%pgCand)                      #! the TAB it sits on
#DECLARE(%pgTab),MULTI
#DECLARE(%pgTabCtl,%pgTab)
#DECLARE(%pgTabBrowse,%pgTab)
#DECLARE(%pgTabAct,%pgTab)
#DECLARE(%pgTxt)
#DECLARE(%pgKind)
#DECLARE(%pgWalk)
#DECLARE(%pgFound)
#DECLARE(%pgStep)
#DECLARE(%pgAct)
#DECLARE(%pgSeen)
#DECLARE(%pgAddedTabs)
#DECLARE(%pgAddedCtls)
#DECLARE(%pgSkipped)
#DECLARE(%pgLeave)
#FREE(%pgCand)
#FREE(%pgTab)
#SET(%pgAddedTabs,0)
#SET(%pgAddedCtls,0)
#SET(%pgSkipped,0)
#SET(%pgLeave,0)
#!---- pass 1: every candidate, in window order -------------------------------
#FOR(%Control)
  #SET(%pgKind,'')
  #CASE(%ControlType)
  #OF('TAB')
    #SET(%pgKind,'TAB')
  #OF('LIST')
  #OROF('COMBO')
    #SET(%pgTxt,'')
    #IF(VAREXISTS(%ControlUnsplitStatement))
      #SET(%pgTxt,EXTRACT(%ControlUnsplitStatement,'DROP',1))
    #ELSE
      #SET(%pgTxt,EXTRACT(%ControlStatement,'DROP',1))
    #ENDIF
    #IF(%pgTxt = '' OR SUB(%pgTxt,1,1) = '<39>')    #! nothing but DROP(rows) counts
      #IF(%ControlType = 'LIST')
        #SET(%pgKind,'BROWSE')                      #! marks its tab, never listed
      #ENDIF
    #ELSE
      #SET(%pgKind,'CONTROL')                       #! a real drop-down = a row
    #ENDIF
  #OF('DROPLIST')
  #OROF('DROPCOMBO')
    #SET(%pgKind,'CONTROL')                         #! already a drop-down by type
  #OF('ENTRY')
  #OROF('SPIN')
  #OROF('SLIDER')
  #OROF('CHECK')
  #OROF('OPTION')
  #OROF('TEXT')
  #OROF('RTF')
  #OROF('BUTTON')
    #SET(%pgKind,'CONTROL')
  #ENDCASE
  #IF(%pgKind AND %Control)
    #ADD(%pgCand,ITEMS(%pgCand) + 1)                #! the new entry is now current
    #SET(%pgCandCtl,%Control)
    #SET(%pgCandKind,%pgKind)
    #SET(%pgCandOwner,'')
    #IF(%pgKind = 'TAB')
      #ADD(%pgTab,ITEMS(%pgTab) + 1)
      #SET(%pgTabCtl,%Control)
      #SET(%pgTabBrowse,0)
      #SET(%pgTabAct,'')
    #ENDIF
  #ENDIF
#ENDFOR
#!---- pass 2: which TAB holds each control -----------------------------------
#FOR(%pgCand),WHERE(%pgCandKind <> 'TAB')
  #SET(%pgWalk,%pgCandCtl)
  #SET(%pgFound,'')
  #FIX(%Control,%pgWalk)
  #IF(UPPER(%Control) = UPPER(%pgWalk))             #! a miss leaves the old fix in place
    #LOOP,FOR(%pgStep,1,16)                         #! bounded - a cycle can never hang AppGen
      #SET(%pgWalk,%ControlParent)
      #IF(%pgWalk = '')
        #BREAK
      #ENDIF
      #FIX(%Control,%pgWalk)
      #IF(UPPER(%Control) <> UPPER(%pgWalk))
        #BREAK
      #ENDIF
      #IF(%ControlType = 'TAB')
        #SET(%pgFound,%Control)
        #BREAK
      #ENDIF
    #ENDLOOP
  #ENDIF
  #SET(%pgCandOwner,%pgFound)
  #IF(%pgFound AND %pgCandKind = 'BROWSE')
    #FOR(%pgTab),WHERE(UPPER(%pgTabCtl) = UPPER(%pgFound))
      #SET(%pgTabBrowse,1)
      #BREAK
    #ENDFOR
  #ENDIF
#ENDFOR
#!---- pass 3: what each tab is going to do -----------------------------------
#!  A tab already in the list keeps ITS action - the developer's word beats
#!  the browse heuristic, and that is what makes a re-scan safe.
#FOR(%pgTab)
  #SET(%pgAct,'')
  #FOR(%F2PTab),WHERE(UPPER(%F2PTabCtl) = UPPER(%pgTabCtl))
    #SET(%pgAct,%F2PTabAction)
    #BREAK
  #ENDFOR
  #IF(%pgAct = '')
    #IF(%pgTabBrowse)
      #SET(%pgAct,'Leave alone')
    #ELSE
      #SET(%pgAct,'Convert into the grid')
    #ENDIF
  #ENDIF
  #SET(%pgTabAct,%pgAct)
#ENDFOR
#!---- pass 4: append what is missing, in window order ------------------------
#SET(%pgSeen,'')
#FOR(%F2PTab)
  #SET(%pgSeen,%pgSeen & '|' & UPPER(%F2PTabCtl) & '|')
#ENDFOR
#FOR(%pgCand),WHERE(%pgCandKind <> 'BROWSE')
  #SET(%pgAct,'')
  #IF(%pgCandKind = 'TAB')
    #FOR(%pgTab),WHERE(UPPER(%pgTabCtl) = UPPER(%pgCandCtl))
      #SET(%pgAct,%pgTabAct)
      #BREAK
    #ENDFOR
  #ELSIF(%pgCandOwner)
    #!  a control is listed only when the tab it lives on converts: the entry
    #!  of a tab that is left alone already covers everything inside it.
    #FOR(%pgTab),WHERE(UPPER(%pgTabCtl) = UPPER(%pgCandOwner))
      #IF(%pgTabAct <> 'Leave alone')
        #SET(%pgAct,'Convert into the grid')
      #ENDIF
      #BREAK
    #ENDFOR
  #ENDIF
  #!  a blank action here means "do not list it": the control is on no tab at
  #!  all (Behaviour -> "Controls to leave alone" is the place for those), or
  #!  the tab it lives on is left alone.
  #IF(%pgAct)
    #IF(INSTRING('|' & UPPER(%pgCandCtl) & '|',%pgSeen,1,1))
      #SET(%pgSkipped,%pgSkipped + 1)               #! already listed - never touched again
    #ELSE
      #ADD(%F2PTab,ITEMS(%F2PTab) + 1)
      #SET(%F2PTabCtl,%pgCandCtl)
      #SET(%F2PTabKind,%pgCandKind)
      #SET(%F2PTabAction,%pgAct)
      #SET(%F2PTabCat,'')
      #SET(%pgSeen,%pgSeen & '|' & UPPER(%pgCandCtl) & '|')
      #IF(%pgCandKind = 'TAB')
        #SET(%pgAddedTabs,%pgAddedTabs + 1)
      #ELSE
        #SET(%pgAddedCtls,%pgAddedCtls + 1)
      #ENDIF
      #IF(%pgAct = 'Leave alone')
        #SET(%pgLeave,%pgLeave + 1)
      #ENDIF
    #ENDIF
  #ENDIF
#ENDFOR
#SET(%F2PTabScanInfo,'added ' & %pgAddedTabs & ' tabs + ' & %pgAddedCtls & ' controls (' & %pgLeave & ' left alone), already listed ' & %pgSkipped)
#!=============================================================================
#!  Shared #GROUPs.  A #GROUP has no end marker and swallows everything after
#!  it, so every #AT / #EMBED above must come FIRST - hence the include here,
#!  at the very end (the same order ABCHAIN.TPL uses for ABGROUP.TPW).
#!=============================================================================
#INCLUDE('ClaPropGrid.tpw')
