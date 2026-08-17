!=====================================================================
! PropGrid.clw - implementation of PropGridClass (see PropGrid.inc)
!=====================================================================
  MEMBER

  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('PROPGRID.INC'),ONCE

  MAP
    MODULE('PROPGRID.DLL')
PG_Initialize      PROCEDURE(),SIGNED,PASCAL,NAME('PG_Initialize')
PG_Shutdown        PROCEDURE(),PASCAL,NAME('PG_Shutdown')
PG_Create          PROCEDURE(UNSIGNED hwndParent, SIGNED x, SIGNED y, SIGNED w, SIGNED h, ULONG style),LONG,PASCAL,NAME('PG_Create')
PG_Destroy         PROCEDURE(LONG pg),PASCAL,NAME('PG_Destroy')
PG_SetPos          PROCEDURE(LONG pg, SIGNED x, SIGNED y, SIGNED w, SIGNED h),PASCAL,NAME('PG_SetPos')
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
PG_GetValue        PROCEDURE(LONG pg, SIGNED row, *CSTRING buf, SIGNED bufLen),SIGNED,PASCAL,RAW,NAME('PG_GetValue')
PG_GetRowCount     PROCEDURE(LONG pg),SIGNED,PASCAL,NAME('PG_GetRowCount')
PG_FindRow         PROCEDURE(LONG pg, *CSTRING propName),SIGNED,PASCAL,RAW,NAME('PG_FindRow')
PG_GetSelected     PROCEDURE(LONG pg),SIGNED,PASCAL,NAME('PG_GetSelected')
PG_PollEvent       PROCEDURE(LONG pg, *SIGNED row, *SIGNED evType),SIGNED,PASCAL,RAW,NAME('PG_PollEvent')
PG_Redraw          PROCEDURE(LONG pg),PASCAL,NAME('PG_Redraw')
    END
  END

!---------------------------------------------------------------------
PropGridClass.Construct PROCEDURE()
  CODE
  SELF.PG            = 0
  SELF.RegionFeq     = 0
  SELF.LiveSync      = 0
  SELF.HideOriginals = 1
  SELF.Initialized   = 0

PropGridClass.Destruct PROCEDURE()
  CODE
  SELF.Kill()

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
  regionFeq{PROP:Hide} = TRUE
  SETTARGET()
  SELF.RegionFeq = regionFeq
  RETURN SELF.InitXY(W, x, y, wd, ht, style)

PropGridClass.InitXY PROCEDURE(WINDOW W, SIGNED x, SIGNED y, SIGNED width, SIGNED height, ULONG style=3)
  CODE
  IF SELF.PG THEN SELF.Kill().
  SELF.Win &= W
  PG_Initialize()
  SELF.PG = PG_Create(W{PROP:Handle}, x, y, width, height, style)
  IF ~SELF.PG THEN RETURN 0.
  IF W{PROP:Timer} = 0 THEN W{PROP:Timer} = 10.   ! event pump needs a timer
  SELF.Initialized = 1
  RETURN 1

PropGridClass.Kill PROCEDURE()
  CODE
  IF SELF.PG
    PG_Destroy(SELF.PG)
    SELF.PG = 0
  END
  SELF.Initialized = 0

PropGridClass.Reposition PROCEDURE()
x   SIGNED
y   SIGNED
wd  SIGNED
ht  SIGNED
sav BYTE
  CODE
  IF ~SELF.PG OR ~SELF.RegionFeq THEN RETURN.
  SETTARGET(SELF.Win)
  sav = 0{PROP:Pixels}
  0{PROP:Pixels} = TRUE
  x  = SELF.RegionFeq{PROP:XPos}
  y  = SELF.RegionFeq{PROP:YPos}
  wd = SELF.RegionFeq{PROP:Width}
  ht = SELF.RegionFeq{PROP:Height}
  0{PROP:Pixels} = sav
  SETTARGET()
  PG_SetPos(SELF.PG, x, y, wd, ht)

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
cVal  CSTRING(4096)
  CODE
  IF ~SELF.PG THEN RETURN 0.
  cName = CLIP(propName)
  cVal  = CLIP(value)
  RETURN PG_AddProperty(SELF.PG, category, cName, propType, cVal)

PropGridClass.SetChoices PROCEDURE(SIGNED row, STRING choices)
cCho CSTRING(4096)
  CODE
  IF ~SELF.PG THEN RETURN.
  cCho = CLIP(choices)
  PG_SetChoices(SELF.PG, row, cCho)

PropGridClass.SetRange PROCEDURE(SIGNED row, REAL low, REAL high, REAL step=1)
  CODE
  IF SELF.PG THEN PG_SetRange(SELF.PG, row, low, high, step).

PropGridClass.SetDescription PROCEDURE(SIGNED row, STRING txt)
cTxt CSTRING(2048)
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
PropGridClass.SetValue PROCEDURE(SIGNED row, STRING value)
cVal CSTRING(4096)
  CODE
  IF ~SELF.PG THEN RETURN.
  cVal = CLIP(value)
  PG_SetValue(SELF.PG, row, cVal)

