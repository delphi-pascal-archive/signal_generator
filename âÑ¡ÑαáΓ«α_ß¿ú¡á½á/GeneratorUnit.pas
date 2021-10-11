unit GeneratorUnit;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms,Dialogs,
  StdCtrls,mmsystem, ExtCtrls, Spin;

type
  TServiceThread = class(TThread)
  public
    procedure Execute; override;
  end;


  TForm1 = class(TForm)
    btnPlay: TButton;
    btnStop: TButton;
    GroupBox1: TGroupBox;
    seLfreq: TSpinEdit;
    Label3: TLabel;
    Label4: TLabel;
    seLLev: TSpinEdit;
    GroupBox2: TGroupBox;
    Label6: TLabel;
    Label7: TLabel;
    seRfreq: TSpinEdit;
    seRLev: TSpinEdit;
    rgL: TRadioGroup;
    rgR: TRadioGroup;
    procedure btnPlayClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure cbLtypChange(Sender: TObject);
    procedure cbRTypChange(Sender: TObject);
    procedure seLfreqChange(Sender: TObject);
    procedure seRfreqChange(Sender: TObject);
    procedure seLLevChange(Sender: TObject);
    procedure seRLevChange(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }

  end;

const
  BlockSize = 1024*32; // ������ ������ ������ -- � ������-�� min ������� ������ ��� ���� 

var
  Form1: TForm1;
  ServiceThread : TServiceThread;

implementation

{$R *.DFM}
var
  Freq  : array [0..1] of LongInt;
  Typ   : array [0..1] of LongInt;
  Lev   : array [0..1] of LongInt;
  tPred : array [0..1] of Double;

  
procedure Mix(Buffer,First,Second : PChar; Count : LongInt); assembler;
{       ��������� ��������� ��� ������� ������ First � Second � ��������}
{       ��������� � Buffer. �������� �������� ����� ������ WORD         }
{       Count -- ����� �������� � ����� �������, �.�. Buffer ����� �����}
{       2*Count ���������}

{       EAX - Buffer       }
{       EDX - First        }
{       ECX - Second       }
{       Count -- � �����   }
asm
        PUSH    EBX
        PUSH    ESI
        PUSH    EDI
        MOV     EDI,EAX     // Buffer ������� � EDI -- ��������� ������� ���������
        MOV     ESI,ECX     // Second ������� � ESI -- ��������� ������� ���������
        MOV     ECX,Count   // Count ������� � ECX
        XCHG    ESI,EDX     // ����� ��������� -- ������ First
@@Loop:
        MOVSW              // ��������� ����� �� First/Second � Buffer � ��������� ��������
        XCHG    ESI,EDX    // ����� ���������
        LOOP    @@Loop     // ��������� ECX � �������� ������� ������ ECX = 0

        POP     EDI
        POP     ESI
        POP     EBX
end;


procedure TForm1.btnPlayClick(Sender: TObject);
var
  WOutCaps : TWAVEOUTCAPS;
