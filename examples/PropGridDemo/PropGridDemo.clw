  PROGRAM
!=====================================================================
!  PropGridDemo - everything PropGridClass can do, hand coded.
!
!  No AppGen, no ABC, no templates: this is plain Clarion driving the
!  class directly, so every call you see here is one you can copy into
!  your own procedure.  The templates emit exactly these calls.
!
!  Three windows:
!    1  Everything    - all 13 editor types, categories, colours, the
!                       four global fonts, per-category and per-row
!                       fonts, wrapped self-sizing rows, the event
!                       pump, and a derived class hook.
!    2  Form          - a normal data-entry form turned into a grid at
!                       run time by BuildFromWindow, with a lookup
!                       trio folded into one drop row and OK/Cancel
!                       driven from grid button rows.
!    3  Tabs          - per-tab categories, a browse tab left alone by
!                       excluding its subtree, and TrimTabs.
!
!  Build:  build.bat   (copies the class + lib + dll in, then MSBuild)
!=====================================================================
  PRAGMA('link(propgrid.lib)')
  INCLUDE('PropGrid.inc'),ONCE

  MAP
DemoEverything  PROCEDURE()
DemoForm        PROCEDURE()
DemoTabs        PROCEDURE()
  END

!---------------------------------------------------------------------
!  A derived class.  TakeSelect is an empty hook in the base class, so
!  overriding it is the cheapest way to react to the user moving from
!  row to row.  TakeChanged is overridden too, to show that calling
!  PARENT keeps LiveSync working.
!---------------------------------------------------------------------
DemoGrid  CLASS(PropGridClass)
TakeSelect   PROCEDURE(SIGNED row),DERIVED
TakeChanged  PROCEDURE(SIGNED row),DERIVED
          END

LastEvent   STRING(160)               ! what the derived class saw

!---- launcher -------------------------------------------------------
MainWin WINDOW('ClaPropGrid demo'),AT(,,220,120),GRAY,SYSTEM,FONT('Segoe UI',9)
          BUTTON('1 - &Everything the class does'),AT(10,10,200,20),USE(?BtnEvery)
          BUTTON('2 - Convert a &form at run time'),AT(10,36,200,20),USE(?BtnForm)
          BUTTON('3 - &Tabs, categories, TrimTabs'),AT(10,62,200,20),USE(?BtnTabs)
          BUTTON('E&xit'),AT(10,92,200,18),USE(?BtnExit),STD(STD:Close)
        END

  CODE
  !  PropGridDemo.exe 1|2|3 opens one window straight away and quits
  !  when it closes - handy for screenshots and for a quick look at
  !  one feature without the menu.
  CASE CLIP(COMMAND('1'))
  OF '1' ; DemoEverything() ; RETURN
  OF '2' ; DemoForm()       ; RETURN
  OF '3' ; DemoTabs()       ; RETURN
  END

  OPEN(MainWin)
  ACCEPT
    CASE ACCEPTED()
    OF ?BtnEvery ; DemoEverything()
    OF ?BtnForm  ; DemoForm()
    OF ?BtnTabs  ; DemoTabs()
    END
  END
  CLOSE(MainWin)
  RETURN

!=====================================================================
!  1 - Everything
!=====================================================================
DemoEverything PROCEDURE()
Grid        DemoGrid                        ! the DERIVED class
cGen        SIGNED                          ! category ids
cNum        SIGNED
cNote       SIGNED
cAct        SIGNED
rName       SIGNED                          ! row ids
rPass       SIGNED
rEnabled    SIGNED
rKind       SIGNED
rAlign      SIGNED
rOpacity    SIGNED
rCount      SIGNED
rRatio      SIGNED
rColour     SIGNED
rDate       SIGNED
rTime       SIGNED
rVersion    SIGNED
rShort      SIGNED
rLong       SIGNED
rCapped     SIGNED
rApply      SIGNED
fMono       SIGNED                          ! font ids
fShout      SIGNED
Status      STRING(160)
Face        STRING(64)
Pt          SIGNED
Bold        SIGNED
Ital        SIGNED
NameF       SIGNED
ValueF      SIGNED

