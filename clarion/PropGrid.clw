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

PropGridClass.Destruct PROCEDURE()
  CODE
  IF SELF.PG
    PG_Destroy(SELF.PG)
    SELF.PG = 0
  END
  SELF.Initialized = 0

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
  SELF.Initialized = 0

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
  CODE
  IF SELF.PG THEN PG_Clear(SELF.PG).

PropGridClass.AddCategory PROCEDURE(STRING catName)
cName CSTRING(256)
  CODE
  IF ~SELF.PG THEN RETURN 0.
  cName = CLIP(catName)
  RETURN PG_AddCategory(SELF.PG, cName)

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
! excludeFeqs = pipe-delimited list of FEQs to leave alone.
!---------------------------------------------------------------------
PropGridClass.BuildFromWindow PROCEDURE(SIGNED category=0, <STRING excludeFeqs>)
feq        SIGNED
ctype      LONG
row        SIGNED
added      SIGNED
labelFeq   SIGNED
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
    IF excl <> '' AND INSTRING('|' & feq & '|', excl, 1, 1) THEN CYCLE.
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
    SELF.NextPrompt = labelFeq
    SETTARGET()
    row = SELF.AddControl(feq, category)
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
! SyncRow - copy one grid value back into the source control / USE var
!---------------------------------------------------------------------
PropGridClass.SyncRow PROCEDURE(SIGNED row)
feq   SIGNED
val   STRING(4096)
pic   STRING(64)
tv    STRING(64)
fv    STRING(64)
ctype LONG
ord   SIGNED
lv    LONG
  CODE
  IF ~SELF.PG THEN RETURN.
  feq = SELF.GetTag(row)
  IF ~feq THEN RETURN.
  val = SELF.GetValue(row)
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
    pic = SELF.ControlPicture(feq)
    CASE UPPER(SUB(pic,2,1))
    OF 'D' OROF 'T'
      lv = DEFORMAT(CLIP(LEFT(val)), pic)           ! LONG keeps CHANGE() exact
      CHANGE(feq, lv)
    ELSE
      CHANGE(feq, CLIP(val))
    END
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
val   STRING(4096)
pic   STRING(64)
lv    LONG
  CODE
  IF ~SELF.PG THEN RETURN.
  cnt = SELF.RowCount()
  LOOP i = 1 TO cnt
    feq = SELF.GetTag(i)
    IF ~feq THEN CYCLE.
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
  IF feq THEN POST(EVENT:Accepted, feq).

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
         OROF CREATE:string OROF CREATE:sstring
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
      IF n > 1
        res = CLIP(res) & '|' & CLIP(SELF.ControlLabel(ch, 0))
      ELSE
        res = CLIP(SELF.ControlLabel(ch, 0))
      END
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
    IF i > 1
      res = CLIP(res) & '|' & CLIP(CONTENTS(feq))
    ELSE
      res = CLIP(CONTENTS(feq))
    END
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
