!ABCIncludeFile
!=====================================================================
! PropGrid.inc - Clarion wrapper class for PROPGRID.DLL
!                (ClaPropGrid: Direct2D property grid)
!=====================================================================
  OMIT('_EndOfInclude_',_PropGridPresent_)
_PropGridPresent_  EQUATE(1)

!---- editor types (match PGT_* in propgrid.h) -----------------------
PGT:Text        EQUATE(1)
PGT:Password    EQUATE(2)
PGT:Drop        EQUATE(3)
PGT:Check       EQUATE(4)
PGT:Radio       EQUATE(5)
PGT:Slider      EQUATE(6)
PGT:Spin        EQUATE(7)
PGT:Button      EQUATE(8)
PGT:Color       EQUATE(9)
PGT:Date        EQUATE(10)
PGT:Time        EQUATE(12)
PGT:MultiText   EQUATE(13)
PGT:ReadOnly    EQUATE(11)

!---- event types ----------------------------------------------------
PGE:Changed     EQUATE(1)
PGE:Button      EQUATE(2)
PGE:Select      EQUATE(3)
PGE:DblClick    EQUATE(4)

!---- create styles --------------------------------------------------
PGS:Border      EQUATE(0001h)
PGS:Description EQUATE(0002h)
PGS:ToolboxLook EQUATE(0004h)
PGS:Sort        EQUATE(0008h)

!---- font parts -----------------------------------------------------
PGF:Name        EQUATE(1)
PGF:Value       EQUATE(2)
PGF:Category    EQUATE(3)
PGF:Desc        EQUATE(4)

!---- color slots ----------------------------------------------------
PGC:Back        EQUATE(1)
PGC:NameBack    EQUATE(2)
PGC:NameText    EQUATE(3)
PGC:ValueText   EQUATE(4)
PGC:CatBack     EQUATE(5)
PGC:CatText     EQUATE(6)
PGC:Lines       EQUATE(7)
PGC:SelBack     EQUATE(8)
PGC:SelText     EQUATE(9)
PGC:DescBack    EQUATE(10)
PGC:DescText    EQUATE(11)

PropGridClass CLASS,TYPE,MODULE('PropGrid.clw'),LINK('PropGrid.clw',_PropGridLinkMode_),DLL(_PropGridDllMode_)
PG              LONG                          ! HPG handle (0 = dead)
Win             &WINDOW                       ! owning Clarion window
RegionFeq       SIGNED                        ! placeholder region (0 = fixed x/y)
LiveSync        BYTE                          ! 1 = push edits to USE vars at once
HideOriginals   BYTE                          ! BuildFromWindow hides source ctrls
Initialized     BYTE
NextPrompt      SIGNED                        ! prompt feq feeding the next AddControl label
Construct       PROCEDURE()
Destruct        PROCEDURE()
!-- lifetime --
Init            PROCEDURE(WINDOW W, SIGNED regionFeq, ULONG style=3),BYTE,PROC,VIRTUAL
InitXY          PROCEDURE(WINDOW W, SIGNED x, SIGNED y, SIGNED width, SIGNED height, ULONG style=3),BYTE,PROC,VIRTUAL
Kill            PROCEDURE(),VIRTUAL
Reposition      PROCEDURE()                   ! re-track region after resize
!-- appearance --
SetFont         PROCEDURE(SHORT part, STRING face, SHORT sizePt, BYTE bold=0, BYTE italic=0)
SetColor        PROCEDURE(SHORT slot, LONG color)
SetRowHeight    PROCEDURE(SHORT px)
SetSplitter     PROCEDURE(SHORT px)
!-- building --
ClearAll        PROCEDURE()
AddCategory     PROCEDURE(STRING catName),SIGNED,PROC
AddProperty     PROCEDURE(SIGNED category, STRING propName, SHORT propType, STRING value),SIGNED,PROC
SetChoices      PROCEDURE(SIGNED row, STRING choices)
SetRange        PROCEDURE(SIGNED row, REAL low, REAL high, REAL step=1)
SetDescription  PROCEDURE(SIGNED row, STRING txt)
SetReadOnly     PROCEDURE(SIGNED row, BYTE readOnly=1)
SetExpanded     PROCEDURE(SIGNED category, BYTE expanded=1)
SetTag          PROCEDURE(SIGNED row, LONG tag)
GetTag          PROCEDURE(SIGNED row),LONG
!-- values --
SetValue        PROCEDURE(SIGNED row, STRING value)
GetValue        PROCEDURE(SIGNED row),STRING
FindRow         PROCEDURE(STRING propName),SIGNED
GetSelected     PROCEDURE(),SIGNED
RowCount        PROCEDURE(),SIGNED
!-- form conversion (runtime reflection) --
AddControl      PROCEDURE(SIGNED feq, SIGNED category=0),SIGNED,PROC,VIRTUAL
BuildFromWindow PROCEDURE(SIGNED category=0, <STRING excludeFeqs>),SIGNED,PROC,VIRTUAL
SyncBack        PROCEDURE()                   ! all grid values -> USE vars
SyncRow         PROCEDURE(SIGNED row)         ! one grid value  -> USE var
SyncFrom        PROCEDURE()                   ! USE vars -> grid values
!-- event pump --
TakeEvent       PROCEDURE(),BYTE,PROC,VIRTUAL ! call from ACCEPT loop
TakeChanged     PROCEDURE(SIGNED row),VIRTUAL
TakeButton      PROCEDURE(SIGNED row),VIRTUAL
TakeSelect      PROCEDURE(SIGNED row),VIRTUAL
Redraw          PROCEDURE()
!-- internals --
ControlLabel    PROCEDURE(SIGNED feq, SIGNED prevPromptFeq),STRING,PRIVATE
              END

  _EndOfInclude_