Win WINDOW('1 - Everything the class does'),AT(,,440,340),GRAY,SYSTEM,RESIZE,TIMER(10),FONT('Segoe UI',9)
      REGION,AT(4,4,432,300),USE(?PGRegion)
      STRING(@s160),AT(6,310,428,10),USE(Status)
      BUTTON('Apply'),AT(6,324,60,14),USE(?ApplyBtn),HIDE
      BUTTON('&Close'),AT(376,324,60,14),USE(?CloseBtn),STD(STD:Close)
    END

  CODE
  OPEN(Win)
  IF ~Grid.Init(Win, ?PGRegion, PGS:Border + PGS:Description)
    MESSAGE('PROPGRID.DLL did not create the grid.', 'ClaPropGrid demo')
    CLOSE(Win)
    RETURN
  END

  !---- the four global font slots + the colours ---------------------
  Grid.SetFont(PGF:Name,     'Segoe UI', 9, 0, 0)
  Grid.SetFont(PGF:Value,    'Segoe UI', 9, 0, 0)
  Grid.SetFont(PGF:Category, 'Segoe UI', 9, 1, 0)
  Grid.SetFont(PGF:Desc,     'Segoe UI', 9, 0, 0)
  Grid.SetColor(PGC:CatBack,  00E4E9F0h)     ! 0BBGGRRh - blue-green-red
  Grid.SetColor(PGC:CatText,  005F3A1Fh)     ! reads back as RGB 1F3A5F
  Grid.SetColor(PGC:SelBack,  00F5E4D6h)
  Grid.SetSplitter(150)

  !---- every editor type -------------------------------------------
  cGen     = Grid.AddCategory('General')
  rName    = Grid.AddProperty(cGen, 'Name',      PGT:Text,     'Widget Alpha')
  Grid.SetDescription(rName, 'PGT:Text - a plain in-place edit.')
  rPass    = Grid.AddProperty(cGen, 'Password',  PGT:Password, 'secret')
  Grid.SetDescription(rPass, 'PGT:Password - masked while it shows.')
  rEnabled = Grid.AddProperty(cGen, 'Enabled',   PGT:Check,    '1')
  Grid.SetDescription(rEnabled, 'PGT:Check - the value is "1" or "0".')
  rKind    = Grid.AddProperty(cGen, 'Kind',      PGT:Drop,     'Standard')
  Grid.SetChoices(rKind, 'Standard|Advanced|Custom|Legacy')
  Grid.SetDescription(rKind, 'PGT:Drop - choices are a pipe list.')
  rAlign   = Grid.AddProperty(cGen, 'Alignment', PGT:Radio,    'Left')
  Grid.SetChoices(rAlign, 'Left|Center|Right')

  cNum     = Grid.AddCategory('Numbers')
  rOpacity = Grid.AddProperty(cNum, 'Opacity',   PGT:Slider,   '75')
  Grid.SetRange(rOpacity, 0, 100, 5)
  Grid.SetDescription(rOpacity, 'PGT:Slider - drag it, or type in the box.')
  rCount   = Grid.AddProperty(cNum, 'Count',     PGT:Spin,     '3')
  Grid.SetRange(rCount, 0, 50, 1)
  rRatio   = Grid.AddProperty(cNum, 'Ratio',     PGT:Spin,     '0.5')
  Grid.SetRange(rRatio, 0, 1, 0.05)
  rColour  = Grid.AddProperty(cNum, 'Fore colour', PGT:Color,  '3D6DA8')
  Grid.SetDescription(rColour, 'PGT:Color - opens the Windows picker.')
  rDate    = Grid.AddProperty(cNum, 'Created',   PGT:Date,     '17/08/2026')
  rTime    = Grid.AddProperty(cNum, 'Start time',PGT:Time,     '09:30')
  rVersion = Grid.AddProperty(cNum, 'Version',   PGT:ReadOnly, '1.2.0')
  Grid.SetDescription(rVersion, 'PGT:ReadOnly - shown, never edited.')

  !---- wrapped, self-sizing rows ------------------------------------
  cNote    = Grid.AddCategory('Notes')
  rShort   = Grid.AddProperty(cNote, 'One liner', PGT:MultiText, |
             'Long text on a normal row is trimmed with an ellipsis.')
  rLong    = Grid.AddProperty(cNote, 'Wrapped',   PGT:MultiText, |
             'This row wraps.  The value is laid out over as many ' & |
             'lines as it needs, the row grows to fit and every row ' & |
             'below it moves down.  Drag the splitter and watch the ' & |
             'whole grid re-flow around it.')
  Grid.SetRowWrap(rLong, -1)                 ! -1 = as many lines as it takes
  Grid.SetDescription(rLong, 'SetRowWrap(row,-1) - unlimited lines.')
  rCapped  = Grid.AddProperty(cNote, 'Capped at 2', PGT:ReadOnly, |
             'A read-only note capped at two lines: the rest is ' & |
             'clipped, but the two lines it does show are laid out ' & |
             'properly instead of trimmed to one.')
  Grid.SetRowWrap(rCapped, 2)                ! at most two lines

  !---- per-category and per-row fonts -------------------------------
  !  AddFont registers a face/size/bold/italic once and returns an id.
  !  Identical fonts are de-duplicated, so calling it in a loop is safe.
  fMono  = Grid.AddFont('Consolas', 10, 0, 0)
  Grid.SetCategoryFont(cNum, PGF:Inherit, PGF:Inherit, fMono)   ! values only
  !  the same thing in one call, for the category header this time
  Grid.SetCategoryFontFace(cNote, PGF:Category, 'Segoe UI', 12, 1, 0)
  !  and one single row shouting louder than the rest
  fShout = Grid.SetRowFontFace(rName, PGF:Value, 'Georgia', 14, 1, 1)

  !---- an action row that drives a real button ----------------------
  !  This is exactly what FormToPropertyGrid does with OK / Cancel: the
  !  row is tagged with a control, and TakeButton POSTs EVENT:Accepted
  !  to it, so the window's own handler runs unchanged.
  cAct   = Grid.AddCategory('Actions')
  rApply = Grid.AddProperty(cAct, 'Apply', PGT:Button, 'Apply now')
  Grid.SetTag(rApply, ?ApplyBtn)

  !---- read the fonts back out again --------------------------------
  Grid.GetRowFont(rName, NameF, ValueF)
  Grid.GetFontInfo(ValueF, Face, Pt, Bold, Ital)
  Status = 'Name value font: ' & CLIP(Face) & ' ' & Pt & 'pt bold=' & Bold & |
           ' italic=' & Ital & '  |  ' & Grid.FontCount() & ' fonts, ' & |
           Grid.RowCount() & ' rows, wrapped row is ' & |
           Grid.RowHeight(rLong) & 'px tall'
  DISPLAY(?Status)
  Grid.Redraw()

  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      IF Grid.TakeEvent()                    ! drains the DLL's queue
        IF LastEvent
          Status = LastEvent
          DISPLAY(?Status)
        END
      END
    OF EVENT:Sized
      Grid.Reposition()                      ! DockMode is PGD:Region
    END
    CASE ACCEPTED()
    OF ?ApplyBtn                             ! POSTed here by TakeButton
      Status = 'Apply pressed from the grid.  Name = ' & |
               CLIP(Grid.GetValue(rName)) & ', Kind = ' & |
               CLIP(Grid.GetValue(rKind)) & ', Enabled = ' & |
               CLIP(Grid.GetValue(rEnabled))
      DISPLAY(?Status)
    END
  END

  Grid.Kill()
  CLOSE(Win)
  RETURN

