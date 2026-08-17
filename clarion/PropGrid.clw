!=====================================================================
! PropGrid.clw - implementation of PropGridClass (see PropGrid.inc)
!
! Runtime facts this code relies on (all verified on Clarion 12 by
! probing a live window - see INSTALL.md "Verified runtime notes"):
!   * ?ctl{PROP:Text} on an ENTRY/SPIN returns the picture WITHOUT the
!     leading '@'  ->  'd17', 'n-9.2', 's30'.  ControlPicture() adds it.
!   * CONTENTS(feq) returns the RAW USE variable value, never the
!     formatted display text, so @D/@T values must be FORMAT()ed.
!   * CHANGE(feq,value) assigns the USE variable with a plain
!     string->numeric conversion. Feeding it a REAL loses the decimal
!     point, so numbers go through a LONG (dates/times) or the raw
!     text (everything else).
!   * OPTION: write with feq{PROP:Selected} = ordinal (that honours a
!     RADIO's VALUE attribute); CHANGE() on an OPTION corrupts it.
!   * CHECK : PROP:Checked is READ ONLY. Write with
!     CHANGE(feq, PROP:TrueValue / PROP:FalseValue), defaulting to 1/0.
!   * PROP:From reads back only for a string FROM(); a queue-driven
!     DROP is enumerated by walking PROP:Selected 1..PROP:Items.
!   * PROP:Use gives back the USE variable's VALUE, not its name, and a
!     control whose USE is only a field equate reads back BLANK - so
!     "does this control have a USE variable?" cannot be answered by
!     asking.  SetNameControl() writes with CHANGE() and then VERIFIES
!     with CONTENTS(); only when they disagree does it fall back to
!     PROP:Text.  (Measured: CHANGE() on a caption STRING sets no error
!     and changes nothing; on a STRING(@s30),USE(var) it sets var.)
!   * A grid BUTTON row POSTs EVENT:Accepted to the real control, and
!     that POSTed event is processed BEFORE the next EVENT:Timer reaches
!     TakeEvent (measured: the button handler ran on tick 0, the timer
!     tick after it was tick 1).  The lookup a button opens runs while
!     this ACCEPT loop is suspended, so PendingSyncFrom counts TWO ticks
!     before calling SyncFrom() - one tick would be enough in the common
!     case but not if EVENT:Timer was already queued.
!=====================================================================
  MEMBER

  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('PROPGRID.INC'),ONCE

  MAP
!   NOTE: the MODULE() label below must NOT be 'PROPGRID.DLL'.  Clarion
!   strips the extension and compares the result with the name of the
!   module being compiled - PropGrid.clw - decides these prototypes are
!   defined HERE, and every one of them fails with
!   "Missing procedure definition: PG_CREATE((LONG,...)".  The label is
!   only a grouping name; binding is by NAME() plus propgrid.lib.
    MODULE('ClaPropGridDLL')
PG_Initialize      PROCEDURE(),SIGNED,PROC,PASCAL,NAME('PG_Initialize')
PG_Shutdown        PROCEDURE(),PASCAL,NAME('PG_Shutdown')
PG_Create          PROCEDURE(UNSIGNED hwndParent, SIGNED x, SIGNED y, SIGNED w, SIGNED h, ULONG style),LONG,PASCAL,NAME('PG_Create')
PG_Destroy         PROCEDURE(LONG pg),PASCAL,NAME('PG_Destroy')
PG_SetPos          PROCEDURE(LONG pg, SIGNED x, SIGNED y, SIGNED w, SIGNED h),PASCAL,NAME('PG_SetPos')
PG_GetHwnd         PROCEDURE(LONG pg),UNSIGNED,PASCAL,NAME('PG_GetHwnd')
PG_SetFont         PROCEDURE(LONG pg, SIGNED part, *CSTRING face, SIGNED sizePt, SIGNED bold, SIGNED italic),PASCAL,RAW,NAME('PG_SetFont')
PG_SetColor        PROCEDURE(LONG pg, SIGNED slot, LONG color),PASCAL,NAME('PG_SetColor')
PG_SetRowHeight    PROCEDURE(LONG pg, SIGNED px),PASCAL,NAME('PG_SetRowHeight')
PG_SetSplitter     PROCEDURE(LONG pg, SIGNED px),PASCAL,NAME('PG_SetSplitter')
PG_Clear           PROCEDURE(LONG pg),PASCAL,NAME('PG_Clear')
PG_AddCategory     PROCEDURE(LONG pg, *CSTRING catName),SIGNED,PASCAL,RAW,NAME('PG_AddCategory')
PG_AddProperty     PROCEDURE(LONG pg, SIGNED category, *CSTRING propName, SIGNED propType, *CSTRING value),SIGNED,PASCAL,RAW,NAME('PG_AddProperty')
PG_SetChoices      PROCEDURE(LONG pg, SIGNED row, *CSTRING choices),PASCAL,RAW,NAME('PG_SetChoices')
PG_SetRange        PROCEDURE(LONG pg, SIGNED row, REAL low, REAL high, REAL step),PASCAL,NAME('PG_SetRange')
PG_SetDescription  PROCEDURE(LONG pg, SIGNED row, *CSTRING txt),PASCAL,RAW,NAME('PG_SetDescription')
PG_SetReadOnly     PROCEDURE(LONG pg, SIGNED row, SIGNED readOnly),PASCAL,NAME('PG_SetReadOnly')
PG_SetExpanded     PROCEDURE(LONG pg, SIGNED category, SIGNED expanded),PASCAL,NAME('PG_SetExpanded')
PG_SetTag          PROCEDURE(LONG pg, SIGNED row, LONG tag),PASCAL,NAME('PG_SetTag')
PG_GetTag          PROCEDURE(LONG pg, SIGNED row),LONG,PASCAL,NAME('PG_GetTag')
PG_SetValue        PROCEDURE(LONG pg, SIGNED row, *CSTRING value),PASCAL,RAW,NAME('PG_SetValue')
PG_GetValue        PROCEDURE(LONG pg, SIGNED row, *CSTRING buf, SIGNED bufLen),SIGNED,PROC,PASCAL,RAW,NAME('PG_GetValue')
PG_GetRowCount     PROCEDURE(LONG pg),SIGNED,PASCAL,NAME('PG_GetRowCount')
PG_FindRow         PROCEDURE(LONG pg, *CSTRING propName),SIGNED,PASCAL,RAW,NAME('PG_FindRow')
PG_GetSelected     PROCEDURE(LONG pg),SIGNED,PASCAL,NAME('PG_GetSelected')
PG_PollEvent       PROCEDURE(LONG pg, *SIGNED row, *SIGNED evType),SIGNED,PASCAL,RAW,NAME('PG_PollEvent')
PG_Redraw          PROCEDURE(LONG pg),PASCAL,NAME('PG_Redraw')
    END
  END

PGInitDone   BYTE(0)                        ! PG_Initialize() is once per process

!---------------------------------------------------------------------
PropGridClass.Construct PROCEDURE()
  CODE
  SELF.PG            = 0
  SELF.Win          &= NULL
  SELF.RegionFeq     = 0
  SELF.DockMode      = PGD:Region
  SELF.DockSize      = 0
  SELF.MarginX       = 0
  SELF.MarginY       = 0
  SELF.Style         = PGS:Border + PGS:Description
  SELF.LiveSync      = 0
  SELF.HideOriginals = 1
  SELF.Initialized   = 0
  SELF.TimerInterval = 10
  SELF.MaxScanItems  = 500
  SELF.NextPrompt    = 0
  SELF.PendingSyncFrom = 0
  SELF.TabCategories = 0
  SELF.Lookups      &= NEW(PropGridLookupQueue)
  SELF.Tabs         &= NEW(PropGridTabQueue)

PropGridClass.Destruct PROCEDURE()
  CODE
  IF SELF.PG
    PG_Destroy(SELF.PG)
    SELF.PG = 0
  END
  SELF.Initialized = 0
  IF ~SELF.Lookups &= NULL
    FREE(SELF.Lookups)
    DISPOSE(SELF.Lookups)
    SELF.Lookups &= NULL
  END
  IF ~SELF.Tabs &= NULL
    FREE(SELF.Tabs)
    DISPOSE(SELF.Tabs)
    SELF.Tabs &= NULL
  END

!---------------------------------------------------------------------
! lifetime
!---------------------------------------------------------------------
PropGridClass.Init PROCEDURE(WINDOW W, SIGNED regionFeq, ULONG style=3)
x   SIGNED
y   SIGNED
wd  SIGNED
ht  SIGNED
sav BYTE
  CODE
  SETTARGET(W)
  sav = 0{PROP:Pixels}
  0{PROP:Pixels} = TRUE
  x  = regionFeq{PROP:XPos}
  y  = regionFeq{PROP:YPos}
  wd = regionFeq{PROP:Width}
  ht = regionFeq{PROP:Height}
  0{PROP:Pixels} = sav
  SETTARGET()
  SELF.RegionFeq = regionFeq
  SELF.DockMode  = PGD:Region
  RETURN SELF.InitXY(W, x, y, wd, ht, style)

PropGridClass.InitXY PROCEDURE(WINDOW W, SIGNED x, SIGNED y, SIGNED width, SIGNED height, ULONG style=3)
  CODE
  IF SELF.PG THEN SELF.Kill().
  SELF.Win &= W
  SELF.Style = style
  IF ~PGInitDone
    PG_Initialize()
    PGInitDone = 1
  END
  IF width < 1 THEN width = 1.
  IF height < 1 THEN height = 1.
  SELF.PG = PG_Create(W{PROP:Handle}, x, y, width, height, style)
  IF ~SELF.PG THEN RETURN 0.
  IF SELF.TimerInterval > 0 AND W{PROP:Timer} = 0
    W{PROP:Timer} = SELF.TimerInterval             ! the event pump needs a timer
  END
  SELF.Initialized = 1
  RETURN 1

PropGridClass.Kill PROCEDURE()
  CODE
  IF SELF.PG
    PG_Destroy(SELF.PG)
    SELF.PG = 0
  END
  SELF.Initialized     = 0
  SELF.PendingSyncFrom = 0

PropGridClass.SetDock PROCEDURE(BYTE mode, SIGNED size=0, SIGNED marginX=0, SIGNED marginY=0)
  CODE
  SELF.DockMode = mode
  SELF.DockSize = size
  SELF.MarginX  = marginX
  SELF.MarginY  = marginY

PropGridClass.SetPos PROCEDURE(SIGNED x, SIGNED y, SIGNED width, SIGNED height)
  CODE
  IF ~SELF.PG THEN RETURN.
  IF width < 1 THEN width = 1.
  IF height < 1 THEN height = 1.
  PG_SetPos(SELF.PG, x, y, width, height)

PropGridClass.Reposition PROCEDURE()
x   SIGNED
y   SIGNED
wd  SIGNED
ht  SIGNED
cw  SIGNED
ch  SIGNED
sav BYTE
  CODE
  IF ~SELF.PG THEN RETURN.
  IF SELF.DockMode = PGD:Fixed THEN RETURN.
  IF SELF.DockMode = PGD:Region AND ~SELF.RegionFeq THEN RETURN.
  x  = 0
  y  = 0
  wd = 0
  ht = 0
  SETTARGET(SELF.Win)
  sav = 0{PROP:Pixels}
  0{PROP:Pixels} = TRUE
  IF SELF.DockMode = PGD:Region
    x  = SELF.RegionFeq{PROP:XPos}
    y  = SELF.RegionFeq{PROP:YPos}
    wd = SELF.RegionFeq{PROP:Width}
    ht = SELF.RegionFeq{PROP:Height}
  ELSE
    cw = 0{PROP:Width}
    ch = 0{PROP:Height}
    CASE SELF.DockMode
    OF PGD:Left
      x  = SELF.MarginX
      y  = SELF.MarginY
      wd = SELF.DockSize
      ht = ch - 2 * SELF.MarginY
    OF PGD:Right
      x  = cw - SELF.DockSize - SELF.MarginX
      y  = SELF.MarginY
      wd = SELF.DockSize
      ht = ch - 2 * SELF.MarginY
    ELSE                                            ! PGD:Fill
      x  = SELF.MarginX
      y  = SELF.MarginY
      wd = cw - 2 * SELF.MarginX
      ht = ch - 2 * SELF.MarginY
    END
  END
  0{PROP:Pixels} = sav
  SETTARGET()
  SELF.SetPos(x, y, wd, ht)

!---------------------------------------------------------------------
! appearance
!---------------------------------------------------------------------
PropGridClass.SetFont PROCEDURE(SHORT part, STRING face, SHORT sizePt, BYTE bold=0, BYTE italic=0)
cFace CSTRING(128)
  CODE
  IF ~SELF.PG THEN RETURN.
  cFace = CLIP(face)
  PG_SetFont(SELF.PG, part, cFace, sizePt, bold, italic)

PropGridClass.SetColor PROCEDURE(SHORT slot, LONG color)
  CODE
  IF SELF.PG THEN PG_SetColor(SELF.PG, slot, color).

PropGridClass.SetRowHeight PROCEDURE(SHORT px)
  CODE
  IF SELF.PG THEN PG_SetRowHeight(SELF.PG, px).

PropGridClass.SetSplitter PROCEDURE(SHORT px)
  CODE
  IF SELF.PG THEN PG_SetSplitter(SELF.PG, px).

!---------------------------------------------------------------------
! building
!---------------------------------------------------------------------
PropGridClass.ClearAll PROCEDURE()
i SIGNED
  CODE
  IF ~SELF.Lookups &= NULL THEN FREE(SELF.Lookups).   ! the rows they describe are going
  IF ~SELF.Tabs &= NULL                               ! the category ids die with the rows,
    LOOP i = 1 TO RECORDS(SELF.Tabs)                  ! but the names / overrides survive
      GET(SELF.Tabs, i)
      SELF.Tabs.CatId = 0
      PUT(SELF.Tabs)
    END
  END
  SELF.PendingSyncFrom = 0
  IF SELF.PG THEN PG_Clear(SELF.PG).

PropGridClass.AddCategory PROCEDURE(STRING catName)
cName CSTRING(256)
  CODE
  IF ~SELF.PG THEN RETURN 0.
  cName = CLIP(catName)
  RETURN PG_AddCategory(SELF.PG, cName)

!---------------------------------------------------------------------
! SetTabCategory - rename the category a TAB's controls will land in.
! Works with TabCategories off too: an override always makes a category
! for that one tab.  Call BEFORE BuildFromWindow.
!---------------------------------------------------------------------
PropGridClass.SetTabCategory PROCEDURE(SIGNED tabFeq, STRING catName)
  CODE
  IF ~tabFeq THEN RETURN.
  SELF.TabEntry(tabFeq)
  SELF.Tabs.CatName = catName
  PUT(SELF.Tabs)

!---------------------------------------------------------------------
! TabCategoryOf - the category of the TAB that holds feq, creating it
! on demand.  0 = feq is not inside a TAB, or tab categories are off
! and no override was set - use your default category instead.
!---------------------------------------------------------------------
PropGridClass.TabCategoryOf PROCEDURE(SIGNED feq)
tabFeq SIGNED
cat    SIGNED
  CODE
  IF ~SELF.PG OR ~feq THEN RETURN 0.
  SETTARGET(SELF.Win)
  tabFeq = SELF.OwnerTab(feq)
  cat    = CHOOSE(tabFeq <> 0, SELF.TabCategory(tabFeq, 0), 0)
  SETTARGET()
  RETURN cat

PropGridClass.AddProperty PROCEDURE(SIGNED category, STRING propName, SHORT propType, STRING value)
cName CSTRING(256)
cVal  CSTRING(4097)
  CODE
  IF ~SELF.PG THEN RETURN 0.
  cName = CLIP(propName)
  cVal  = CLIP(value)
  RETURN PG_AddProperty(SELF.PG, category, cName, propType, cVal)

PropGridClass.SetChoices PROCEDURE(SIGNED row, STRING choices)
cCho CSTRING(4097)
  CODE
  IF ~SELF.PG THEN RETURN.
  cCho = CLIP(choices)
  PG_SetChoices(SELF.PG, row, cCho)

PropGridClass.SetRange PROCEDURE(SIGNED row, REAL low, REAL high, REAL step=1)
  CODE
  IF SELF.PG THEN PG_SetRange(SELF.PG, row, low, high, step).

PropGridClass.SetDescription PROCEDURE(SIGNED row, STRING txt)
cTxt CSTRING(2049)
  CODE
  IF ~SELF.PG THEN RETURN.
  cTxt = CLIP(txt)
  PG_SetDescription(SELF.PG, row, cTxt)

PropGridClass.SetReadOnly PROCEDURE(SIGNED row, BYTE readOnly=1)
  CODE
  IF SELF.PG THEN PG_SetReadOnly(SELF.PG, row, readOnly).

PropGridClass.SetExpanded PROCEDURE(SIGNED category, BYTE expanded=1)
  CODE
  IF SELF.PG THEN PG_SetExpanded(SELF.PG, category, expanded).

PropGridClass.SetTag PROCEDURE(SIGNED row, LONG tag)
  CODE
  IF SELF.PG THEN PG_SetTag(SELF.PG, row, tag).

PropGridClass.GetTag PROCEDURE(SIGNED row)
  CODE
  IF ~SELF.PG THEN RETURN 0.
  RETURN PG_GetTag(SELF.PG, row)

!---------------------------------------------------------------------
! values
!---------------------------------------------------------------------
PropGridClass.SetValue PROCEDURE(SIGNED row, STRING value)
cVal CSTRING(4097)
  CODE
  IF ~SELF.PG THEN RETURN.
  cVal = CLIP(value)
  PG_SetValue(SELF.PG, row, cVal)

PropGridClass.GetValue PROCEDURE(SIGNED row)
buf CSTRING(4097)
  CODE
  IF ~SELF.PG THEN RETURN ''.
  buf = ''
  PG_GetValue(SELF.PG, row, buf, SIZE(buf))
  RETURN buf

PropGridClass.FindRow PROCEDURE(STRING propName)
cName CSTRING(256)
  CODE
  IF ~SELF.PG THEN RETURN 0.
  cName = CLIP(propName)
  RETURN PG_FindRow(SELF.PG, cName)

PropGridClass.GetSelected PROCEDURE()
  CODE
  IF ~SELF.PG THEN RETURN 0.
  RETURN PG_GetSelected(SELF.PG)

PropGridClass.RowCount PROCEDURE()
  CODE
  IF ~SELF.PG THEN RETURN 0.
  RETURN PG_GetRowCount(SELF.PG)

!---------------------------------------------------------------------
! AddControl - create one grid row from an existing window control.
! Uses runtime reflection: control type, picture, range, choices.
! Returns the new row id, or 0 when the control has no grid equivalent.
!---------------------------------------------------------------------
PropGridClass.AddControl PROCEDURE(SIGNED feq, SIGNED category=0)
ctype LONG
row   SIGNED
lbl   STRING(256)
val   STRING(4096)
cho   STRING(4096)
pic   STRING(64)
tip   STRING(256)
ptype SHORT
lv    LONG
lo    REAL
hi    REAL
st    REAL
ro    BYTE
  CODE
  IF ~SELF.PG THEN RETURN 0.
  SETTARGET(SELF.Win)
  ctype = feq{PROP:Type}
  lbl   = SELF.ControlLabel(feq, SELF.NextPrompt)
  SELF.NextPrompt = 0
  ptype = 0
  cho   = ''
  val   = ''
  lo    = 0
  hi    = 0
  st    = 1
  CASE ctype
  OF CREATE:entry OROF CREATE:spin OROF CREATE:singleline
    pic = SELF.ControlPicture(feq)
    CASE UPPER(SUB(pic,2,1))
    OF 'D'
      ptype = PGT:Date
    OF 'T'
      ptype = PGT:Time
    ELSE
      IF feq{PROP:Password}
        ptype = PGT:Password
      ELSIF ctype = CREATE:spin
        ptype = PGT:Spin
      ELSE
        ptype = PGT:Text
      END
    END
    IF ptype = PGT:Date OR ptype = PGT:Time
      lv  = CONTENTS(feq)                          ! CONTENTS is the RAW value
      val = FORMAT(lv, pic)
    ELSE
      val = CONTENTS(feq)
    END
    IF ctype = CREATE:spin
      lo = feq{PROP:RangeLow}
      hi = feq{PROP:RangeHigh}
      st = feq{PROP:Step}
    END
  OF CREATE:slider
    ptype = PGT:Slider
    val   = CONTENTS(feq)
    lo    = feq{PROP:RangeLow}
    hi    = feq{PROP:RangeHigh}
    st    = feq{PROP:Step}
  OF CREATE:check OROF CREATE:state3
    ptype = PGT:Check
    val   = CHOOSE(feq{PROP:Checked} = 1, '1', '0')
  OF CREATE:option
    ptype = PGT:Radio
    cho   = SELF.ChildLabels(feq)
    val   = SELF.ChildLabelAt(feq, CHOICE(feq))
  OF CREATE:list OROF CREATE:combo OROF CREATE:droplist OROF CREATE:dropcombo
    IF feq{PROP:Drop}                              ! a plain browse LIST is not a property
      ptype = PGT:Drop
      cho   = SELF.ListChoices(feq)
      val   = CONTENTS(feq)
    END
  OF CREATE:text OROF CREATE:rtf
    ptype = PGT:MultiText
    val   = CONTENTS(feq)
  OF CREATE:button
    ptype = PGT:Button
    val   = ''
  OF CREATE:string OROF CREATE:sstring OROF CREATE:prompt
    ptype = PGT:ReadOnly
    val   = feq{PROP:Text}
  END
  IF ~ptype
    SETTARGET()
    RETURN 0
  END
  ro = 0
  IF feq{PROP:ReadOnly} OR feq{PROP:Disable} THEN ro = 1.
  tip = feq{PROP:Tip}
  IF st = 0 THEN st = 1.
  SETTARGET()
  row = SELF.AddProperty(category, lbl, ptype, val)
  IF ~row THEN RETURN 0.
  SELF.SetTag(row, feq)
  IF cho <> '' THEN SELF.SetChoices(row, cho).
  IF hi > lo THEN SELF.SetRange(row, lo, hi, st).
  IF tip <> '' THEN SELF.SetDescription(row, tip).
  IF ro THEN SELF.SetReadOnly(row, 1).
  RETURN row

!---------------------------------------------------------------------
! BuildFromWindow - walk every control on the window, convert the
! supported ones into grid rows and (optionally) hide the originals
! together with the PROMPT/STRING that labels them.
! excludeFeqs = pipe-delimited list of FEQs to leave alone.  Excluding
! a container (SHEET / TAB / GROUP / OPTION) excludes everything inside
! it - that is how a whole browse tab stays alive.
! With TabCategories on, each TAB's text names a category and the
! rows land under their own tab's header (see TabCategory).
!---------------------------------------------------------------------
PropGridClass.BuildFromWindow PROCEDURE(SIGNED category=0, <STRING excludeFeqs>)
feq        SIGNED
ctype      LONG
row        SIGNED
added      SIGNED
labelFeq   SIGNED
tabFeq     SIGNED
cat        SIGNED
excl       STRING(1024)
  CODE
  IF ~SELF.PG THEN RETURN 0.
  IF OMITTED(excludeFeqs)
    excl = ''
  ELSE
    excl = '|' & CLIP(excludeFeqs) & '|'
  END
  added    = 0
  labelFeq = 0
  SETTARGET(SELF.Win)
  LOOP feq = FIRSTFIELD() TO LASTFIELD()
    ctype = feq{PROP:Type}
    IF ~ctype THEN CYCLE.
    IF feq = SELF.RegionFeq THEN CYCLE.
    IF SELF.IsExcluded(feq, excl)                  ! the control itself, or a
      labelFeq = 0                                 ! container above it - do NOT let
      CYCLE                                        ! the next control steal its prompt
    END
    IF feq{PROP:Hide} THEN CYCLE.
    CASE ctype
    OF CREATE:prompt OROF CREATE:string OROF CREATE:sstring
      labelFeq = feq                               ! label for the NEXT data control
      CYCLE
    OF CREATE:radio OROF CREATE:sheet OROF CREATE:tab OROF CREATE:group    |
         OROF CREATE:panel OROF CREATE:image OROF CREATE:line              |
         OROF CREATE:box OROF CREATE:ellipse OROF CREATE:region            |
         OROF CREATE:menu OROF CREATE:item OROF CREATE:menubar             |
         OROF CREATE:toolbar OROF CREATE:progress OROF CREATE:custom       |
         OROF CREATE:ole
      CYCLE
    END
    cat    = category
    tabFeq = SELF.OwnerTab(feq)
    IF tabFeq THEN cat = SELF.TabCategory(tabFeq, category).
    SELF.NextPrompt = labelFeq
    SETTARGET()
    row = SELF.AddControl(feq, cat)
    SETTARGET(SELF.Win)
    IF row
      added += 1
      IF SELF.HideOriginals
        feq{PROP:Hide} = TRUE
        IF labelFeq THEN labelFeq{PROP:Hide} = TRUE.
      END
    END
    labelFeq = 0
  END
  SETTARGET()
  SELF.Redraw()
  RETURN added

!---------------------------------------------------------------------
! TrimTabs - hide every TAB the conversion emptied, and any SHEET
! whose last visible TAB just went.  Call this AFTER the lookup trios
! are folded (AddFileDrop hides its controls, so a tab that is nothing
! but lookups only empties then) and after any manual hiding.
!---------------------------------------------------------------------
PropGridClass.TrimTabs PROCEDURE()
feq  SIGNED
i    SIGNED
ch   SIGNED
live BYTE
  CODE
  IF SELF.Win &= NULL THEN RETURN.
  SETTARGET(SELF.Win)
  LOOP feq = FIRSTFIELD() TO LASTFIELD()
    IF feq{PROP:Type} = CREATE:tab AND ~feq{PROP:Hide}
      IF SELF.ContainerEmptied(feq) THEN feq{PROP:Hide} = TRUE.
    END
  END
  LOOP feq = FIRSTFIELD() TO LASTFIELD()
    IF feq{PROP:Type} = CREATE:sheet AND ~feq{PROP:Hide}
      live = 0
      LOOP i = 1 TO 512
        ch = feq{PROP:Child, i}
        IF ~ch THEN BREAK.
        IF ch{PROP:Type} = CREATE:tab AND ~ch{PROP:Hide}
          live = 1
          BREAK
        END
      END
      IF ~live THEN feq{PROP:Hide} = TRUE.
    END
  END
  SETTARGET()

!---------------------------------------------------------------------
! AddFileDrop - fold a "lookup trio" (code ENTRY + '...' BUTTON +
! description STRING) into ONE drop-down row that shows the DESCRIPTION
! and writes the CODE back.
!
!   codes / names  parallel pipe lists, one item per lookup-file record
!                  ('D01|D02'  /  'Sales|Support').  Build them with
!                  PipeSafe() so a '|' inside the data cannot split them.
!   codeFeq        the real ENTRY - hidden here, tagged on the row, and
!                  the target of every write-back.
!   nameFeq        the description control - hidden here, kept in step.
!   label          '' = take the PROMPT/STRING in front of codeFeq.
!
! The '...' BUTTON is NOT touched: the caller (the template) hides it,
! because a lookup row makes it redundant.
!---------------------------------------------------------------------
PropGridClass.AddFileDrop PROCEDURE(SIGNED category, STRING label, SIGNED codeFeq, SIGNED nameFeq, |
                                    STRING codes, STRING names, <STRING description>)
row  SIGNED
ord  SIGNED
lfeq SIGNED
code STRING(256)
val  STRING(256)
cap  STRING(256)
  CODE
  IF ~SELF.PG OR ~codeFeq THEN RETURN 0.
  cap = CLIP(LEFT(label))
  SETTARGET(SELF.Win)
  code = CONTENTS(codeFeq)                         ! CONTENTS is the RAW value
  lfeq = SELF.PrevLabelFeq(codeFeq, nameFeq)
  IF cap = '' THEN cap = SELF.ControlLabel(codeFeq, lfeq).
  codeFeq{PROP:Hide} = TRUE                        ! the drop row replaces the trio
  IF nameFeq THEN nameFeq{PROP:Hide} = TRUE.
  IF SELF.HideOriginals AND lfeq THEN lfeq{PROP:Hide} = TRUE.
  SETTARGET()
  ord = SELF.PipeFind(codes, code)
  IF ord
    val = SELF.PipeItem(names, ord)
  ELSE
    val = CLIP(LEFT(code))                         ! unknown code - show it raw
  END
  row = SELF.AddProperty(category, cap, PGT:Drop, val)
  IF ~row THEN RETURN 0.
  SELF.SetChoices(row, names)
  SELF.SetTag(row, codeFeq)                        ! SyncRow/SyncFrom find the control here
  IF ~OMITTED(description)
    IF CLIP(description) <> '' THEN SELF.SetDescription(row, description).
  END
  IF SELF.Lookups &= NULL THEN SELF.Lookups &= NEW(PropGridLookupQueue).
  CLEAR(SELF.Lookups)
  SELF.Lookups.Row     = row
  SELF.Lookups.CodeFeq = codeFeq
  SELF.Lookups.NameFeq = nameFeq
  SELF.Lookups.Codes   = codes
  SELF.Lookups.Names   = names
  ADD(SELF.Lookups)
  IF ord AND nameFeq
    SETTARGET(SELF.Win)
    SELF.SetNameControl(nameFeq, val)
    SETTARGET()
  END
  RETURN row

!---------------------------------------------------------------------
! SyncRow - copy one grid value back into the source control / USE var
!---------------------------------------------------------------------
PropGridClass.SyncRow PROCEDURE(SIGNED row)
feq   SIGNED
val   STRING(4096)
tv    STRING(64)
fv    STRING(64)
ctype LONG
ord   SIGNED
  CODE
  IF ~SELF.PG THEN RETURN.
  feq = SELF.GetTag(row)
  IF ~feq THEN RETURN.
  val = SELF.GetValue(row)
  IF SELF.FindLookup(row)                          ! a lookup row: name -> code
    ord = SELF.PipeFind(SELF.Lookups.Names, val)
    IF ~ord THEN RETURN.                           ! not one of the choices - leave it
    SETTARGET(SELF.Win)
    SELF.WriteControl(SELF.Lookups.CodeFeq, SELF.PipeItem(SELF.Lookups.Codes, ord))
    IF SELF.Lookups.NameFeq
      SELF.SetNameControl(SELF.Lookups.NameFeq, SELF.PipeItem(SELF.Lookups.Names, ord))
    END
    SETTARGET()
    RETURN
  END
  SETTARGET(SELF.Win)
  ctype = feq{PROP:Type}
  CASE ctype
  OF CREATE:check OROF CREATE:state3
    tv = feq{PROP:TrueValue}
    fv = feq{PROP:FalseValue}
    IF tv = '' THEN tv = '1'.
    IF fv = '' THEN fv = '0'.
    IF CLIP(LEFT(val)) = '1' OR UPPER(CLIP(LEFT(val))) = 'TRUE' OR UPPER(CLIP(LEFT(val))) = 'YES'
      CHANGE(feq, CLIP(tv))
    ELSE
      CHANGE(feq, CLIP(fv))
    END
  OF CREATE:option
    ord = SELF.ChildOrdinal(feq, val)
    IF ord > 0 THEN feq{PROP:Selected} = ord.       ! honours the RADIO's VALUE()
  OF CREATE:list OROF CREATE:combo OROF CREATE:droplist OROF CREATE:dropcombo
    IF ~SELF.ListSelect(feq, val)
      CHANGE(feq, CLIP(val))
    END
  OF CREATE:entry OROF CREATE:spin OROF CREATE:singleline
    SELF.WriteControl(feq, val)
  OF CREATE:button OROF CREATE:string OROF CREATE:sstring OROF CREATE:prompt
    !- nothing to write back for these -
  ELSE
    CHANGE(feq, CLIP(val))
  END
  SETTARGET()

PropGridClass.SyncBack PROCEDURE()
i   SIGNED
cnt SIGNED
  CODE
  cnt = SELF.RowCount()
  LOOP i = 1 TO cnt
    SELF.SyncRow(i)
  END

PropGridClass.SyncFrom PROCEDURE()
i     SIGNED
cnt   SIGNED
feq   SIGNED
ord   SIGNED
val   STRING(4096)
pic   STRING(64)
lv    LONG
  CODE
  IF ~SELF.PG THEN RETURN.
  cnt = SELF.RowCount()
  LOOP i = 1 TO cnt
    feq = SELF.GetTag(i)
    IF ~feq THEN CYCLE.
    IF SELF.FindLookup(i)                          ! a lookup row: code -> name
      SETTARGET(SELF.Win)
      val = CONTENTS(SELF.Lookups.CodeFeq)
      SETTARGET()
      ord = SELF.PipeFind(SELF.Lookups.Codes, val)
      IF ord
        val = SELF.PipeItem(SELF.Lookups.Names, ord)
        IF SELF.Lookups.NameFeq
          SETTARGET(SELF.Win)
          SELF.SetNameControl(SELF.Lookups.NameFeq, val)
          SETTARGET()
        END
      ELSE
        val = CLIP(LEFT(val))                      ! unknown code - show it raw
      END
      SELF.SetValue(i, val)
      CYCLE
    END
    val = ''
    SETTARGET(SELF.Win)
    CASE feq{PROP:Type}
    OF CREATE:check OROF CREATE:state3
      val = CHOOSE(feq{PROP:Checked} = 1, '1', '0')
    OF CREATE:option
      val = SELF.ChildLabelAt(feq, CHOICE(feq))
    OF CREATE:button
      val = ''
    OF CREATE:string OROF CREATE:sstring OROF CREATE:prompt
      val = feq{PROP:Text}
    OF CREATE:entry OROF CREATE:spin OROF CREATE:singleline
      pic = SELF.ControlPicture(feq)
      CASE UPPER(SUB(pic,2,1))
      OF 'D' OROF 'T'
        lv  = CONTENTS(feq)
        val = FORMAT(lv, pic)
      ELSE
        val = CONTENTS(feq)
      END
    ELSE
      val = CONTENTS(feq)
    END
    SETTARGET()
    SELF.SetValue(i, val)
  END
  SELF.Redraw()

!---------------------------------------------------------------------
! event pump
!---------------------------------------------------------------------
PropGridClass.TakeEvent PROCEDURE()
row     SIGNED
evt     SIGNED
handled BYTE
guard   SIGNED
  CODE
  IF ~SELF.PG THEN RETURN 0.
!  A grid BUTTON row POSTs EVENT:Accepted to the real control (TakeButton)
!  and arms this countdown.  The POSTed event - and, for a lookup button,
!  the whole browse it opens - is processed while this ACCEPT loop is
!  suspended, so by the time the SECOND timer tick gets here the USE
!  variables hold whatever the lookup wrote and the grid can be refreshed.
!  One tick is NOT enough: the POSTed event may still be queued behind the
!  EVENT:Timer that is being handled right now.
  IF SELF.PendingSyncFrom
    SELF.PendingSyncFrom -= 1
    IF ~SELF.PendingSyncFrom THEN SELF.SyncFrom().
  END
  handled = 0
  guard   = 0
  LOOP
    guard += 1
    IF guard > 2000 THEN BREAK.
    row = 0
    evt = 0
    IF ~PG_PollEvent(SELF.PG, row, evt) THEN BREAK.
    handled = 1
    CASE evt
    OF PGE:Changed
      SELF.TakeChanged(row)
    OF PGE:Button
      SELF.TakeButton(row)
    OF PGE:Select OROF PGE:DblClick
      SELF.TakeSelect(row)
    END
  END
  RETURN handled

PropGridClass.TakeChanged PROCEDURE(SIGNED row)
  CODE
  IF SELF.LiveSync THEN SELF.SyncRow(row).

PropGridClass.TakeButton PROCEDURE(SIGNED row)
feq SIGNED
  CODE
  feq = SELF.GetTag(row)
  IF feq
    POST(EVENT:Accepted, feq)
    SELF.PendingSyncFrom = 2                       ! see TakeEvent: refresh AFTER it ran
  END

PropGridClass.TakeSelect PROCEDURE(SIGNED row)
  CODE
  !- hook for derived classes -

PropGridClass.Redraw PROCEDURE()
  CODE
  IF SELF.PG THEN PG_Redraw(SELF.PG).

!---------------------------------------------------------------------
! internals - every one of these assumes SETTARGET(SELF.Win) is active
!---------------------------------------------------------------------
PropGridClass.ControlLabel PROCEDURE(SIGNED feq, SIGNED prevLabelFeq)
txt STRING(256)
p   SIGNED
  CODE
  txt = ''
  IF prevLabelFeq
    txt = prevLabelFeq{PROP:Text}
  END
  IF txt = ''
    CASE feq{PROP:Type}
    OF CREATE:check OROF CREATE:state3 OROF CREATE:button OROF CREATE:radio |
         OROF CREATE:option OROF CREATE:group OROF CREATE:prompt            |
         OROF CREATE:string OROF CREATE:sstring OROF CREATE:tab
      txt = feq{PROP:Text}                        ! a real caption, not a picture
    END
  END
  LOOP                                            ! strip accelerator ampersands
    p = INSTRING('&', txt, 1, 1)
    IF ~p THEN BREAK.
    txt = SUB(txt, 1, p - 1) & SUB(txt, p + 1, SIZE(txt) - p)
  END
  txt = LEFT(txt)
  IF txt <> ''
    IF SUB(CLIP(txt), LEN(CLIP(txt)), 1) = ':'
      txt = SUB(CLIP(txt), 1, LEN(CLIP(txt)) - 1)
    END
  END
  IF txt = '' THEN txt = 'Field ' & feq.
  RETURN CLIP(txt)

PropGridClass.ControlPicture PROCEDURE(SIGNED feq)
t STRING(64)
  CODE
  t = feq{PROP:Text}                              ! ENTRY/SPIN: the picture, NO leading @
  IF t = '' THEN RETURN ''.
  IF SUB(t,1,1) = '@' THEN RETURN CLIP(t).
  RETURN '@' & CLIP(t)

PropGridClass.ChildLabels PROCEDURE(SIGNED optFeq)
res STRING(4096)
i   SIGNED
n   SIGNED
ch  SIGNED
  CODE
  res = ''
  n   = 0
  LOOP i = 1 TO 256
    ch = optFeq{PROP:Child, i}
    IF ~ch THEN BREAK.
    IF ch{PROP:Type} = CREATE:radio
      n += 1
      SELF.PipeAppend(res, SELF.ControlLabel(ch, 0), n)
    END
  END
  RETURN CLIP(res)

PropGridClass.ChildLabelAt PROCEDURE(SIGNED optFeq, SIGNED ordinal)
i   SIGNED
n   SIGNED
ch  SIGNED
  CODE
  IF ordinal < 1 THEN RETURN ''.
  n = 0
  LOOP i = 1 TO 256
    ch = optFeq{PROP:Child, i}
    IF ~ch THEN BREAK.
    IF ch{PROP:Type} = CREATE:radio
      n += 1
      IF n = ordinal THEN RETURN CLIP(SELF.ControlLabel(ch, 0)).
    END
  END
  RETURN ''

PropGridClass.ChildOrdinal PROCEDURE(SIGNED optFeq, STRING label)
i   SIGNED
n   SIGNED
ch  SIGNED
  CODE
  n = 0
  LOOP i = 1 TO 256
    ch = optFeq{PROP:Child, i}
    IF ~ch THEN BREAK.
    IF ch{PROP:Type} = CREATE:radio
      n += 1
      IF UPPER(CLIP(SELF.ControlLabel(ch, 0))) = UPPER(CLIP(LEFT(label)))
        RETURN n
      END
    END
  END
  RETURN 0

PropGridClass.ListChoices PROCEDURE(SIGNED feq)
res  STRING(4096)
sTxt STRING(256)
i    SIGNED
n    SIGNED
sOrd SIGNED
  CODE
  res = feq{PROP:From}                            ! only a string FROM() reads back
  IF res <> '' THEN RETURN CLIP(res).
  n = feq{PROP:Items}
  IF n < 1 OR n > SELF.MaxScanItems THEN RETURN ''.
  sOrd = CHOICE(feq)
  sTxt = CONTENTS(feq)
  LOOP i = 1 TO n
    feq{PROP:Selected} = i
    SELF.PipeAppend(res, CONTENTS(feq), i)
  END
  IF sOrd > 0
    feq{PROP:Selected} = sOrd
  ELSE
    CHANGE(feq, CLIP(sTxt))
  END
  RETURN CLIP(res)

PropGridClass.ListSelect PROCEDURE(SIGNED feq, STRING val)
i    SIGNED
n    SIGNED
sOrd SIGNED
  CODE
  n = feq{PROP:Items}
  IF n < 1 OR n > SELF.MaxScanItems THEN RETURN 0.
  sOrd = CHOICE(feq)
  LOOP i = 1 TO n
    feq{PROP:Selected} = i
    IF UPPER(CLIP(CONTENTS(feq))) = UPPER(CLIP(LEFT(val)))
      RETURN 1
    END
  END
  IF sOrd > 0 THEN feq{PROP:Selected} = sOrd.
  RETURN 0

!---------------------------------------------------------------------
! WriteControl - the ENTRY / SPIN write-back rule, in one place:
! an @D / @T picture round-trips through a LONG (CHANGE() with a REAL
! loses the decimal point), everything else goes back as plain text.
! Assumes SETTARGET(SELF.Win) is active.
!---------------------------------------------------------------------
PropGridClass.WriteControl PROCEDURE(SIGNED feq, STRING val)
pic STRING(64)
lv  LONG
  CODE
  IF ~feq THEN RETURN.
  pic = SELF.ControlPicture(feq)
  CASE UPPER(SUB(pic,2,1))
  OF 'D' OROF 'T'
    lv = DEFORMAT(CLIP(LEFT(val)), pic)             ! LONG keeps CHANGE() exact
    CHANGE(feq, lv)
  ELSE
    CHANGE(feq, CLIP(val))
  END

!---------------------------------------------------------------------
! PrevLabelFeq - the PROMPT / STRING that labels the control at feq, i.e.
! the nearest one DECLARED before it (skipFeq, the description control,
! is stepped over).  Anything else in the way means the control has no
! label of its own.  Assumes SETTARGET(SELF.Win) is active.
!---------------------------------------------------------------------
PropGridClass.PrevLabelFeq PROCEDURE(SIGNED feq, SIGNED skipFeq)
i SIGNED
n SIGNED
t LONG
  CODE
  IF feq < 2 THEN RETURN 0.
  n = 0
  LOOP i = feq - 1 TO 1 BY -1
    n += 1
    IF n > 32 THEN BREAK.                           ! the label is never far away
    IF i = skipFeq THEN CYCLE.
    t = i{PROP:Type}
    IF ~t THEN CYCLE.                               ! no such control - keep walking
    CASE t
    OF CREATE:prompt OROF CREATE:string OROF CREATE:sstring
      RETURN i
    END
    BREAK                                           ! a real control - give up
  END
  RETURN 0

!---------------------------------------------------------------------
! SetNameControl - put txt into the description control.
!
! There is NO reliable way to ask a control whether it has a USE
! VARIABLE: PROP:Use gives back the variable's VALUE (blank for a
! field-equate-only USE, but also blank for an empty variable).  So the
! write is done and then VERIFIED: CHANGE() first - that is what a form
! saves - and only when CONTENTS() disagrees is the control a caption
! with nothing behind it, which takes PROP:Text instead.
! Assumes SETTARGET(SELF.Win) is active.
!---------------------------------------------------------------------
PropGridClass.SetNameControl PROCEDURE(SIGNED feq, STRING txt)
want STRING(256)
  CODE
  IF ~feq THEN RETURN.
  want = CLIP(LEFT(txt))
  CHANGE(feq, want)
  IF CLIP(LEFT(CONTENTS(feq))) = CLIP(want) THEN RETURN.
  CASE feq{PROP:Type}                              ! no USE variable behind it
  OF CREATE:string OROF CREATE:sstring OROF CREATE:prompt
    feq{PROP:Text} = CLIP(want)
  END