PropGridClass.GetValue PROCEDURE(SIGNED row)
buf CSTRING(4096)
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
!---------------------------------------------------------------------
PropGridClass.AddControl PROCEDURE(SIGNED feq, SIGNED category=0)
ctype    LONG
row      SIGNED
lbl      STRING(256)
val      STRING(4096)
cho      STRING(4096)
pic      STRING(64)
ptype    SHORT
child    SIGNED
i        SIGNED
  CODE
  IF ~SELF.PG THEN RETURN 0.
  SETTARGET(SELF.Win)
  ctype = feq{PROP:Type}
  lbl   = SELF.ControlLabel(feq, SELF.NextPrompt)
  SELF.NextPrompt = 0
  ptype = 0
  cho   = ''
  val   = CONTENTS(feq)
  CASE ctype
  OF CREATE:entry
    pic = feq{PROP:Text}
    IF feq{PROP:Password}
      ptype = PGT:Password
    ELSIF UPPER(SUB(pic,1,2)) = '@D'
      ptype = PGT:Date
    ELSIF UPPER(SUB(pic,1,2)) = '@T'
      ptype = PGT:Time
    ELSE
      ptype = PGT:Text
    END
  OF CREATE:spin
    ptype = PGT:Spin
  OF CREATE:check
    ptype = PGT:Check
    val   = CHOOSE(feq{PROP:Checked} = TRUE, '1', '0')
  OF CREATE:option
    ptype = PGT:Radio
    ! collect radio-button children as choices
    i = 1
    LOOP
      child = feq{PROP:Child, i}
      IF ~child THEN BREAK.
      IF child{PROP:Type} = CREATE:radio
        cho = CLIP(cho) & CHOOSE(cho = '', '', '|') & CLIP(SELF.ControlLabel(child, 0))
      END
      i += 1
    END
    i = CHOICE(feq)
    IF i > 0 THEN val = SELF.ControlLabel(feq{PROP:Child, i}, 0).
  OF CREATE:droplist OROF CREATE:dropcombo OROF CREATE:list OROF CREATE:combo
    ptype = PGT:Drop
    cho   = feq{PROP:From}
  OF CREATE:text
    ptype = PGT:MultiText
  OF CREATE:button
    ptype = PGT:Button
    val   = ''
  OF CREATE:string OROF CREATE:sstring
    ptype = PGT:ReadOnly
    val   = feq{PROP:Text}
  ELSE
    SETTARGET()
    RETURN 0
  END
  SETTARGET()
  row = SELF.AddProperty(category, lbl, ptype, CLIP(val))
  IF ~row THEN RETURN 0.
  SELF.SetTag(row, feq)
  IF cho THEN SELF.SetChoices(row, CLIP(cho)).
  SETTARGET(SELF.Win)
  IF ctype = CREATE:spin
    SELF.SetRange(row, feq{PROP:RangeLow}, feq{PROP:RangeHigh}, CHOOSE(feq{PROP:Step} = 0, 1, feq{PROP:Step}))
  END
  IF feq{PROP:ReadOnly} OR feq{PROP:Disable} THEN SELF.SetReadOnly(row, 1).
  IF feq{PROP:Tip} THEN SELF.SetDescription(row, feq{PROP:Tip}).
  SETTARGET()
  RETURN row

!---------------------------------------------------------------------
! BuildFromWindow - walk every control on the window, convert the
! supported ones into grid rows, hide the originals (and their
! prompts).  excludeFeqs = pipe list of FEQs to leave alone.
!---------------------------------------------------------------------
PropGridClass.BuildFromWindow PROCEDURE(SIGNED category=0, <STRING excludeFeqs>)
feq        SIGNED
ctype      LONG
row        SIGNED
added      SIGNED
promptFeq  SIGNED
excl       STRING(1024)
  CODE
  IF ~SELF.PG THEN RETURN 0.
  excl  = CHOOSE(OMITTED(excludeFeqs), '', '|' & CLIP(excludeFeqs) & '|')
  added = 0
  promptFeq = 0
  SETTARGET(SELF.Win)
  LOOP feq = FIRSTFIELD() TO LASTFIELD()
    ctype = feq{PROP:Type}
    IF ~ctype THEN CYCLE.
    IF feq = SELF.RegionFeq THEN CYCLE.
    IF excl AND INSTRING('|' & feq & '|', excl, 1, 1) THEN CYCLE.
    IF feq{PROP:Hide} THEN CYCLE.
    CASE ctype
    OF CREATE:prompt
      promptFeq = feq
      CYCLE
    OF CREATE:radio OROF CREATE:sheet OROF CREATE:tab OROF CREATE:group |
         OROF CREATE:panel OROF CREATE:image OROF CREATE:line          |
         OROF CREATE:box OROF CREATE:ellipse OROF CREATE:region        |
         OROF CREATE:menu OROF CREATE:item OROF CREATE:progress
      CYCLE
    END
    SETTARGET()
    SELF.NextPrompt = promptFeq
    row = SELF.AddControl(feq, category)
    SETTARGET(SELF.Win)
    IF row
      added += 1
      IF SELF.HideOriginals
        feq{PROP:Hide} = TRUE
        IF promptFeq THEN promptFeq{PROP:Hide} = TRUE.
      END
    END
    promptFeq = 0
  END
  SETTARGET()
  SELF.Redraw()
  RETURN added

