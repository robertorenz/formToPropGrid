!ABCIncludeFile(PROPGRID)
!=====================================================================
! PropGrid.inc - Clarion wrapper class for PROPGRID.DLL
!                (ClaPropGrid: Direct2D property grid)
!
! Multi-DLL:  where this class's CODE lives is decided by the two
!             project defines _PropGridLinkMode_ / _PropGridDllMode_,
!             which the ClaPropGrid templates generate through the ABC
!             class category 'PROPGRID'.  With neither define present
!             (a hand-coded project) LINK behaves as 1 and DLL as 0,
!             which is exactly the single-EXE behaviour.  Never EQUATE
!             them here - they must arrive as project defines.
!=====================================================================
  OMIT('_EndOfInclude_',_PropGridPresent_)
_PropGridPresent_  EQUATE(1)

!---- link/dll mode defaults ----------------------------------------
! Template-generated apps define _PropGridModesSet_ plus the two mode
! pragmas through the ABC 'PROPGRID' class category.  A hand-coded
! project that defines nothing gets safe single-EXE defaults here:
! the class code LINKs in and nothing is imported from a DLL.  With
! NO values at all the DLL() attribute is undefined and every virtual
! call dies with an access violation - so never remove this block.
  OMIT('_EndOfModes_',_PropGridModesSet_)
_PropGridLinkMode_ EQUATE(1)
_PropGridDllMode_  EQUATE(0)
  _EndOfModes_

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
PGT:ReadOnly    EQUATE(11)
PGT:Time        EQUATE(12)
PGT:MultiText   EQUATE(13)

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

!---- placement / docking modes (Reposition uses these) --------------
PGD:Region      EQUATE(0)   ! track the REGION control in RegionFeq
PGD:Fill        EQUATE(1)   ! fill the whole window client area
PGD:Left        EQUATE(2)   ! dock to the left edge, DockSize wide
PGD:Right       EQUATE(3)   ! dock to the right edge, DockSize wide
PGD:Fixed       EQUATE(4)   ! do not move on resize

!---- lookup registry (see PropGridClass.AddFileDrop) -----------------
! One entry per "lookup trio" (code ENTRY + '...' BUTTON + description
! STRING) that has been folded into a single PGT:Drop row.  Codes and
! Names are PARALLEL pipe-delimited lists: item n of Names is what the
! grid shows, item n of Codes is what gets written back to CodeFeq.
PropGridLookupQueue QUEUE,TYPE
Row                   SIGNED                  ! grid row id (also the SetTag row)
CodeFeq               SIGNED                  ! control holding the code   (hidden)
NameFeq               SIGNED                  ! control showing the name   (hidden, 0 = none)
Codes                 STRING(2048)            ! 'A|B|C'   - written back
Names                 STRING(4096)            ! 'Ape|Bee|Cat' - displayed
                    END

!---- tab registry (see PropGridClass.BuildFromWindow) ----------------
! One entry per TAB that has fed a row into the grid, or that
! SetTabCategory pre-registered.  CatId is lazy: the category header is
! only created when the first row actually lands under it, so a TAB
! whose every control is excluded never shows an empty header.
PropGridTabQueue  QUEUE,TYPE
TabFeq              SIGNED                  ! the TAB control
CatName             STRING(64)              ! '' = the TAB's own text
CatId               SIGNED                  ! 0 = not created yet
                  END

!---- category name registry (see PropGridClass.AddCategory) ----------
! AddCategory merges by name: asking twice for 'General' returns the
! SAME header, whichever source asked (default category, a tab, a
! lookup row, an added row, hand code).
PropGridCatQueue  QUEUE,TYPE
Name                STRING(64)
Id                  SIGNED
                  END