!---------------------------------------------------------------------
! tab helpers (all assume SETTARGET(SELF.Win) is active)
!---------------------------------------------------------------------
! IsExcluded - feq, or any container above it, is in the exclude list.
! The parent walk is what makes "exclude the TAB" spare its children.
PropGridClass.IsExcluded PROCEDURE(SIGNED feq, STRING excl)
p SIGNED
  CODE
  IF excl = '' THEN RETURN 0.
  p = feq
  LOOP WHILE p
    IF INSTRING('|' & p & '|', excl, 1, 1) THEN RETURN 1.
    p = p{PROP:Parent}
  END
  RETURN 0

PropGridClass.OwnerTab PROCEDURE(SIGNED feq)
p SIGNED
  CODE
  p = feq{PROP:Parent}
  LOOP WHILE p
    IF p{PROP:Type} = CREATE:tab THEN RETURN p.
    p = p{PROP:Parent}
  END
  RETURN 0

PropGridClass.TabEntry PROCEDURE(SIGNED tabFeq)
i SIGNED
  CODE
  LOOP i = 1 TO RECORDS(SELF.Tabs)
    GET(SELF.Tabs, i)
    IF SELF.Tabs.TabFeq = tabFeq THEN RETURN.
  END
  CLEAR(SELF.Tabs)
  SELF.Tabs.TabFeq = tabFeq
  ADD(SELF.Tabs)                                   ! the buffer stays on the new entry

