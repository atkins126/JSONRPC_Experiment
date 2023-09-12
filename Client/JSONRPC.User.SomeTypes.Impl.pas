unit JSONRPC.User.SomeTypes.Impl;

interface

uses
  JSONRPC.Common.Types, System.Classes, System.JSON.Serializers,
  JSONRPC.RIO, JSONRPC.User.SomeTypes;

function GetSomeJSONRPC(const ServerURL: string = '';
  const AWrapperType: TTransportWrapperType = twtHTTP;
  const UseDefaultProcs: Boolean = True;
  const AOnSyncProc: TOnSyncEvent = nil;
  const AOnBeforeParse: TOnBeforeParseEvent = nil): ISomeJSONRPC;

implementation

uses
{$IF DEFINED(TEST) OR DEFINED(DEBUG)}
  Winapi.Windows,
{$ENDIF}
  System.JSON, System.Rtti, JSONRPC.InvokeRegistry,
  JSONRPC.JsonUtils;

function GetSomeJSONRPC(
  const ServerURL: string = '';
  const AWrapperType: TTransportWrapperType = twtHTTP;
  const UseDefaultProcs: Boolean = True;
  const AOnSyncProc: TOnSyncEvent = nil;
  const AOnBeforeParse: TOnBeforeParseEvent = nil
  ): ISomeJSONRPC;
begin
{$IF DEFINED(TEST)}
  // Developed to send rubbish data to check server tolerance
  RegisterJSONRPCWrapper(TypeInfo(ISomeExtendedJSONRPC));
{$ENDIF}

  RegisterJSONRPCWrapper(TypeInfo(ISomeJSONRPC));

//  case AWrapperType of
//    twtHTTP: JSONRPC.TransportWrapper.HTTP.InitTransportWrapperHTTP;
//    twtTCP: JSONRPC.TransportWrapper.TCP.InitTransportWrapperTCP;
//  end;
  var LJSONRPCWrapper := TJSONRPCWrapper.Create(nil);
  LJSONRPCWrapper.ServerURL := ServerURL;
  Result := LJSONRPCWrapper as ISomeJSONRPC;

{$IF DECLARED(IsDebuggerPresent)}
  if IsDebuggerPresent then
    begin
      LJSONRPCWrapper.SendTimeout := 10*60*1000;
      LJSONRPCWrapper.ResponseTimeout := LJSONRPCWrapper.SendTimeout;
      LJSONRPCWrapper.ConnectionTimeout := LJSONRPCWrapper.SendTimeout;
//      LJSONRPCWrapper.ResponseTimeout := 150;
//      LJSONRPCWrapper.SendTimeout := 150;
    end;
{$ENDIF}

{$IF DEFINED(TEST)}
  // OnSync is typically not used, unless you're testing something,
  // in this case, just copy the request into the response
  if ServerURL = '' then
    begin
      if UseDefaultProcs then
        begin
          LJSONRPCWrapper.OnSync := procedure (ARequest, AResponse: TStream)
          begin
            AResponse.CopyFrom(ARequest);
          end;

          LJSONRPCWrapper.OnBeforeParse := procedure (const AContext: TInvContext;
            AMethNum: Integer; const AMethMD: TIntfMethEntry; const AMethodID: Int64;
            AJSONResponse: TStream)
          begin
            // This is where the client can pretend to be a server, look at the response,
            // which is actually the request, and then clear the response stream and
            // write its actual response into it...
            if (AJSONResponse.Size <> 0) and (AMethMD.Name = 'AddSomeXY') then
              begin
                AJSONResponse.Position := 0;

                var LBytes: TArray<Byte>;
                SetLength(LBytes, AJSONResponse.Size);
                AJSONResponse.Read(LBytes[0], AJSONResponse.Size);
        //        var LJSONResponseStr := TEncoding.UTF8.GetString(LBytes);

        // THIS BUG WILL KILL / HANG THE DEBUGGER, on exit of this method
        //       var LJSONResponseStr := '';
        //       AJSONResponse.Read(LJSONResponseStr, AJSONResponse.Size);

                var LJSONObj := TJSONObject.ParseJSONValue(LBytes, 0);
                try
                  var LX: Integer := LJSONObj.GetValue<Integer>('params.X');
                  var LY: Integer := LJSONObj.GetValue<Integer>('params.Y');
                  var LValue: TValue := LX + LY;
                  AJSONResponse.Size := 0;
                  WriteJSONResult(AContext, AMethNum, AMethMD, AMethodID, LValue, AJSONResponse);
                finally
                  LJSONObj.Free;
                end;
              end;
          end;

        end else
        begin
          LJSONRPCWrapper.OnSync := AOnSyncProc;
          LJSONRPCWrapper.OnBeforeParse := AOnBeforeParse;
        end;

// Do anything to the JSON response stream, before parsing starts...
// Since there's no server, write response data into the server response, so that it can be parsed

    end;
{$ENDIF}

end;

initialization
  InvRegistry.RegisterInterface(TypeInfo(ISomeJSONRPC));
{$IF DEFINED(TEST)}
  // Developed to send rubbish data to check server tolerance
  InvRegistry.RegisterInterface(TypeInfo(ISomeExtendedJSONRPC));
{$ENDIF}
end.