PropGridClass CLASS,TYPE,MODULE('PropGrid.clw'),LINK('PropGrid.clw',_PropGridLinkMode_),DLL(_PropGridDllMode_)
PG              LONG                          ! HPG handle (0 = dead)
Win             &WINDOW                       ! owning Clarion window
RegionFeq       SIGNED                        ! placeholder region (0 = fixed x/y)
DockMode        BYTE                          ! PGD:xxx - drives Reposition()
DockSize        SIGNED                        ! px width for PGD:Left / PGD:Right
MarginX         SIGNED                        ! px inset, left+right
MarginY         SIGNED                        ! px inset, top+bottom
Style           ULONG                         ! style passed to PG_Create
LiveSync        BYTE                          ! 1 = push edits to USE vars at once
HideOriginals   BYTE                          ! BuildFromWindow hides source ctrls
Initialized     BYTE
TimerInterval   SIGNED                        ! forced on the window (0 = leave alone)
MaxScanItems    SIGNED                        ! cap when enumerating a queue DROP
NextPrompt      SIGNED                        ! label feq feeding the next AddControl
PendingSyncFrom BYTE                          ! >0 = SyncFrom() in N more TakeEvent calls
TabCategories   BYTE                          ! 1 = each TAB's text becomes a category
Lookups         &PropGridLookupQueue,PRIVATE  ! AddFileDrop registry (NEW in Construct)
Tabs            &PropGridTabQueue,PRIVATE     ! per-tab registry    (NEW in Construct)
CatNames        &PropGridCatQueue,PRIVATE     ! category merge-by-name registry
Construct       PROCEDURE()
Destruct        PROCEDURE()
!-- lifetime --
Init            PROCEDURE(WINDOW W, SIGNED regionFeq, ULONG style=3),BYTE,PROC,VIRTUAL
InitXY          PROCEDURE(WINDOW W, SIGNED x, SIGNED y, SIGNED width, SIGNED height, ULONG style=3),BYTE,PROC,VIRTUAL
Kill            PROCEDURE(),VIRTUAL
SetDock         PROCEDURE(BYTE mode, SIGNED size=0, SIGNED marginX=0, SIGNED marginY=0)
SetPos          PROCEDURE(SIGNED x, SIGNED y, SIGNED width, SIGNED height)
Reposition      PROCEDURE(),VIRTUAL           ! re-track region / dock after resize
!-- appearance --
SetFont         PROCEDURE(SHORT part, STRING face, SHORT sizePt, BYTE bold=0, BYTE italic=0)
SetColor        PROCEDURE(SHORT slot, LONG color)
SetRowHeight    PROCEDURE(SHORT px)
SetSplitter     PROCEDURE(SHORT px)
!-- building --
ClearAll        PROCEDURE()
AddCategory     PROCEDURE(STRING catName),SIGNED,PROC
SetTabCategory  PROCEDURE(SIGNED tabFeq, STRING catName)  ! rename the TAB's category
TabCategoryOf   PROCEDURE(SIGNED feq),SIGNED,PROC ! category of the TAB holding feq (made on demand; 0 = none)
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
TrimTabs        PROCEDURE(),VIRTUAL           ! hide TABs the conversion emptied - call AFTER the lookups are folded
AddFileDrop     PROCEDURE(SIGNED category, STRING label, SIGNED codeFeq, SIGNED nameFeq, |
                          STRING codes, STRING names, <STRING description>),SIGNED,PROC,VIRTUAL
PipeSafe        PROCEDURE(STRING txt),STRING  ! CLIP+LEFT, and '|' in data -> '/'
SyncBack        PROCEDURE()                   ! all grid values -> USE vars
SyncRow         PROCEDURE(SIGNED row)         ! one grid value  -> USE var
SyncFrom        PROCEDURE()                   ! USE vars -> grid values
!-- event pump --
TakeEvent       PROCEDURE(),BYTE,PROC,VIRTUAL ! call from the ACCEPT loop / timer
TakeChanged     PROCEDURE(SIGNED row),VIRTUAL
TakeButton      PROCEDURE(SIGNED row),VIRTUAL
TakeSelect      PROCEDURE(SIGNED row),VIRTUAL
Redraw          PROCEDURE()
!-- internals (all assume SETTARGET(SELF.Win) is active) --
ControlLabel    PROCEDURE(SIGNED feq, SIGNED prevLabelFeq),STRING,PRIVATE
ControlPicture  PROCEDURE(SIGNED feq),STRING,PRIVATE
ChildLabels     PROCEDURE(SIGNED optFeq),STRING,PRIVATE
ChildLabelAt    PROCEDURE(SIGNED optFeq, SIGNED ordinal),STRING,PRIVATE
ChildOrdinal    PROCEDURE(SIGNED optFeq, STRING label),SIGNED,PRIVATE
ListChoices     PROCEDURE(SIGNED feq),STRING,PRIVATE
ListSelect      PROCEDURE(SIGNED feq, STRING val),BYTE,PROC,PRIVATE
WriteControl    PROCEDURE(SIGNED feq, STRING val),PRIVATE
PrevLabelFeq    PROCEDURE(SIGNED feq, SIGNED skipFeq),SIGNED,PRIVATE
SetNameControl  PROCEDURE(SIGNED feq, STRING txt),PRIVATE
IsExcluded      PROCEDURE(SIGNED feq, STRING excl),BYTE,PRIVATE  ! feq - or a container above it - in the list
OwnerTab        PROCEDURE(SIGNED feq),SIGNED,PRIVATE             ! nearest TAB ancestor (0 = none)
TabEntry        PROCEDURE(SIGNED tabFeq),PRIVATE                 ! fix SELF.Tabs on the entry, adding it if new
TabCategory     PROCEDURE(SIGNED tabFeq, SIGNED fallback),SIGNED,PRIVATE ! the TAB's category, created on demand
ContainerEmptied PROCEDURE(SIGNED feq),BYTE,PRIVATE              ! no visible control left inside
!-- pipe-delimited list helpers (used by the lookup rows and by ListChoices) --
PipeAppend      PROCEDURE(*STRING list, STRING value, SIGNED itemNo),PRIVATE
PipeItem        PROCEDURE(STRING list, SIGNED ordinal),STRING,PRIVATE
PipeFind        PROCEDURE(STRING list, STRING value),SIGNED,PRIVATE
FindLookup      PROCEDURE(SIGNED row),BYTE,PRIVATE  ! fixes SELF.Lookups on a hit
              END

  _EndOfInclude_