! TabCategory - the category id for a TAB, created the first time a row
! wants it.  An explicit SetTabCategory name always wins; otherwise the
! TAB's own text - but only when TabCategories is on.  fallback = the
! caller's default category.
PropGridClass.TabCategory PROCEDURE(SIGNED tabFeq, SIGNED fallback)
nm STRING(256)
  CODE
  SELF.TabEntry(tabFeq)
  IF SELF.Tabs.CatId THEN RETURN SELF.Tabs.CatId.
  IF SELF.Tabs.CatName <> ''
    nm = SELF.Tabs.CatName
  ELSIF SELF.TabCategories
    nm = SELF.ControlLabel(tabFeq, 0)              ! the TAB's text, ampersands stripped
  ELSE
    RETURN fallback
  END
  IF CLIP(nm) = '' THEN RETURN fallback.
  SELF.Tabs.CatId = SELF.AddCategory(CLIP(nm))
  PUT(SELF.Tabs)
  RETURN SELF.Tabs.CatId

! ContainerEmptied - nothing visible is left inside: every child is
! hidden, or is itself a container with nothing visible inside it.
PropGridClass.ContainerEmptied PROCEDURE(SIGNED feq)
i  SIGNED
ch SIGNED
  CODE
  LOOP i = 1 TO 512
    ch = feq{PROP:Child, i}
    IF ~ch THEN BREAK.
    IF ch{PROP:Hide} THEN CYCLE.
    CASE ch{PROP:Type}
    OF CREATE:group OROF CREATE:option OROF CREATE:sheet OROF CREATE:tab
      IF ~SELF.ContainerEmptied(ch) THEN RETURN 0.
    ELSE
      RETURN 0                                     ! a live control - keep the tab
    END
  END
  RETURN 1

