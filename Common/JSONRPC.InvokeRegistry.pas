unit JSONRPC.InvokeRegistry;

interface

uses
  {$IFDEF POSIX}Posix.SysTypes,{$ENDIF}
  System.SysUtils, System.TypInfo, System.Classes, System.Generics.Collections,
  System.SyncObjs,
  Soap.IntfInfo,
  JSONRPC.Common.Types;

type

  InvString = UnicodeString;
  TDataContext = class;

  { TRemotable is the base class for remoting complex types - it introduces a virtual
    constructor (to allow the JSON RPC runtime to properly create the object and derived
    types) and it provides life-time management - via DataContext - so the JSON RPC
    runtime can properly disposed of complex types received by a Service }
{$M+}
  TRemotable = class
  private
    FDataContext: TDataContext;
    procedure SetDataContext(Value: TDataContext);
  public
    constructor Create; virtual;
    destructor  Destroy; override;

    property   DataContext: TDataContext read FDataContext write SetDataContext;
  end;
{$M-}

  PTRemotable = ^TRemotable;
  TRemotableClass = class of TRemotable;

  TInvokableClass = class(TInterfacedObject, IInterface, IJSONRPCMethodException)
  protected
    FMessage: string;
    FCode: Integer;
    FMethodName: string;
{$IFNDEF AUTOREFCOUNT}
    FRefCount: Integer;
{$ENDIF !AUTOREFCOUNT}
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
{$IFNDEF AUTOREFCOUNT}
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
{$ENDIF !AUTOREFCOUNT}
  public
    constructor Create; virtual;
{$IFNDEF AUTOREFCOUNT}
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    class function NewInstance: TObject; override;
    property RefCount: Integer read FRefCount;
{$ENDIF !AUTOREFCOUNT}

    function SafeCallException(ExceptObject: TObject;
      ExceptAddr: Pointer): HResult; override;

    { IJSONRPCException }
    function GetCode: Integer;
    procedure SetCode(ACode: Integer);
    property Code: Integer read GetCode write SetCode;

    function GetMessage: string;
    procedure SetMessage(const AMsg: string);
    property Message: string read GetMessage write SetMessage;


    { IJSONRPCException }
    function GetMethodName: string;
    procedure SetMethodName(const AMethodName: string);

    {$WARN HIDING_MEMBER OFF}
    property MethodName: string read GetMethodName write SetMethodName;
    {$WARN HIDING_MEMBER ON}
  end;
  TInvokableClassClass = class of TInvokableClass;

  { Used when registering a class factory  - Specify a factory callback
    if you need to control the lifetime of the object - otherwise JSON RPC
    will create the implementation class using the virtual constructor }
  TCreateInstanceProc = procedure(out obj: TObject);

  InvRegClassEntry = record
    ClassType: TClass;
    Proc: TCreateInstanceProc;
  end;

  eHeaderMethodType = (hmtAll, hmtRequest, hmtResponse);

  THeaderMethodTypeArray = TArray<eHeaderMethodType>;

  TRequiredArray = TArray<Boolean>;

  IntfExceptionItem = record
    ClassType: TClass;
    MethodNames: string;
  end;

  TExceptionItemArray = TArray<IntfExceptionItem>;

  InterfaceMapItem = record
    Name: string;                             { Native name of interface    }
    ExtName: InvString;                       { PortTypeName                }
    UnitName: string;                         { Filename of interface       }
    GUID: TGUID;                              { GUID of interface           }
    Info: PTypeInfo;                          { Typeinfo of interface       }
    DefImpl: TClass;                          { Metaclass of implementation }
{$IFDEF WIDE_RETURN_NAMES}
    ReturnParamNames: InvString;              { Return Parameter names      }
{$ELSE}
    ReturnParamNames: string;                 { Return Parameter names      }
{$ENDIF}
  end;

  TInterfaceMapItemArray = TArray<InterfaceMapItem>;

  TInvokableClassRegistry = class
  protected
    FCriticalSection: TCriticalSection;
    FRegIntfs: TArray<InterfaceMapItem>;
    FRegClasses: TArray<InvRegClassEntry>;

    procedure DeleteFromReg(AClass: TClass; Info: PTypeInfo);
  public
    constructor Create;
    destructor Destroy; override;

    { Basic Invokable Interface Registration Routine }
    procedure RegisterInterface(Info: PTypeInfo);

    function GetInvokableClass: TClass;
    function GetInterface: InterfaceMapItem;

    procedure RegisterInvokableClass(AClass: TClass; const CreateProc: TCreateInstanceProc); overload;
    procedure RegisterInvokableClass(AClass: TClass); overload;

    procedure RegisterReturnParamNames(Info: PTypeInfo; const RetParamNames: InvString);

  private
    procedure Lock; virtual;
    procedure UnLock; virtual;
    function  GetIntfIndex(const IntfInfo: PTypeInfo): Integer;
  public

    procedure GetInterfaceInfoFromName(const UnitName,  IntfName: string; var Info: PTypeInfo; var IID: TGUID);
    function  GetInterfaceTypeInfo(const AGUID: TGUID): Pointer;
    function  GetInvokableObjectFromClass(AClass: TClass): TObject;
    function  GetRegInterfaceEntry(Index: Integer): InterfaceMapItem;
    function  HasRegInterfaceImpl(Index: Integer): Boolean;
    procedure GetClassFromIntfInfo(Info: PTypeInfo; var AClass: TClass);
    function  GetInterfaceCount: Integer;

    procedure UnRegisterInterface(Info: PTypeInfo);
    procedure UnRegisterInvokableClass(AClass: TClass);
  end;

  ETypeRegistryException = class(Exception);

  TRemotableTypeRegistry = class
  private
    FAutoRegister: Boolean;
    FCriticalSection: TCriticalSection;
  protected
    procedure Lock; virtual;
    procedure UnLock; virtual;
  public
    constructor Create;
    destructor Destroy; override;

    { Flag to automatically register types }
    property AutoRegisterNativeTypes: Boolean read FAutoRegister write FAutoRegister;
  end;

  TRemotableClassRegistry       = TRemotableTypeRegistry;
  