!=====================================================================
!  2 - Convert a form at run time
!=====================================================================
DemoForm PROCEDURE()
Grid        PropGridClass
cMain       SIGNED
cAct        SIGNED
rDept       SIGNED
rOk         SIGNED
rCancel     SIGNED
Excl        STRING(256)
Codes       STRING(256)
Names       STRING(256)
!---- the form's own USE variables - SyncBack writes into these ------
CusName     STRING(40)
CusRef      STRING(10)
CusActive   BYTE
CusRating   STRING(10)
CusCredit   LONG
DeptCode    STRING(4)
DeptName    STRING(30)
Summary     STRING(200)

Win WINDOW('2 - the same form, converted'),AT(,,480,300),GRAY,SYSTEM,RESIZE,TIMER(10),FONT('Segoe UI',9)
      PROMPT('Customer name:'),AT(8,10,80,10),USE(?PName)
      ENTRY(@s40),AT(92,8,120,12),USE(CusName)
      PROMPT('Reference:'),AT(8,26,80,10),USE(?PRef)
      ENTRY(@s10),AT(92,24,60,12),USE(CusRef)
      PROMPT('Credit limit:'),AT(8,42,80,10),USE(?PCredit)
      SPIN(@n7),AT(92,40,60,12),USE(CusCredit),RANGE(0,100000),STEP(500)
      CHECK('Active'),AT(92,58,60,10),USE(CusActive)
      PROMPT('Rating:'),AT(8,74,80,10),USE(?PRating)
      LIST,AT(92,72,80,12),USE(CusRating),DROP(6),FROM('A|B|C|D')
      !---- the classic lookup trio: code ENTRY + '...' + description --
      PROMPT('Department:'),AT(8,90,80,10),USE(?PDept)
      ENTRY(@s4),AT(92,88,30,12),USE(DeptCode)
      BUTTON('...'),AT(126,88,12,12),USE(?LookupDept)
      STRING(@s30),AT(142,90,100,10),USE(DeptName)
      BUTTON('OK'),AT(8,120,50,14),USE(?OkBtn),DEFAULT
      BUTTON('Cancel'),AT(62,120,50,14),USE(?CancelBtn)
      STRING(@s200),AT(8,142,240,20),USE(Summary)
      REGION,AT(256,8,216,284),USE(?PGRegion)
    END

  CODE
  CusName   = 'Acme Manufacturing'
  CusRef    = 'C-10045'
  CusActive = 1
  CusRating = 'B'
  CusCredit = 25000
  DeptCode  = 'D02'

  OPEN(Win)
  IF ~Grid.Init(Win, ?PGRegion, PGS:Border + PGS:Description)
    CLOSE(Win) ; RETURN
  END

  !  LiveSync off: nothing is written back until SyncBack() runs, which
  !  is what the OK button does below.  Turn it on and every keystroke
  !  lands in the USE variable instead.
  Grid.LiveSync      = 0
  Grid.HideOriginals = 1                     ! hide what we convert
  Grid.SetSplitter(100)

  !---- what NOT to convert ------------------------------------------
  !  Excluding a container excludes its whole subtree; excluding one
  !  control spares just that control.  The lookup trio is excluded
  !  because AddFileDrop folds all three into one row below.
  Excl = ''
  Excl = CLIP(Excl) & '|' & ?OkBtn
  Excl = CLIP(Excl) & '|' & ?CancelBtn
  Excl = CLIP(Excl) & '|' & ?Summary
  Excl = CLIP(Excl) & '|' & ?DeptCode
  Excl = CLIP(Excl) & '|' & ?LookupDept
  Excl = CLIP(Excl) & '|' & ?DeptName

  cMain = Grid.AddCategory('Customer')
  Grid.BuildFromWindow(cMain, CLIP(Excl))    ! the whole form, in one call

  !---- fold the lookup trio into ONE drop row -----------------------
  !  Codes and Names are parallel pipe lists - item n of Names is what
  !  the grid shows, item n of Codes is what gets written back.  Build
  !  them with PipeSafe() so a '|' in the data cannot split the list.
  !  A real app loops its lookup FILE here; the lists are all the class
  !  needs, so a code table can come from anywhere.
  Codes = 'D01|D02|D03|D04'
  Names = 'Sales|Support|Warehouse|Head office'
  rDept = Grid.AddFileDrop(cMain, 'Department', ?DeptCode, ?DeptName, |
                           Codes, Names, 'Shows the name, stores the code.')
  HIDE(?LookupDept)                          ! the drop row replaced it

  !---- OK / Cancel as grid rows -------------------------------------
  cAct    = Grid.AddCategory('Actions')
  rOk     = Grid.AddProperty(cAct, 'OK',     PGT:Button, 'OK')
  Grid.SetTag(rOk, ?OkBtn)
  rCancel = Grid.AddProperty(cAct, 'Cancel', PGT:Button, 'Cancel')
  Grid.SetTag(rCancel, ?CancelBtn)
  HIDE(?OkBtn)
  HIDE(?CancelBtn)

  Summary = 'The form is still there - every control was hidden, not removed.'
  DISPLAY
  Grid.Redraw()

  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      Grid.TakeEvent()
    OF EVENT:Sized
      Grid.Reposition()
    END
    CASE ACCEPTED()
    OF ?OkBtn                                ! POSTed by the grid row
      Grid.SyncBack()                        ! grid -> the USE variables
      Summary = 'SyncBack wrote: ' & CLIP(CusName) & ' / ' & CLIP(CusRef) & |
                ' / credit ' & CusCredit & ' / active ' & CusActive & |
                ' / rating ' & CLIP(CusRating) & ' / dept ' & CLIP(DeptCode)
      DISPLAY(?Summary)
    OF ?CancelBtn
      POST(EVENT:CloseWindow)
    END
  END

  Grid.Kill()
  CLOSE(Win)
  RETURN