!---------------------------------------------------------------------
! pipe-delimited list helpers
!---------------------------------------------------------------------
PropGridClass.PipeAppend PROCEDURE(*STRING list, STRING value, SIGNED itemNo)
  CODE
  IF itemNo > 1
    list = CLIP(list) & '|' & CLIP(value)
  ELSE
    list = CLIP(value)                              ! item 1 may legitimately be blank
  END

PropGridClass.PipeSafe PROCEDURE(STRING txt)
s STRING(256)
p SIGNED
  CODE
  s = CLIP(LEFT(txt))                               ! numerics arrive right justified
  LOOP
    p = INSTRING('|', s, 1, 1)
    IF ~p THEN BREAK.
    s[p : p] = '/'                                  ! a '|' in the DATA would split the list
  END
  RETURN CLIP(s)

PropGridClass.PipeItem PROCEDURE(STRING list, SIGNED ordinal)
s  STRING(4096)
p1 SIGNED
p2 SIGNED
n  SIGNED
  CODE
  IF ordinal < 1 THEN RETURN ''.
  s  = list
  p1 = 1
  n  = 0
  LOOP
    n += 1
    IF n > 4096 THEN BREAK.
    p2 = INSTRING('|', s, 1, p1)
    IF n = ordinal
      IF p2
        RETURN CLIP(SUB(s, p1, p2 - p1))
      ELSE
        RETURN CLIP(SUB(s, p1, SIZE(s) - p1 + 1))
      END
    END
    IF ~p2 THEN BREAK.
    p1 = p2 + 1
    IF p1 > SIZE(s) THEN BREAK.
  END
  RETURN ''