{ Forward ref. structure to satisfy DynamicArray<Type>        }
{ encountered before declaration of Type itself in .HPP file  }

  TDynToClear = record
    P: Pointer;
    Info: PTypeInfo;
  end;

  TDataContext = class
  protected
    FObjsToDestroy: TArray<TObject>;
    DataOffset: Integer;
    Data: TArray<Byte>;
    DataP: TArray<Pointer>;
    VarToClear: TArray<Pointer>;
    DynArrayToClear: TArray<TDynToClear>;
{$IFNDEF NEXTGEN}
    StrToClear: TArray<Pointer>;
    WStrToClear: TArray<Pointer>;
{$ENDIF !NEXTGEN}
{$IFDEF UNICODE}
    UStrToClear: TArray<Pointer>;
{$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;
    function  AllocData(Size: Integer): Pointer;
    procedure SetDataPointer(Index: Integer; P: Pointer);
    function  GetDataPointer(Index: Integer): Pointer;
    procedure AddObjectToDestroy(Obj: TObject);
    procedure RemoveObjectToDestroy(Obj: TObject);
    procedure AddDynArrayToClear(P: Pointer; Info: PTypeInfo);
    procedure AddVariantToClear(P: PVarData);
{$IFNDEF NEXTGEN}
    procedure AddStrToClear(P: Pointer);
    procedure AddWStrToClear(P: Pointer);
{$ENDIF !NEXTGEN}
{$IFDEF UNICODE}
    procedure AddUStrToClear(P: Pointer);
{$ENDIF}
  end;

  TInvContext = class(TDataContext)
  protected
    ResultP: Pointer;
  public
    procedure SetMethodInfo(const MD: TIntfMethEntry);
    procedure SetParamPointer(Param: Integer; P: Pointer);
    function  GetParamPointer(Param: Integer): Pointer;
    function  GetResultPointer: Pointer;
    procedure SetResultPointer(P: Pointer);
    procedure AllocServerData(const MD: TIntfMethEntry);
  end;

function  GetRemotableDataContext: Pointer;
procedure SetRemotableDataContext(Value: Pointer);

function  InvRegistry:   TInvokableClassRegistry;

implementation

uses
  {$IFDEF MSWINDOWS}Winapi.Windows,{$ENDIF}
  {$IFDEF POSIX}Posix.Unistd,{$ENDIF}
  System.RTTI, System.Types, System.Variants,
  Soap.HTTPUtil, Soap.SOAPConst, Soap.XSBuiltIns, JSONRPC.RIO;

var
  JSONRPCInvRegistryV: TInvokableClassRegistry;

threadvar
  RemotableDataContext: Pointer;

function GetRemotableDataContext: Pointer;
begin
  Result := RemotableDataContext;
end;

procedure SetRemotableDataContext(Value: Pointer);
begin
  RemotableDataContext := Value;
end;

function TInvokableClassRegistry.GetInterfaceCount: Integer;
begin
  Result := 0;
  if FRegIntfs <> nil then
    Result := Length(FRegIntfs);
end;

function TInvokableClassRegistry.GetRegInterfaceEntry(Index: Integer): InterfaceMapItem;
begin
  if Index < Length(FRegIntfs) then
    Result := FRegIntfs[Index];
end;

function TInvokableClassRegistry.HasRegInterfaceImpl(Index: Integer): Boolean;
begin
  if Index < Length(FRegIntfs) then
    Result := FRegIntfs[Index].DefImpl <> nil
  else
    Result := False;
end;


constructor TInvokableClassRegistry.Create;
begin
  inherited Create;
  FCriticalSection := TCriticalSection.Create;
end;

destructor TInvokableClassRegistry.Destroy;
begin
  FreeAndNil(FCriticalSection);
  inherited Destroy;
end;

procedure TInvokableClassRegistry.Lock;
begin
  FCriticalSection.Enter;
end;

procedure TInvokableClassRegistry.UnLock;
begin
  FCriticalSection.Leave;
end;

procedure TInvokableClassRegistry.RegisterInvokableClass(AClass: TClass);
var
  LContext: TRttiContext;
  LType: TRttiType;
  LInstanceType: TRttiInstanceType absolute LType;
begin
  LContext := TRttiContext.Create;
  LType := LContext.GetType(AClass);
  if LType <> nil then
    begin
      if LType is TRttiInstanceType then
        begin
          var LIntfs := LInstanceType.GetImplementedInterfaces;
          RegisterInterface(LIntfs[0].Handle);
        end;
    end;
  RegisterInvokableClass(AClass, nil);
end;

function TInvokableClassRegistry.GetInvokableClass: TClass;
begin
  if Length(FRegClasses) > 0 then
    Result := FRegClasses[0].ClassType else
    Result := nil;
end;

function TInvokableClassRegistry.GetInterface: InterfaceMapItem;
begin
  if Length(FRegIntfs) > 0 then
    Result := FRegIntfs[0] else
    Result := Default(InterfaceMapItem);
end;

procedure TInvokableClassRegistry.RegisterInvokableClass(AClass: TClass;
  const CreateProc: TCreateInstanceProc);
var
  Index, I, J: Integer;
  Table: PInterfaceTable;
begin
  Lock;
  try
    Table := AClass.GetInterfaceTable;
    { If a class does not implement interfaces, we'll try its parent }
    if Table = nil then
    begin
      if (AClass.ClassParent <> nil) then
      begin
        Table := AClass.ClassParent.GetInterfaceTable;
        {
        if Table <> nil then
          AClass := AClass.ClassParent;
        }
      end;
    end;
    if Table = nil then
      raise ETypeRegistryException.CreateFmt(SNoInterfacesInClass, [AClass.ClassName]);
    Index := Length(FRegClasses);
    SetLength(FRegClasses, Index + 1);
    FRegClasses[Index].ClassType := AClass;
    FRegClasses[Index].Proc := CreateProc;

    { Find out what Registered invokable interface this class implements }
    for I := 0 to Table.EntryCount - 1 do
    begin
      for J := 0 to Length(FRegIntfs) - 1 do
        if IsEqualGUID(FRegIntfs[J].GUID, Table.Entries[I].IID) then
          { NOTE: Don't replace an existing implementation           }
          {       This approach allows for better control over what  }
          {       class implements a particular interface            }
          if FRegIntfs[J].DefImpl = nil then
            FRegIntfs[J].DefImpl := AClass;
    end;
  finally
    UnLock;
  end;
end;

procedure TInvokableClassRegistry.DeleteFromReg(AClass: TClass; Info: PTypeInfo);
var
  I, Index, ArrayLen: Integer;
begin
  Lock;
  try
    Index := -1;
    if Assigned(Info) then
      ArrayLen := Length(FRegIntfs)
    else
      ArrayLen := Length(FRegClasses);
    for I := 0 to ArrayLen - 1 do
      begin
        if (Assigned(Info) and (FRegIntfs[I].Info = Info)) or
          (Assigned(AClass) and (FRegClasses[I].ClassType = AClass)) then
          begin
            Index := I;
            Break;
          end;
      end;
    if Index <> -1 then
      begin
        if Assigned(Info) then
          begin
            for I := Index to ArrayLen - 2 do
              FRegIntfs[I] := FRegIntfs[I+1];
            SetLength(FRegIntfs, Length(FRegIntfs) -1);
          end else
          begin
            for I := Index to ArrayLen - 2 do
              FRegClasses[I] := FRegClasses[I+1];
            SetLength(FRegClasses, Length(FRegClasses) -1);
          end;
      end;
  finally
    UnLock;
  end;
end;

procedure TInvokableClassRegistry.UnRegisterInvokableClass(AClass: TClass);
var
  I: Integer;
begin
  { Remove class from any interfaces it was registered as default class }
  for I := 0 to Length(FRegIntfs) - 1 do
    if FRegIntfs[I].DefImpl = AClass then
      FRegIntfs[I].DefImpl := nil;

  DeleteFromReg(AClass, nil);
end;

procedure TInvokableClassRegistry.RegisterInterface(Info: PTypeInfo);
var
  Index: Integer;
  IntfMD: TIntfMetaData;
  I, J: Integer;
  Table: PInterfaceTable;
begin
  Lock;
  try
    for I := 0 to Length(FRegIntfs) - 1 do
      if FRegIntfs[I].Info = Info then
        Exit;

    GetIntfMetaData(Info, IntfMD, True);

    Index := Length(FRegIntfs);
    SetLength(FRegIntfs, Index + 1);
    FRegIntfs[Index].GUID := IntfMD.IID;
    FRegIntfs[Index].Info := Info;
    FRegIntfs[Index].Name := IntfMD.Name;
    FRegIntfs[Index].UnitName := IntfMD.UnitName;

    if FRegIntfs[Index].DefImpl = nil then
      begin
        { NOTE: First class that implements this interface wins!! }
        for I := 0 to Length(FRegClasses) - 1 do
          begin
            { Allow for a class whose parent implements interfaces }
            Table :=  FRegClasses[I].ClassType.GetInterfaceTable;
            if (Table = nil) then
              begin
                Table := FRegClasses[I].ClassType.ClassParent.GetInterfaceTable;
              end;
            for J := 0 to Table.EntryCount - 1 do
              begin
                if IsEqualGUID(IntfMD.IID, Table.Entries[J].IID) then
                  begin
                    FRegIntfs[Index].DefImpl := FRegClasses[I].ClassType;
                    Exit;
                  end;
              end;
          end;
      end;
  finally
    Unlock;
  end;
end;

procedure TInvokableClassRegistry.RegisterReturnParamNames(Info: PTypeInfo; const RetParamNames: InvString);
var
  I: Integer;
begin
  Lock;
  try
    I := GetIntfIndex(Info);
    if I >= 0 then
      begin
        FRegIntfs[I].ReturnParamNames := RetParamNames;
      end;
  finally
    Unlock;
  end;
end;

{ calls to this method need to be within a Lock/try <here> finally/unlock block }
function TInvokableClassRegistry.GetIntfIndex(const IntfInfo: PTypeInfo): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Length(FRegIntfs)-1 do
    begin
      if IntfInfo = FRegIntfs[I].Info then
        begin
          Exit(I);
        end;
    end;
end;

procedure TInvokableClassRegistry.UnRegisterInterface(Info: PTypeInfo);
begin
  DeleteFromReg(nil, Info);
end;

function TInvokableClassRegistry.GetInterfaceTypeInfo(const AGUID: TGUID): Pointer;
var
  I: Integer;
begin
  Result := nil;
  Lock;
  try
    for I := 0 to Length(FRegIntfs) - 1 do
    begin
      if IsEqualGUID(AGUID, FRegIntfs[I].GUID) then
      begin
        Result := FRegIntfs[I].Info;
        Exit;
      end;
    end;
  finally
    UnLock;
  end;
end;

procedure TInvokableClassRegistry.GetInterfaceInfoFromName(
  const UnitName, IntfName: string; var Info: PTypeInfo; var IID: TGUID);
var
  I: Integer;
begin
  Info := nil;
  Lock;
  try
    for I := 0 to Length(FRegIntfs) - 1 do
      begin
        if SameText(IntfName, FRegIntfs[I].Name) and
          ((UnitName = '') or (SameText(UnitName, FRegIntfs[I].UnitName))) then
          begin
            Info := FRegIntfs[I].Info;
            IID := FRegIntfs[I].GUID;
          end;
      end;
  finally
    UnLock;
  end;
end;

function TInvokableClassRegistry.GetInvokableObjectFromClass(
  AClass: TClass): TObject;
var
  I: Integer;
  Found: Boolean;
begin
  Result := nil;
  Lock;
  Found := False;
  try
    for I := 0 to Length(FRegClasses) - 1 do
      if FRegClasses[I].ClassType = AClass then
        if Assigned(FRegClasses[I].Proc) then
          begin
            FRegClasses[I].Proc(Result);
            Found := True;
          end;
    if not Found and  AClass.InheritsFrom(TInvokableClass) then
      Result := TInvokableClassClass(AClass).Create;
  finally
    UnLock;
  end;
end;

procedure TInvokableClassRegistry.GetClassFromIntfInfo(Info: PTypeInfo;
  var AClass: TClass);
var
  I: Integer;
begin
  AClass := nil;
  Lock;
  try
    for I := 0 to Length(FRegIntfs) - 1 do
      if FRegIntfs[I].Info = Info then
        begin
          AClass := FRegIntfs[I].DefImpl;
          Break;
        end;
  finally
    UnLock;
  end;
end;

{ TInvokableClass }

constructor TInvokableClass.Create;
begin
  inherited Create;
end;

{$IFNDEF AUTOREFCOUNT}
procedure TInvokableClass.AfterConstruction;
begin
  { Release the constructor's implicit refcount }
  TInterlocked.Decrement(FRefCount);
end;

procedure TInvokableClass.BeforeDestruction;
begin
  if RefCount <> 0 then
    System.Error(reInvalidPtr);
end;
{$ENDIF !AUTOREFCOUNT}

{ Set an implicit refcount so that refcounting  }
{ during construction won't destroy the object. }
{$IFNDEF AUTOREFCOUNT}
class function TInvokableClass.NewInstance: TObject;
begin
  Result := inherited NewInstance;
  TInvokableClass(Result).FRefCount := 1;
end;
{$ENDIF !AUTOREFCOUNT}

function TInvokableClass.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

{$IFNDEF AUTOREFCOUNT}
function TInvokableClass._AddRef: Integer;
begin
  Result := TInterlocked.Increment(FRefCount);
end;

function TInvokableClass._Release: Integer;
begin
  Result := TInterlocked.Decrement(FRefCount);
  if Result = 0 then
    Destroy;
end;
{$ENDIF !AUTOREFCOUNT}

function TInvokableClass.SafeCallException(ExceptObject: TObject;
  ExceptAddr: Pointer): HResult;
var
  L0: Exception absolute ExceptObject;
  L1: EJSONRPCException absolute ExceptObject;
  L2: EJSONRPCMethodException absolute ExceptObject;
begin
  FCode := 0;
  FMessage := '';
  FMethodName := '';
  if ExceptObject is EJSONRPCException then
    begin
      FCode := L1.Code;
      FMessage := L1.Message;
    end;
  if ExceptObject is EJSONRPCMethodException then
    begin
      FMethodName := L2.MethodName;
    end;
  if ExceptObject is Exception then
    begin
      FMessage := L0.Message;
    end;
  Result := E_UNEXPECTED;
end;

function TInvokableClass.GetCode: Integer;
begin
  Result := FCode;
end;

procedure TInvokableClass.SetCode(ACode: Integer);
begin
  FCode := ACode;
end;

function TInvokableClass.GetMessage: string;
begin
  Result := FMessage;
end;

procedure TInvokableClass.SetMessage(const AMsg: string);
begin
  FMessage := AMsg;
end;

function TInvokableClass.GetMethodName: string;
begin
  Result := FMethodName;
end;

procedure TInvokableClass.SetMethodName(const AMethodName: string);
begin
  FMethodName := AMethodName;
end;

{ TRemotable }

constructor TRemotable.Create;
begin
  inherited;
  if RemotableDataContext <> nil then
  begin
    TDataContext(RemotableDataContext).AddObjectToDestroy(Self);
    Self.DataContext := TDataContext(RemotableDataContext);
  end;
end;

destructor TRemotable.Destroy;
begin
  if RemotableDataContext <> nil then
  begin
    TDataContext(RemotableDataContext).RemoveObjectToDestroy(Self);
    Self.DataContext := nil;
  end;
  inherited Destroy;
end;

procedure TRemotable.SetDataContext(Value: TDataContext);
begin
  if (RemotableDataContext <> nil) and (RemotableDataContext = Self.DataContext) then
  begin
    TDataContext(RemotableDataContext).RemoveObjectToDestroy(Self);
  end;
  FDataContext := Value;
end;

constructor TRemotableTypeRegistry.Create;
begin
  inherited Create;
  FAutoRegister := True;
  FCriticalSection := TCriticalSection.Create;
end;

destructor TRemotableTypeRegistry.Destroy;
begin
  FreeAndNil(FCriticalSection);
  inherited Destroy;
end;

procedure TRemotableTypeRegistry.Lock;
begin
  FCriticalSection.Enter;
end;

procedure TRemotableTypeRegistry.UnLock;
begin
  FCriticalSection.Leave;
end;

{ TDataContext }

procedure TDataContext.SetDataPointer(Index: Integer; P: Pointer);
begin
  DataP[Index] := P;
end;

function TDataContext.GetDataPointer(Index: Integer): Pointer;
begin
  Result := DataP[Index];
end;

procedure TDataContext.AddVariantToClear(P: PVarData);
var
  I: Integer;
begin
  for I := 0 to Length(VarToClear) -1 do
    if VarToClear[I] = P then
      Exit;
  I := Length(VarToClear);
  SetLength(VarToClear, I + 1);
  VarToClear[I] := P;
end;

{$IFNDEF NEXTGEN}
procedure TDataContext.AddStrToClear(P: Pointer);
var
  I: Integer;
begin
  { If this string is in the list already, we're set }
  for I := 0 to Length(StrToClear) -1 do
    if StrToClear[I] = P then
      Exit;
  I := Length(StrToClear);
  SetLength(StrToClear, I + 1);
  StrToClear[I] := P;
end;

procedure TDataContext.AddWStrToClear(P: Pointer);
var
  I: Integer;
begin
  { If this WideString is in the list already, we're set }
  for I := 0 to Length(WStrToClear) -1 do
    if WStrToClear[I] = P then
      Exit;
  I := Length(WStrToClear);
  SetLength(WStrToClear, I + 1);
  WStrToClear[I] := P;
end;
{$ENDIF !NEXTGEN}

{$IFDEF UNICODE}
procedure TDataContext.AddUStrToClear(P: Pointer);
var
  I: Integer;
begin
  { If this UnicodeString is in the list already, we're set }
  for I := 0 to Length(UStrToClear) -1 do
    if UStrToClear[I] = P then
      Exit;
  I := Length(UStrToClear);
  SetLength(UStrToClear, I + 1);
  UStrToClear[I] := P;
end;
{$ENDIF}

constructor TDataContext.Create;
begin
  inherited;
end;

destructor TDataContext.Destroy;
var
  I: Integer;
  P: Pointer;
begin
  { Clean up objects we've allocated }
  for I := 0 to Length(FObjsToDestroy) - 1 do
  begin
     if (FObjsToDestroy[I] <> nil) and (FObjsToDestroy[I].InheritsFrom(TRemotable)) then
     begin
       TRemotable(FObjsToDestroy[I]).Free;
     end;
  end;
  SetLength(FObjsToDestroy, 0);

  { Clean Variants we allocated }
  for I := 0 to Length(VarToClear) - 1 do
  begin
    if Assigned(VarToClear[I]) then
      Variant( PVarData(VarToClear[I])^) := NULL;
  end;
  SetLength(VarToClear, 0);

  { Clean up dynamic arrays we allocated }
  for I := 0 to Length(DynArrayToClear) - 1 do
  begin
    if Assigned(DynArrayToClear[I].P) then
    begin
      P := PPointer(DynArrayToClear[I].P)^;
      DynArrayClear(P, DynArrayToClear[I].Info)
    end;
  end;
  SetLength(DynArrayToClear, 0);

{$IFNDEF NEXTGEN}
  { Clean up strings we allocated }
  for I := 0 to Length(StrToClear) - 1 do
  begin
    if Assigned(StrToClear[I]) then
      PAnsiString(StrToClear[I])^ := '';
  end;
  SetLength(StrToClear, 0);
{$ENDIF !NEXTGEN}

{$IFDEF UNICODE}
  { Cleanup unicode strings we allocated }
  for I := 0 to Length(UStrToClear) - 1 do
  begin
    if Assigned(UStrToClear[I]) then
      PUnicodeString(UStrToClear[I])^ := '';
  end;
  SetLength(UStrToClear, 0);
{$ENDIF}

{$IFNDEF NEXTGEN}
  { Clean up WideStrings we allocated }
  for I := 0 to Length(WStrToClear) - 1 do
  begin
    if Assigned(WStrToClear[I]) then
      PWideString(WStrToClear[I])^ := '';
  end;
  SetLength(WStrToClear, 0);
{$ENDIF !NEXTGEN}

  inherited;
end;

procedure TDataContext.AddDynArrayToClear(P: Pointer; Info: PTypeInfo);
var
  I: Integer;
begin
  for I := 0 to Length(DynArrayToClear) -1 do
    if DynArrayToClear[I].P = P then
      Exit;
  I := Length(DynArrayToClear);
  SetLength(DynArrayToClear, I + 1);
  DynArrayToClear[I].P := P;
  DynArrayToClear[I].Info := Info;
end;

procedure TDataContext.AddObjectToDestroy(Obj: TObject);
var
  Index, EmptySlot: Integer;
begin
  EmptySlot := -1;
  for Index := 0 to Length(FObjsToDestroy) -1 do
  begin
    if FObjsToDestroy[Index] = Obj then
      Exit;
    if FObjsToDestroy[Index] = nil then
      EmptySlot := Index;
  end;
  if EmptySlot <> -1 then
  begin
    FObjsToDestroy[EmptySlot] := Obj;
    Exit;
  end;
  Index := Length(FObjsToDestroy);
  SetLength(FObjsToDestroy, Index + 1);
  FObjsToDestroy[Index] := Obj;
end;

procedure TDataContext.RemoveObjectToDestroy(Obj: TObject);
var
  I: Integer;
begin
  I := 0;
  while I < Length(FObjsToDestroy) do
  begin
    if FObjsToDestroy[I] = Obj then
    begin
      FObjsToDestroy[I] := nil;
      Break;
    end;
    Inc(I);
  end;
end;

function TDataContext.AllocData(Size: Integer): Pointer;
begin
  Result := @Data[DataOffset];
  Inc(DataOffset, Size);
end;

{ TInvContext }

const
  MAXINLINESIZE = sizeof(TVarData) + 4;

procedure TInvContext.SetMethodInfo(const MD: TIntfMethEntry);
begin
  SetLength(DataP, MD.ParamCount + 1);
  SetLength(Data, (MD.ParamCount + 1) * MAXINLINESIZE);
end;

procedure TInvContext.SetParamPointer(Param: Integer; P: Pointer);
begin
   SetDataPointer(Param,  P);
end;

function TInvContext.GetParamPointer(Param: Integer): Pointer;
begin
  Result := GetDataPointer(Param);
end;

function TInvContext.GetResultPointer: Pointer;
begin
  Result := ResultP;
end;

procedure TInvContext.SetResultPointer(P: Pointer);
begin
  ResultP := P;
end;

procedure TInvContext.AllocServerData(const MD: TIntfMethEntry);
  function GetTypeSize(Info: PTypeInfo): Integer;
  var
    Context: TRttiContext;
    Typ: TRttiType;
  begin
    if (Info = TypeInfo(Variant)) or (Info = TypeInfo(OleVariant)) then
      Exit(SizeOf(TVarData));                                                
    Result := SizeOf(Pointer);
    Typ := Context.GetType(Info);
    if Assigned(Typ) then
      Result := Typ.TypeSize;
  end;
var
  I: Integer;
  Info: PTypeInfo;
  P: Pointer;
begin
  for I := 0 to MD.ParamCount - 1 do
  begin
    P := AllocData(GetTypeSize(MD.Params[I].Info));
    SetParamPointer(I, P);
    if MD.Params[I].Info.Kind = tkVariant then
    begin
      Variant(PVarData(P)^) := NULL;
      AddVariantToClear(PVarData(P));
    end else if MD.Params[I].Info.Kind = tkDynArray then
    begin
      AddDynArrayToClear(P, MD.Params[I].Info);
{$IFNDEF NEXTGEN}
    end else if MD.Params[I].Info.Kind = tkLString then
    begin
      PAnsiString(P)^ := '';
      AddStrToClear(P);
{$ENDIF !NEXTGEN}
{$IFDEF UNICODE}
    end else if MD.Params[I].Info.Kind = tkUString then
    begin
      PUnicodeString(P)^ := '';
      AddUStrToClear(P);
{$ENDIF}
{$IFNDEF NEXTGEN}
    end else if MD.Params[I].Info.kind = tkWString then
    begin
      PWideString(P)^ := '';
      AddWStrToClear(P);
{$ENDIF !NEXTGEN}
    end;
  end;
  if MD.ResultInfo <> nil then
  begin
    Info := MD.ResultInfo;
    case Info^.Kind of
{$IFNDEF NEXTGEN}
      tkLString:
        begin
          P := AllocData(sizeof(PAnsiString));
          PAnsiString(P)^ := '';
          AddStrToClear(P);
        end;
      tkWString:
        begin
          P := AllocData(sizeof(PWideString));
          PWideString(P)^ := '';
          AddWStrToClear(P);
        end;
{$ENDIF !NEXTGEN}
{$IFDEF UNICODE}
      tkUString:
        begin
          P := AllocData(sizeof(PUnicodeString));
          PUnicodeString(P)^ := '';
          AddUStrToClear(P);
        end;
{$ENDIF}
      tkInt64:
        P := AllocData(sizeof(Int64));
      tkVariant:
        begin
          P := AllocData(sizeof(TVarData));
          Variant( PVarData(P)^ ) := NULL;
          AddVariantToClear(PVarData(P));
        end;
      tkDynArray:
        begin
          P := AllocData(GetTypeSize(Info));
          AddDynArrayToClear(P, MD.ResultInfo);
        end;
      else
        P := AllocData(GetTypeSize(Info));
    end;
    SetResultPointer(P);
  end;
end;

procedure InitIR;
begin
  JSONRPCInvRegistryV := TInvokableClassRegistry.Create;
end;

function InvRegistry: TInvokableClassRegistry;
begin
  if not Assigned(JSONRPCInvRegistryV) then
    InitIR;
  Result := JSONRPCInvRegistryV;
end;

initialization
  if not Assigned(JSONRPCInvRegistryV) then
    InitIR;
finalization
  JSONRPCInvRegistryV.Free;
end.

