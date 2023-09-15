unit JSONRPC.TransportWrapper.TCP;

interface

uses
  JSONRPC.Common.Types, System.Classes,
  System.Net.URLClient,
  System.Net.ClientSocket, System.Net.Socket.Common
  ;

type

  TJSONRPCTCPTransportWrapper = class(TJSONRPCTransportWrapper)
  protected
//    FSocket: TSocket;
    FSocket: TClientSocket;
//    FSocket: TIdTCPClient;
    FServerURL: string;
    FEndpoint: TNetEndpoint;

    function GetConnected: Boolean; override;
    procedure ParseURL;

    function GetRequestStream: TStream; override;
    function GetResponseStream: TStream; override;

    function GetConnectionTimeout: Integer; override;
    function GetResponseTimeout: Integer; override;
    function GetSendTimeout: Integer; override;
    procedure SetConnectionTimeout(const Value: Integer); override;
    procedure SetResponseTimeout(const Value: Integer); override;
    procedure SetSendTimeout(const Value: Integer); override;
  public
    procedure Connect; override;

    constructor Create; override;
    destructor Destroy; override;
    procedure Post(const AURL: string; const ASource, AResponseContent: TStream;
      const AHeaders: TNetHeaders); override;
          property Connected;
  end;

  procedure InitTransportWrapperTCP;

implementation

uses
{$IF DEFINED(DEBUG)}
  Winapi.Windows,
{$ENDIF}
  System.Net.Socket,
  Winapi.Winsock2, System.SysUtils;

{ TJSONRPCTCPTransportWrapper }

procedure TJSONRPCTCPTransportWrapper.Connect;
begin
  try
    FSocket.Connect(FEndpoint);
  except
    //
  end;
//  FSocket.Connect(FEndpoint.Address.Address, FEndpoint.Port);
end;

constructor TJSONRPCTCPTransportWrapper.Create;
begin
  inherited;
//  FSocket := System.Net.Socket.TSocket.Create(TSocketType.TCP, TEncoding.UTF8);
  FSocket := TClientSocket.Create;
//  FSocket := TIdTCPClient.Create(nil);
end;

destructor TJSONRPCTCPTransportWrapper.Destroy;
begin
  FSocket.Free;
  inherited;
end;

function TJSONRPCTCPTransportWrapper.GetConnected: Boolean;
begin
  if not Assigned(FSocket) then
    Exit(False);
  Result := FSocket.State * [TSocketState.Connected] <> [];
//  Result := FSocket.Connected;
end;

function TJSONRPCTCPTransportWrapper.GetConnectionTimeout: Integer;
begin
  Result := FSocket.ConnectTimeout;
end;

function TJSONRPCTCPTransportWrapper.GetRequestStream: TStream;
begin
  if not Assigned(FRequestStream) then
    FRequestStream := TTrackedMemoryStream.Create(CheckStream);
  if FRequestStream.Size <> 0 then
    FRequestStream.Size := 0;
  Result := FRequestStream;
end;

function TJSONRPCTCPTransportWrapper.GetResponseStream: TStream;
begin
  if not Assigned(FResponseStream) then
    FResponseStream:= TTrackedMemoryStream.Create(CheckStream);
  if FResponseStream.Size <> 0 then
    FResponseStream.Size := 0;
  Result := FResponseStream;
end;

function TJSONRPCTCPTransportWrapper.GetResponseTimeout: Integer;
begin
  Result := FSocket.ReceiveTimeout;
//  Result := FSocket.ReadTimeout;
end;

function TJSONRPCTCPTransportWrapper.GetSendTimeout: Integer;
begin
  Result := FSocket.SendTimeout;
end;

procedure TJSONRPCTCPTransportWrapper.ParseURL;
var
  LURI: TURI;
begin
  LURI := TURI.Create(FServerURL);
  if FEndpoint.Family = 0 then
    FEndpoint.Family := AF_INET;
  FEndpoint.Port := LURI.Port;
  FEndpoint.SetAddress(LURI.Host);
end;

procedure TJSONRPCTCPTransportWrapper.Post(const AURL: string; const ASource,
  AResponseContent: TStream; const AHeaders: TNetHeaders);
var
  LSendBuffer, LReceivedBuffer: TBytes;
begin

  if not Connected then
    begin
      if FServerURL <> AURL then
        begin
          FServerURL := AURL;
          ParseURL;
        end;
      Connect;
    end;

  ASource.Position := 0;
  SetLength(LSendBuffer, ASource.Size);
  // Send outgoing client data
  ASource.Read(LSendBuffer, Length(LSendBuffer));
  FSocket.Send(LSendBuffer);

  // Read incoming server response on client side
  LReceivedBuffer := FSocket.Receive();
  {$IF DEFINED(DEBUG)}
  var LReceivedString := StringOf(LReceivedBuffer);
  OutputDebugString(PChar(LReceivedString));
  {$ENDIF}
  AResponseContent.Size := 0;
  AResponseContent.Write(LReceivedBuffer, Length(LReceivedBuffer));
end;

procedure TJSONRPCTCPTransportWrapper.SetConnectionTimeout(
  const Value: Integer);
begin
  FSocket.ConnectTimeout := Value;
end;

procedure TJSONRPCTCPTransportWrapper.SetResponseTimeout(const Value: Integer);
begin
  FSocket.ReceiveTimeout := Value;
end;

procedure TJSONRPCTCPTransportWrapper.SetSendTimeout(const Value: Integer);
begin
  FSocket.SendTimeout := Value;
end;

procedure InitTransportWrapperTCP;
begin
  GJSONRPCTransportWrapperClass := TJSONRPCTCPTransportWrapper;
end;

initialization
  if not Assigned(GJSONRPCTransportWrapperClass) then
    InitTransportWrapperTCP;
end.