!  PipeFind - ordinal of value inside list, 0 when it is not there.
!  Case insensitive, blank tolerant, and - when BOTH sides are numeric -
!  value tolerant too, so '1' finds '001' and '1.00' finds '1'.  An exact
!  text match always wins over a numeric one.
PropGridClass.PipeFind PROCEDURE(STRING list, STRING value)
s     STRING(4096)
item  STRING(256)
want  STRING(256)
p1    SIGNED
p2    SIGNED
n     SIGNED
hit   SIGNED
isnum BYTE
  CODE
  want = UPPER(CLIP(LEFT(value)))
  IF want = '' THEN RETURN 0.
  s = list
  IF CLIP(s) = '' THEN RETURN 0.
  isnum = NUMERIC(CLIP(want))
  hit   = 0
  p1    = 1
  n     = 0
  LOOP
    n += 1
    IF n > 4096 THEN BREAK.
    p2 = INSTRING('|', s, 1, p1)
    IF p2
      item = SUB(s, p1, p2 - p1)
    ELSE
      item = SUB(s, p1, SIZE(s) - p1 + 1)
    END
    item = UPPER(CLIP(LEFT(item)))
    IF item = want THEN RETURN n.
    IF ~hit AND isnum AND NUMERIC(CLIP(item))
      IF DEFORMAT(CLIP(item)) = DEFORMAT(CLIP(want)) THEN hit = n.
    END
    IF ~p2 THEN BREAK.
    p1 = p2 + 1
    IF p1 > SIZE(s) THEN BREAK.
  END
  RETURN hit

!  FindLookup - is this row an AddFileDrop row?  On a hit the queue
!  buffer is left FIXed on it, so the caller reads SELF.Lookups.xxx.
PropGridClass.FindLookup PROCEDURE(SIGNED row)
i SIGNED
  CODE
  IF SELF.Lookups &= NULL OR ~row THEN RETURN 0.
  LOOP i = 1 TO RECORDS(SELF.Lookups)
    GET(SELF.Lookups, i)
    IF ERRORCODE() THEN BREAK.
    IF SELF.Lookups.Row = row THEN RETURN 1.
  END
  RETURN 0