!=====================================================================
!  3 - Tabs, categories and TrimTabs
!=====================================================================
DemoTabs PROCEDURE()
Grid        PropGridClass
cMain       SIGNED
Excl        STRING(64)
Note        STRING(200)
HistQ       QUEUE
Line          STRING(40)
            END
CusName     STRING(40)
CusPhone    STRING(20)
CusStreet   STRING(40)
CusCity     STRING(30)
CusPost     STRING(10)
Ix          SIGNED

Win WINDOW('3 - tabs, categories, TrimTabs'),AT(,,520,320),GRAY,SYSTEM,RESIZE,TIMER(10),FONT('Segoe UI',9)
      SHEET,AT(6,6,270,280),USE(?Sheet)
        TAB('&Customer'),USE(?TabCust)
          PROMPT('Name:'),AT(14,30,50,10),USE(?PName)
          ENTRY(@s40),AT(70,28,140,12),USE(CusName)
          PROMPT('Phone:'),AT(14,46,50,10),USE(?PPhone)
          ENTRY(@s20),AT(70,44,90,12),USE(CusPhone)
        END
        TAB('&Address'),USE(?TabAddr)
          PROMPT('Street:'),AT(14,30,50,10),USE(?PStreet)
          ENTRY(@s40),AT(70,28,140,12),USE(CusStreet)
          PROMPT('City:'),AT(14,46,50,10),USE(?PCity)
          ENTRY(@s30),AT(70,44,110,12),USE(CusCity)
          PROMPT('Post code:'),AT(14,62,50,10),USE(?PPost)
          ENTRY(@s10),AT(70,60,50,12),USE(CusPost)
        END
        TAB('&History'),USE(?TabHist)
          LIST,AT(14,28,250,200),USE(?HistList),FROM(HistQ),FORMAT('200L(2)|M~Recent activity~')
          BUTTON('&Insert'),AT(14,234,50,14),USE(?InsBtn)
          BUTTON('&Delete'),AT(68,234,50,14),USE(?DelBtn)
        END
      END
      STRING(@s200),AT(6,292,508,20),USE(Note)
      REGION,AT(282,6,232,280),USE(?PGRegion)
    END

  CODE
  CusName   = 'Acme Manufacturing'
  CusPhone  = '+1 555 0134'
  CusStreet = '18 Foundry Road'
  CusCity   = 'Sheffield'
  CusPost   = 'S1 2AB'
  LOOP Ix = 1 TO 6
    HistQ.Line = 'Order ' & (1000 + Ix) & ' shipped'
    ADD(HistQ)
  END

  OPEN(Win)
  IF ~Grid.Init(Win, ?PGRegion, PGS:Border + PGS:Description)
    CLOSE(Win) ; RETURN
  END

  !  Each TAB's own text becomes a category, so the rows keep the
  !  grouping the form already had.
  Grid.TabCategories = 1
  !  ... unless you override one by name.  SetTabCategory only RECORDS
  !  the override, so it has to run BEFORE BuildFromWindow.
  Grid.SetTabCategory(?TabAddr, 'Postal address')

  !  Excluding the TAB excludes everything inside it - list, buttons
  !  and all - so the browse tab stays a live, working tab beside the
  !  grid.  That one FEQ is the whole trick.
  Excl = '|' & ?TabHist

  !  Fallback category 0: every control here lives on a tab, so no
  !  fallback header is wanted.  Pass a real category id instead and
  !  anything sitting outside a tab lands under it.
  cMain = 0
  Grid.BuildFromWindow(cMain, CLIP(Excl))

  !  LAST: hide the tabs the conversion emptied, and the SHEET too once
  !  its last visible tab goes.  Here the History tab survives, so the
  !  sheet stays - with one tab on it.
  Grid.TrimTabs()

  Note = 'Customer and Address became categories; History was excluded by ' & |
         'its TAB feq, so the browse still works.  TrimTabs hid the two ' & |
         'emptied tabs.'
  DISPLAY
  Grid.Redraw()

  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      IF Grid.TakeEvent()
        Grid.SyncBack()                      ! keep the hidden form in step
      END
    OF EVENT:Sized
      Grid.Reposition()
    END
    CASE ACCEPTED()
    OF ?InsBtn
      HistQ.Line = 'Added from the browse tab'
      ADD(HistQ)
    OF ?DelBtn
      IF RECORDS(HistQ)
        GET(HistQ, CHOICE(?HistList))
        IF ~ERRORCODE() THEN DELETE(HistQ).
      END
    END
  END

  Grid.Kill()
  CLOSE(Win)
  RETURN

!=====================================================================
!  the derived class
!=====================================================================
DemoGrid.TakeSelect PROCEDURE(SIGNED row)
  CODE
  LastEvent = 'TakeSelect: row ' & row & ' (' & CLIP(SELF.GetValue(row)) & ')'

DemoGrid.TakeChanged PROCEDURE(SIGNED row)
  CODE
  PARENT.TakeChanged(row)                    ! keeps LiveSync working
  LastEvent = 'TakeChanged: row ' & row & ' is now "' & |
              CLIP(SELF.GetValue(row)) & '"'