begin
  // �������� ������� ���������� ������
  FillChar(WOutCaps,SizeOf(TWAVEOUTCAPS),#0);
  if MMSYSERR_NOERROR <> WaveOutGetDevCaps(0,@WOutCaps,SizeOf(TWAVEOUTCAPS)) then
  begin
    ShowMessage('������ ���������������');
    exit;
  end;
  // ���������� ���������� �������
  Freq[0] := seLfreq.Value;
  Freq[1] := seRfreq.Value;
  Typ[0] :=  rgL.ItemIndex;
  Typ[1] :=  rgR.ItemIndex;
  Lev[0] :=  seLLev.Value;
  Lev[1] :=  seRLev.Value;
  tPred[0] := 0;
  tPred[1] := 0;
  // ������ ������ ������ �� ����������
  ServiceThread := TServiceThread.Create(False);
end;

procedure Generator(buf : PChar;  Typ, Freq,  Lev, Size : LongInt; var tPred : Double);
var
  I : LongInt;
  OmegaC,t : Double;
begin
  case Typ of
   0:  // ������
       begin
       for I := 0 to Size-2 do begin
         PSmallInt(buf)^ := 0;
         Inc(PSmallInt(buf));
       end;
       tPred := 0;
       end;
   1: // �����
      begin
        OmegaC := 2*PI*Freq;
        for I := 0 to Size div 2 do begin
          t := I/44100 + tPred;
          PSmallInt(buf)^ := Round(Lev*sin(OmegaC*t));
          Inc(PSmallInt(buf));
        end;
        tPred := t;
      end;
   2: // ������
      begin
        OmegaC := 2*PI*Freq;
        for I := 0 to Size div 2 do begin
          t := I/44100 + tPred;
          if sin(OmegaC*t) >= 0 then
            PSmallInt(buf)^ := Lev
          else
            PSmallInt(buf)^ := -Lev;
          Inc(PSmallInt(buf));
        end;
        tPred := t;
      end;
   end;
end;

procedure TServiceThread.Execute;
var
  I : Integer;
  hEvent : THandle;
  wfx : TWAVEFORMATEX;
  hwo : HWAVEOUT;
  si : TSYSTEMINFO;
  wh : array [0..1] of TWAVEHDR;
  Buf : array [0..1] of PChar;
  CnlBuf  : array [0..1] of PChar;
begin

  // ���������� ��������� �������
  FillChar(wfx,Sizeof(TWAVEFORMATEX),#0);
  with wfx do begin
    wFormatTag := WAVE_FORMAT_PCM;      // ������������ PCM ������
    nChannels := 2;                     // ��� ������������
    nSamplesPerSec := 44100;            // ������� ������������� 44,1 ���
    wBitsPerSample := 16;               // ������� 16 ���
    nBlockAlign := wBitsPerSample div 8 * nChannels; // ����� ���� � ������ ��� ������������ -- 4 �����
    nAvgBytesPerSec := nSamplesPerSec * nBlockAlign; // ����� ���� � ��������� ��������� ��� �������������
    cbSize := 0;     // �� ������������
  end;

  // �������� ����������
  hEvent := CreateEvent(nil,false,false,nil);
  if WaveOutOpen(@hwo,0,@wfx,hEvent,0,CALLBACK_EVENT) <> MMSYSERR_NOERROR then begin
    CloseHandle(hEvent);
    Exit;
  end;

  // ��������� ������ ��� ������, ������������� ��� �������� ������ Windows
  GetSystemInfo(si);
  buf[0] := VirtualAlloc(nil,(BlockSize*4+si.dwPageSize-1) div si.dwPagesize * si.dwPageSize,
                             MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE);
  buf[1] := PChar(LongInt(buf[0]) + BlockSize);
  // �������� ������ ��� ����������� ��� ������ �����
  CnlBuf[0] := PChar(LongInt(Buf[1])  + BlockSize);
  CnlBuf[1] := PChar(LongInt(CnlBuf[0]) + BlockSize div 2);

  // ���������� 2-� ������� ������
  for I:=0 to 1 do begin
    FillChar(wh[I],sizeof(TWAVEHDR),#0);
    wh[I].lpData := buf[I];      // ��������� �� �����
    wh[I].dwBufferLength := BlockSize;  // ����� ������
    waveOutPrepareHeader(hwo, @wh[I], sizeof(TWAVEHDR));  // ���������� ������� ���������
  end;

  // ��������� ������� �������
  Generator(CnlBuf[0],Typ[0], Freq[0], Lev[0], BlockSize div 2, tPred[0]);
  Generator(CnlBuf[1],Typ[1], Freq[1], Lev[1], BlockSize div 2, tPred[1]);
  // ���������� ������� ������� � ������ ����� ������
  Mix(buf[0],CnlBuf[0],CnlBuf[1], BlockSize div 2);
  I:=0;
  while not Terminated do begin
    // �������� ���������� ������ �������� ��� ������������
    waveOutWrite(hwo, @wh[I], sizeof(WAVEHDR));
    WaitForSingleObject(hEvent, INFINITE);
    I:= I xor 1;
    // ��������� ������� �������
    Generator(CnlBuf[0],Typ[0], Freq[0], Lev[0], BlockSize div 2, tPred[0]);
    Generator(CnlBuf[1],Typ[1], Freq[1], Lev[1], BlockSize div 2, tPred[1]);
    // ���������� ������� ������� � ��������� ����� ������
    Mix(buf[I],CnlBuf[0],CnlBuf[1], BlockSize div 2);
    // �������� ����� ������������ � ������������ ����������� ������

  end;

  // ���������� ������ � ����������������
  waveOutReset(hwo);
  waveOutUnprepareHeader(hwo, @wh[0], sizeof(WAVEHDR));
  waveOutUnprepareHeader(hwo, @wh[1], sizeof(WAVEHDR));
  // ������������ ������
  VirtualFree(buf[0],0,MEM_RELEASE);
  WaveOutClose(hwo);
  CloseHandle(hEvent);
end;



procedure TForm1.FormCreate(Sender: TObject);
begin
  rgL.ItemIndex := 1;
  rgR.ItemIndex := 1;
end;

procedure TForm1.btnStopClick(Sender: TObject);
begin
  ServiceThread.Terminate;
end;

procedure TForm1.cbLtypChange(Sender: TObject);
begin
  Typ[0] :=  rgL.ItemIndex;
end;

procedure TForm1.cbRTypChange(Sender: TObject);
begin
  Typ[1] :=  rgR.ItemIndex;
end;

procedure TForm1.seLfreqChange(Sender: TObject);
begin
  Freq[0] := seLfreq.Value;
end;

procedure TForm1.seRfreqChange(Sender: TObject);
begin
  Freq[1] := seRfreq.Value;
end;

procedure TForm1.seLLevChange(Sender: TObject);
begin
  Lev[0] :=  seLLev.Value;
end;

procedure TForm1.seRLevChange(Sender: TObject);
begin
  Lev[1] :=  seRLev.Value;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  ServiceThread.Free;
end;

end.