!---------------------------------------------------------------------
PropGridClass.ControlLabel PROCEDURE(SIGNED feq, SIGNED prevPromptFeq)
txt STRING(256)
p   SIGNED
  CODE
  ! assumes SETTARGET(SELF.Win) is active in the caller
  IF prevPromptFeq
    txt = prevPromptFeq{PROP:Text}
  ELSE
    txt = feq{PROP:Text}
    CASE feq{PROP:Type}
    OF CREATE:entry OROF CREATE:spin OROF CREATE:text |
         OROF CREATE:droplist OROF CREATE:dropcombo   |
         OROF CREATE:list OROF CREATE:combo
      ! PROP:Text is the picture for these - derive from USE label
      txt = feq{PROP:Use}
      IF SUB(txt,1,1) = '?' THEN txt = SUB(txt, 2, SIZE(txt) - 1).
      p = INSTRING(':', txt, 1, 1)          ! strip 'PRE:' prefix
      IF p THEN txt = SUB(txt, p + 1, SIZE(txt) - p).
    END
  END
  ! strip accelerator '&' and trailing ':'
  LOOP
    p = INSTRING('&', txt, 1, 1)
    IF ~p THEN BREAK.
    txt = SUB(txt, 1, p - 1) & SUB(txt, p + 1, SIZE(txt) - p)
  END
  txt = CLIP(LEFT(txt))
  IF txt AND SUB(txt, LEN(CLIP(txt)), 1) = ':'
    txt = SUB(txt, 1, LEN(CLIP(txt)) - 1)
  END
  IF ~txt THEN txt = 'Field ' & feq.
  RETURN CLIP(txt)

!---------------------------------------------------------------------
! SyncRow - copy one grid value back into the source control/USE var
!---------------------------------------------------------------------
PropGridClass.SyncRow PROCEDURE(SIGNED row)
feq   SIGNED
val   STRING(4096)
cho   STRING(4096)
ctype LONG
pic   STRING(64)
i     SIGNED
n     SIGNED
child SIGNED
  CODE
  feq = SELF.GetTag(row)
  IF ~feq THEN RETURN.
  val = SELF.GetValue(row)
  SETTARGET(SELF.Win)
  ctype = feq{PROP:Type}
  CASE ctype
  OF CREATE:check
    CHANGE(feq, CHOOSE(val = '1', 1, 0))
  OF CREATE:option
    ! match the choice text against the radio children -> ordinal
    n = 0
    i = 1
    LOOP
      child = feq{PROP:Child, i}
      IF ~child THEN BREAK.
      IF child{PROP:Type} = CREATE:radio
        n += 1
        IF CLIP(SELF.ControlLabel(child, 0)) = CLIP(val)
          feq{PROP:Selected} = n
          BREAK
        END
      END
      i += 1
    END
  OF CREATE:entry OROF CREATE:spin
    pic = feq{PROP:Text}
    IF UPPER(SUB(pic,1,1)) = '@' AND INSTRING(UPPER(SUB(pic,2,1)), 'DTN', 1, 1)
      CHANGE(feq, DEFORMAT(CLIP(val), pic))
    ELSE
      CHANGE(feq, CLIP(val))
    END
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
  CODE
  cnt = SELF.RowCount()
  SETTARGET(SELF.Win)
  LOOP i = 1 TO cnt
    feq = SELF.GetTag(i)
    IF ~feq THEN CYCLE.
    CASE feq{PROP:Type}
    OF CREATE:check
      val = CHOOSE(feq{PROP:Checked} = TRUE, '1', '0')
    OF CREATE:option
      val = SELF.ControlLabel(feq{PROP:Child, CHOICE(feq)}, 0)
    ELSE
      val = CONTENTS(feq)
    END
    SETTARGET()
    SELF.SetValue(i, CLIP(val))
    SETTARGET(SELF.Win)
  END
  SETTARGET()
  SELF.Redraw()

!---------------------------------------------------------------------
PropGridClass.TakeEvent PROCEDURE()
row     SIGNED
evt     SIGNED
handled BYTE
  CODE
  IF ~SELF.PG THEN RETURN 0.
  handled = 0
  LOOP WHILE PG_PollEvent(SELF.PG, row, evt)
    handled = 1
    CASE evt
    OF PGE:Changed  ; SELF.TakeChanged(row)
    OF PGE:Button   ; SELF.TakeButton(row)
    OF PGE:Select   ; SELF.TakeSelect(row)
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

PropGridClass.Redraw PROCEDURE()
  CODE
  IF SELF.PG THEN PG_Redraw(SELF.PG).
